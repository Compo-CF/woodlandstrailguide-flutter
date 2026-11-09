import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/natural_palette.dart';

/// Anchored adaptive AdMob banner for the bottom of the Map tab. Registered
/// 2026-08-13 as its own Android app in AdMob (App ID
/// ca-app-pub-1927040492403163~5854190344 — set in AndroidManifest.xml —
/// separate from the iOS App ID, which doesn't carry over to Android).
///
/// Real ad unit ID is only used in release builds — debug builds keep
/// using Google's official test unit, so repeatedly tapping around
/// during our own sideload testing never looks like invalid ad clicks
/// against the real unit (an AdMob policy risk, not just tidiness).
///
/// ## Anchored adaptive, not fixed 320x50 (2026-11-09)
/// This used to request `AdSize.banner`, the legacy fixed 320x50. Anchored
/// adaptive asks AdMob for a Google-chosen height at the device's real
/// width, which draws on a **larger inventory pool** — the lever being
/// pulled against a **45% match rate** on this unit (500 requests → 194
/// impressions in the 30 days to 11-08, against 100% for every other
/// healthy banner in the account). It also stops the banner sitting as a
/// 320pt island in the middle of a wider phone.
///
/// Note `getCurrentOrientationAnchoredAdaptiveBannerAdSize` is **deprecated**
/// in google_mobile_ads 9.x; the live call is
/// `getLargeAnchoredAdaptiveBannerAdSizeWithOrientation`.
///
/// Two consequences worth knowing:
///  * The size must be fetched **asynchronously** before the ad is built,
///    so the load starts from [didChangeDependencies], not [initState] —
///    it needs `MediaQuery`.
///  * The height is **orientation-specific**. This app locks no orientation
///    and `AndroidManifest.xml` declares `configChanges="orientation|..."`,
///    so the Activity is NOT recreated on rotate and this State object
///    survives. Width and orientation are therefore re-checked on every
///    dependency change, and the ad reloaded when either actually changes.
///
/// ## Why this widget collapses instead of reserving space
/// Until 2026-11-09 a failed load left a permanent **50px blank strip**
/// under the map in the production release (fixed in `8330bf0`).
/// `onAdFailedToLoad` disposed the ad but never called `setState` and never
/// cleared `_bannerAd`, so `_isLoaded` stayed false forever and `build` kept
/// returning a `SizedBox(height: 50)` — an empty band in the `Column`, with
/// nothing to put in it and no way back. Three rules now hold:
///  * no-fill reserves nothing       -> collapse to `SizedBox.shrink()`
///  * `_bannerAd` never holds a      -> null it on failure, so `dispose()`
///    disposed ad                       can't double-dispose
///  * a failure is never permanent   -> bounded retry with backoff
///
/// The retry matters more than it looks: a **newly registered AdMob app
/// returns no-fill for days** while Google reviews it (this one was still
/// under review on 2026-11-06, with ad serving explicitly limited), so the
/// very first requests a real user makes are the ones most likely to fail.
/// Same reasoning as Transmute's `AdManager.retry`.
class AdMobBannerView extends StatefulWidget {
  const AdMobBannerView({super.key});

  static const _realAdUnitId = 'ca-app-pub-1927040492403163/7394502722';
  static const _testAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  static String get adUnitId => kReleaseMode ? _realAdUnitId : _testAdUnitId;

  @override
  State<AdMobBannerView> createState() => _AdMobBannerViewState();
}

class _AdMobBannerViewState extends State<AdMobBannerView> {
  /// Backoff between load attempts. The last value repeats until
  /// [_maxAttempts] is spent; after that the banner stays collapsed and
  /// costs nothing. A rotation, or re-entering the Map tab, starts over.
  static const _backoff = <Duration>[
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];
  static const _maxAttempts = 5;

  BannerAd? _bannerAd;
  bool _isLoaded = false;
  int _attempts = 0;
  Timer? _retryTimer;

  /// Width and orientation the current ad was requested at, so a rotation
  /// (or a multi-window resize) reloads at the new size and nothing else
  /// does.
  int? _requestedWidth;
  Orientation? _requestedOrientation;

  /// Bumped every time the request parameters change. Async callbacks
  /// compare against it and bail if they belong to a superseded request —
  /// cheaper and less error-prone than threading width through every
  /// closure.
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    final width = media.size.width.truncate();
    final orientation = media.orientation;
    if (width <= 0) return;
    if (width == _requestedWidth && orientation == _requestedOrientation) {
      return;
    }
    _requestedWidth = width;
    _requestedOrientation = orientation;
    _attempts = 0;
    _retryTimer?.cancel();
    _generation++;
    _discardCurrentAd();
    _loadAd(_generation, width, orientation);
  }

  /// Takes the live ad out of the tree *before* disposing it. Disposing an
  /// ad that an `AdWidget` still references is a crash, so the dispose waits
  /// for the frame in which `build` has dropped it.
  void _discardCurrentAd() {
    final old = _bannerAd;
    if (old == null) return;
    _bannerAd = null;
    _isLoaded = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _loadAd(int gen, int width, Orientation orientation) async {
    _attempts++;
    // Falls back to the fixed banner if AdMob can't supply an adaptive
    // height — documented as possible, and it returns null rather than
    // throwing.
    final adaptive =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
      orientation,
      width,
    );
    if (!mounted || gen != _generation) return;

    final ad = BannerAd(
      adUnitId: AdMobBannerView.adUnitId,
      size: adaptive ?? AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (!mounted || gen != _generation) {
            loaded.dispose();
            return;
          }
          setState(() {
            _bannerAd = loaded as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (failed, error) {
          failed.dispose();
          if (!mounted || gen != _generation) return;
          // Clear the reference as well as the flag: `failed` is disposed
          // now, so leaving it in `_bannerAd` would double-dispose on
          // teardown.
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
          _scheduleRetry(gen, width, orientation);
        },
      ),
    );
    ad.load();
  }

  void _scheduleRetry(int gen, int width, Orientation orientation) {
    if (_attempts >= _maxAttempts) return;
    final index =
        _attempts - 1 < _backoff.length ? _attempts - 1 : _backoff.length - 1;
    _retryTimer?.cancel();
    _retryTimer = Timer(_backoff[index], () {
      if (mounted && gen == _generation) _loadAd(gen, width, orientation);
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    // Collapse when there is nothing to show. This widget is a direct child
    // of the map Column, so any reserved height is a visible empty band.
    if (!_isLoaded || ad == null) return const SizedBox.shrink();
    return Container(
      color: NaturalPalette.cardBg,
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: ad),
    );
  }
}

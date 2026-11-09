import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/natural_palette.dart';

/// AdMob banner for the bottom of the Map tab. Registered 2026-08-13 as
/// its own Android app in AdMob (App ID ca-app-pub-1927040492403163~
/// 5854190344 — set in AndroidManifest.xml — separate from the iOS
/// App ID, which doesn't carry over to Android).
///
/// Real ad unit ID is only used in release builds — debug builds keep
/// using Google's official test unit, so repeatedly tapping around
/// during our own sideload testing never looks like invalid ad clicks
/// against the real unit (an AdMob policy risk, not just tidiness).
///
/// ## Why this widget collapses instead of reserving space
/// Until 2026-11-09 a failed load left a permanent **50px blank strip**
/// under the map in the production release. `onAdFailedToLoad` disposed the
/// ad but never called `setState` and never cleared `_bannerAd`, so
/// `_isLoaded` stayed false forever and `build` kept returning a
/// `SizedBox(height: 50)` — an empty band in the `Column`, with nothing to
/// put in it and no way back. Three things were wrong and all are fixed
/// here:
///  * no-fill reserved space forever   -> collapse to `SizedBox.shrink()`
///  * `_bannerAd` kept a disposed ad   -> null it, so `dispose()` can't
///                                        double-dispose
///  * a single failure was permanent   -> bounded retry with backoff
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
  /// costs nothing. Re-entering the Map tab builds fresh state and starts
  /// over.
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

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _attempts++;
    final ad = BannerAd(
      adUnitId: AdMobBannerView.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (!mounted) {
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
          if (!mounted) return;
          // Clear the reference as well as the flag: `failed` is disposed
          // now, so leaving it in `_bannerAd` would double-dispose on
          // teardown.
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
          _scheduleRetry();
        },
      ),
    );
    ad.load();
  }

  void _scheduleRetry() {
    if (_attempts >= _maxAttempts) return;
    final index =
        _attempts - 1 < _backoff.length ? _attempts - 1 : _backoff.length - 1;
    _retryTimer?.cancel();
    _retryTimer = Timer(_backoff[index], () {
      if (mounted) _loadAd();
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

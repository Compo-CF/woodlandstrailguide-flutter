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
class AdMobBannerView extends StatefulWidget {
  const AdMobBannerView({super.key});

  static const _realAdUnitId = 'ca-app-pub-1927040492403163/7394502722';
  static const _testAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  static String get adUnitId => kReleaseMode ? _realAdUnitId : _testAdUnitId;

  @override
  State<AdMobBannerView> createState() => _AdMobBannerViewState();
}

class _AdMobBannerViewState extends State<AdMobBannerView> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: AdMobBannerView.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    ad.load();
    _bannerAd = ad;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox(height: 50);
    return Container(
      color: NaturalPalette.cardBg,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

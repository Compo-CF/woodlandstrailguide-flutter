import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/natural_palette.dart';

/// AdMob banner for the bottom of the Map tab. Uses Google's official
/// TEST ad unit ID — swap for the real Android banner unit ID once
/// it's registered in the AdMob console. See README.md "AdMob setup".
class AdMobBannerView extends StatefulWidget {
  const AdMobBannerView({super.key});

  /// TODO: replace with the real Android banner ad unit ID once
  /// registered in AdMob (a *new* Android app entry — the existing
  /// iOS App ID/ad unit don't carry over to Android).
  static const testAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

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
      adUnitId: AdMobBannerView.testAdUnitId,
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

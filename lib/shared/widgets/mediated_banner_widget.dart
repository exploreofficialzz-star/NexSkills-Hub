import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/unity_ads_service.dart';

/// MediatedBannerWidget — AdMob primary, Unity Ads automatic fallback.
///
/// Drop-in replacement for the old per-screen pattern of manually creating
/// a `BannerAd`, calling `.load()`, and wrapping it in `AdWidget`. This
/// widget owns that lifecycle internally AND adds real mediation:
///
///   1. Attempts to load an AdMob banner (adaptive width by default).
///   2. If AdMob's onAdFailedToLoad fires, swaps to Unity's banner
///      placement instead — so a fill on either network shows something.
///   3. If both fail, renders nothing (SizedBox.shrink) — layout never breaks.
///   4. Ad-free users (HiveService.isAdFree()) never see anything render.
class MediatedBannerWidget extends StatefulWidget {
  /// Adaptive width banner sized to the screen (recommended, higher eCPM).
  /// Set false for a fixed 320x50 standard banner.
  final bool adaptive;

  /// Optional small caption shown above the banner (e.g. "Advertisement").
  final String? label;

  const MediatedBannerWidget({super.key, this.adaptive = true, this.label});

  @override
  State<MediatedBannerWidget> createState() => _MediatedBannerWidgetState();
}

class _MediatedBannerWidgetState extends State<MediatedBannerWidget> {
  BannerAd? _admobAd;
  bool _admobLoaded = false;
  bool _admobFailed = false;
  bool _attempted = false;

  bool get _adFree => HiveService.isAdFree();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_attempted && !_adFree) {
      _attempted = true;
      _loadAdMob();
    }
  }

  Future<void> _loadAdMob() async {
    var size = AdSize.banner;
    if (widget.adaptive) {
      final width = MediaQuery.of(context).size.width.truncate();
      final adaptiveSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      size = adaptiveSize ?? AdSize.banner;
    }

    final ad = BannerAd(
      adUnitId:
          Platform.isIOS ? AdConstants.iosBannerId : AdConstants.androidBannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _admobLoaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          // AdMob gave up — build() will fall through to the Unity banner.
          if (mounted) setState(() => _admobFailed = true);
        },
      ),
    );
    _admobAd = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _admobAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adFree) return const SizedBox.shrink();

    Widget? banner;

    if (_admobLoaded && _admobAd != null) {
      banner = SizedBox(
        width: _admobAd!.size.width.toDouble(),
        height: _admobAd!.size.height.toDouble(),
        child: AdWidget(ad: _admobAd!),
      );
    } else if (_admobFailed) {
      // Fallback network — Unity's banner placement.
      banner = SizedBox(
        width: 320,
        height: 50,
        child: UnityBannerAd(
          placementId: UnityAdsService.instance.bannerPlacementId,
          onLoad: (_) {},
          onFailed: (_, __, ___) {},
        ),
      );
    }

    if (banner == null) return const SizedBox.shrink();
    if (widget.label == null) return Center(child: banner);

    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label!,
          style: TextStyle(color: c.textMuted, fontSize: 9, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        banner,
      ],
    );
  }
}

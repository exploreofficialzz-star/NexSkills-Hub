import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'hive_service.dart';

/// Production AdService — all real ad unit IDs, maximum revenue.
///
/// Ad units wired:
///   Banner                — Today, Explore (every 4 items), Progress
///   Interstitial          — every content open, every tab switch
///   Rewarded              — streak save, bonus XP after lesson
///   Rewarded Interstitial — lesson complete dialog (non-blocking)
///   App-open              — cold resume after 30+ min background
///
/// Policy compliance:
///   • 90s minimum between interstitials (policy min = 60s)
///   • Never on back-press
///   • Always user-action triggered
///   • Premium users never see any ads

class AdService {
  static InterstitialAd?         _interstitialAd;
  static RewardedAd?             _rewardedAd;
  static RewardedInterstitialAd? _rewardedInterstitialAd;
  static AppOpenAd?              _appOpenAd;

  static bool _interstitialLoading         = false;
  static bool _rewardedLoading             = false;
  static bool _rewardedInterstitialLoading = false;
  static bool _appOpenLoading              = false;
  static DateTime? _appOpenLoadedAt;

  // ── IDs — production ──────────────────────────────────────────
  static String get _bannerId =>
      Platform.isIOS
          ? AdConstants.iosBannerId
          : AdConstants.androidBannerId;

  static String get _interstitialId =>
      Platform.isIOS
          ? AdConstants.iosInterstitialId
          : AdConstants.androidInterstitialId;

  static String get _rewardedId =>
      Platform.isIOS
          ? AdConstants.iosRewardedId
          : AdConstants.androidRewardedId;

  static String get _rewardedInterstitialId =>
      Platform.isIOS
          ? AdConstants.iosRewardedInterstitialId
          : AdConstants.androidRewardedInterstitialId;

  static String get _appOpenId =>
      Platform.isIOS
          ? AdConstants.iosAppOpenId
          : AdConstants.androidAppOpenId;

  static const AdRequest _request = AdRequest();

  // ─── Init ─────────────────────────────────────────────────────
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
    ));
    _preloadAll();
  }

  static void _preloadAll() {
    _preloadInterstitial();
    _preloadRewarded();
    _preloadRewardedInterstitial();
    _preloadAppOpen();
  }

  // ─── ADAPTIVE BANNER ──────────────────────────────────────────
  static Future<BannerAd> createAdaptiveBanner(BuildContext context) async {
    final width = MediaQuery.of(context).size.width.truncate();
    final size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    return BannerAd(
      adUnitId: _bannerId,
      size: size ?? AdSize.banner,
      request: _request,
      listener: BannerAdListener(onAdFailedToLoad: (ad, _) => ad.dispose()),
    );
  }

  static BannerAd createBanner() => BannerAd(
        adUnitId: _bannerId,
        size: AdSize.banner,
        request: _request,
        listener:
            BannerAdListener(onAdFailedToLoad: (ad, _) => ad.dispose()),
      );

  // ─── INTERSTITIAL ─────────────────────────────────────────────
  static void _preloadInterstitial() {
    if (_interstitialLoading || _interstitialAd != null) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: _request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoading = false;
          ad.setImmersiveMode(true);
        },
        onAdFailedToLoad: (_) => _interstitialLoading = false,
      ),
    );
  }

  /// Show interstitial. ONLY gate = 90s cooldown + premium check.
  /// [onDismissed] always called — navigation is NEVER blocked.
  static Future<bool> showInterstitial({VoidCallback? onDismissed, String? contentId}) async {
    final progress = HiveService.getProgress();
    if (progress.isPremium) { onDismissed?.call(); return false; }
    if (!progress.canShowInterstitial) { onDismissed?.call(); return false; }
    if (_interstitialAd == null) {
      _preloadInterstitial();
      onDismissed?.call();
      return false;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _interstitialAd = null; _preloadInterstitial();
        HiveService.recordInterstitialShown();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _interstitialAd = null; _preloadInterstitial();
        onDismissed?.call();
      },
    );
    await _interstitialAd!.show();
    return true;
  }

  /// Fire-and-forget for tab switches — no navigation callback needed.
  static void showInterstitialForTabSwitch() => showInterstitial();

  // ─── REWARDED ─────────────────────────────────────────────────
  static void _preloadRewarded() {
    if (_rewardedLoading || _rewardedAd != null) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: _request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { _rewardedAd = ad; _rewardedLoading = false; },
        onAdFailedToLoad: (_) => _rewardedLoading = false,
      ),
    );
  }

  static Future<bool> showRewarded({
    required void Function(RewardItem reward) onRewarded,
    VoidCallback? onDismissed,
  }) async {
    if (HiveService.getProgress().isPremium) return false;
    if (_rewardedAd == null) { _preloadRewarded(); return false; }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _rewardedAd = null; _preloadRewarded();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _rewardedAd = null; _preloadRewarded();
        onDismissed?.call();
      },
    );
    await _rewardedAd!.show(onUserEarnedReward: (_, r) => onRewarded(r));
    return true;
  }

  // ─── REWARDED INTERSTITIAL ────────────────────────────────────
  // Shown after lesson complete — user-initiated via "Watch ad → +50 XP"
  static void _preloadRewardedInterstitial() {
    if (_rewardedInterstitialLoading || _rewardedInterstitialAd != null) return;
    _rewardedInterstitialLoading = true;
    RewardedInterstitialAd.load(
      adUnitId: _rewardedInterstitialId,
      request: _request,
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          _rewardedInterstitialLoading = false;
        },
        onAdFailedToLoad: (_) => _rewardedInterstitialLoading = false,
      ),
    );
  }

  static Future<bool> showRewardedInterstitial({
    required void Function(RewardItem reward) onRewarded,
    VoidCallback? onDismissed,
  }) async {
    if (HiveService.getProgress().isPremium) return false;
    if (_rewardedInterstitialAd == null) {
      _preloadRewardedInterstitial();
      return false;
    }
    _rewardedInterstitialAd!.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedInterstitialAd = null;
        _preloadRewardedInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedInterstitialAd = null;
        _preloadRewardedInterstitial();
        onDismissed?.call();
      },
    );
    await _rewardedInterstitialAd!.show(
        onUserEarnedReward: (_, r) => onRewarded(r));
    return true;
  }

  // ─── APP-OPEN ─────────────────────────────────────────────────
  static void _preloadAppOpen() {
    if (_appOpenLoading || _appOpenAd != null) return;
    _appOpenLoading = true;
    AppOpenAd.load(
      adUnitId: _appOpenId,
      request: _request,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenLoading = false;
          _appOpenLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (_) => _appOpenLoading = false,
      ),
    );
  }

  static bool get _appOpenIsValid =>
      _appOpenAd != null &&
      _appOpenLoadedAt != null &&
      DateTime.now().difference(_appOpenLoadedAt!).inHours < 4;

  static Future<void> showAppOpenIfReady() async {
    if (HiveService.getProgress().isPremium) return;
    if (!_appOpenIsValid) { _preloadAppOpen(); return; }
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _appOpenAd = null; _preloadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _appOpenAd = null; _preloadAppOpen();
      },
    );
    await _appOpenAd!.show();
  }

  static void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _rewardedInterstitialAd?.dispose();
    _appOpenAd?.dispose();
  }
}

// ─── Lifecycle observer ───────────────────────────────────────────────────────
class AdLifecycleObserver {
  static DateTime? _backgroundedAt;
  static void onPause() => _backgroundedAt = DateTime.now();
  static Future<void> onResume() async {
    if (_backgroundedAt == null) return;
    final away = DateTime.now().difference(_backgroundedAt!).inSeconds;
    if (away > 1800) await AdService.showAppOpenIfReady();
    _backgroundedAt = null;
  }
}

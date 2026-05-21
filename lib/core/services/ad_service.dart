import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'hive_service.dart';

/// AdService — SDK initialisation + legacy ad helpers.
///
/// App-open ads are intentionally NOT included per product decision.
/// All interstitial/rewarded orchestration is in AdManager.
class AdService {
  static InterstitialAd? _interstitialAd;
  static RewardedAd? _rewardedAd;
  static RewardedInterstitialAd? _rewardedInterstitialAd;

  static bool _interstitialLoading = false;
  static bool _rewardedLoading = false;
  static bool _rewardedInterstitialLoading = false;

  static String get _bannerId =>
      Platform.isIOS ? AdConstants.iosBannerId : AdConstants.androidBannerId;

  static String get _interstitialId =>
      Platform.isIOS ? AdConstants.iosInterstitialId : AdConstants.androidInterstitialId;

  static String get _rewardedId =>
      Platform.isIOS ? AdConstants.iosRewardedId : AdConstants.androidRewardedId;

  static String get _rewardedInterstitialId =>
      Platform.isIOS ? AdConstants.iosRewardedInterstitialId : AdConstants.androidRewardedInterstitialId;

  static const AdRequest _request = AdRequest();

  // ── SDK init only — call from main() before runApp ────────────
  /// Initialises the MobileAds SDK but does NOT load any ad creatives.
  /// Ad loading happens post-first-frame via AdManager to comply with
  /// AdMob policy (no ads before first frame renders).
  static Future<void> initializeSdkOnly() async {
    await MobileAds.instance.initialize();
    MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
    ));
  }

  /// Legacy entry point kept for compatibility.
  static Future<void> initialize() async => initializeSdkOnly();

  /// Called from HomeScreen postFrameCallback — safe to start loading creatives.
  static void preloadAllPostFrame() {
    _preloadInterstitial();
    _preloadRewarded();
    _preloadRewardedInterstitial();
    // App-open ads: intentionally not preloaded per product decision.
  }

  // ── Adaptive / standard banner ─────────────────────────────────
  static Future<BannerAd> createAdaptiveBanner(BuildContext context) async {
    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
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
        listener: BannerAdListener(onAdFailedToLoad: (ad, _) => ad.dispose()),
      );

  // ── Interstitial ───────────────────────────────────────────────
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

  /// [onDismissed] is always called — navigation is never blocked.
  static Future<bool> showInterstitial({
    VoidCallback? onDismissed,
    String? contentId,
  }) async {
    final progress = HiveService.getProgress();
    if (progress.isPremium || !progress.canShowInterstitial) {
      onDismissed?.call();
      return false;
    }
    if (_interstitialAd == null) {
      _preloadInterstitial();
      onDismissed?.call();
      return false;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _preloadInterstitial();
        HiveService.recordInterstitialShown();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        _preloadInterstitial();
        onDismissed?.call();
      },
    );
    await _interstitialAd!.show();
    return true;
  }

  // ── Rewarded ───────────────────────────────────────────────────
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

  // ── Rewarded Interstitial ──────────────────────────────────────
  static void _preloadRewardedInterstitial() {
    if (_rewardedInterstitialLoading || _rewardedInterstitialAd != null) return;
    _rewardedInterstitialLoading = true;
    RewardedInterstitialAd.load(
      adUnitId: _rewardedInterstitialId,
      request: _request,
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) { _rewardedInterstitialAd = ad; _rewardedInterstitialLoading = false; },
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
    _rewardedInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _rewardedInterstitialAd = null; _preloadRewardedInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _rewardedInterstitialAd = null; _preloadRewardedInterstitial();
        onDismissed?.call();
      },
    );
    await _rewardedInterstitialAd!.show(onUserEarnedReward: (_, r) => onRewarded(r));
    return true;
  }

  static void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _rewardedInterstitialAd?.dispose();
  }
}

// ── Lifecycle observer (app-resume handler) ────────────────────────────────────
class AdLifecycleObserver {
  static void onPause() {}   // Nothing to do — no app-open ad
  static void onResume() {}  // Nothing to do — no app-open ad
}

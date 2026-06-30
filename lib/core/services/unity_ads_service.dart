import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../constants/app_constants.dart';
import 'hive_service.dart';

/// UnityAdsService — secondary ad network, mediated alongside AdMob.
///
/// Role in the waterfall:
///   AdMob is always tried FIRST (AdManager / AdService are the primary
///   orchestrators). Unity Ads is only attempted when AdMob has no creative
///   ready — either still loading or failed to fill — which raises overall
///   fill rate without ever stacking two ads or double-counting cooldowns.
///
/// Live formats: Interstitial, Rewarded, Banner.
/// No native placement exists in the Unity dashboard, so native ads remain
/// AdMob-only (see AdConstants.androidNativeId / AdManager.nativeAdUnitId).
///
/// NOTE: this targets the `unity_ads_plugin` v4.x API surface
/// (UnityAds.init / UnityAds.load / UnityAds.showVideoAd / UnityBannerAd).
/// If your pinned package version differs, double-check these method
/// signatures against your installed version before shipping —
/// this sandbox has no network access to run `flutter pub get` and verify.
class UnityAdsService {
  UnityAdsService._();
  static final UnityAdsService instance = UnityAdsService._();

  static String get _gameId => Platform.isIOS
      ? UnityAdsConstants.iosGameId
      : UnityAdsConstants.androidGameId;

  static String get _interstitialPlacement => Platform.isIOS
      ? UnityAdsConstants.iosInterstitialPlacementId
      : UnityAdsConstants.androidInterstitialPlacementId;

  static String get _rewardedPlacement => Platform.isIOS
      ? UnityAdsConstants.iosRewardedPlacementId
      : UnityAdsConstants.androidRewardedPlacementId;

  static String get _bannerPlacement => Platform.isIOS
      ? UnityAdsConstants.iosBannerPlacementId
      : UnityAdsConstants.androidBannerPlacementId;

  /// Exposed for MediatedBannerWidget.
  String get bannerPlacementId => _bannerPlacement;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  bool _interstitialReady = false;
  bool _rewardedReady = false;

  bool get isInterstitialReady => _interstitialReady;
  bool get isRewardedReady => _rewardedReady;

  // ── Init — call once from main(), alongside AdMob init ─────────
  Future<void> init() async {
    if (_initialized) return;
    try {
      await UnityAds.init(
        gameId: _gameId,
        testMode: false, // LIVE — matches AdMob going live in this release
        onComplete: () {
          _initialized = true;
          loadInterstitial();
          loadRewarded();
        },
        onFailed: (error, message) {
          debugPrint('UnityAds init failed: $error $message');
        },
      );
    } catch (e) {
      debugPrint('UnityAds init threw: $e');
    }
  }

  // ── Interstitial ────────────────────────────────────────────────
  void loadInterstitial() {
    if (!_initialized || _interstitialReady) return;
    UnityAds.load(
      placementId: _interstitialPlacement,
      onComplete: (_) => _interstitialReady = true,
      onFailed: (_, __, ___) => _interstitialReady = false,
    );
  }

  /// [onDismissed] always fires exactly once, whether the ad played,
  /// was skipped, or failed — navigation is never blocked.
  Future<bool> showInterstitial({VoidCallback? onDismissed}) async {
    if (HiveService.getProgress().isPremium) {
      onDismissed?.call();
      return false;
    }
    if (!_interstitialReady) {
      onDismissed?.call();
      return false;
    }
    _interstitialReady = false;
    var fired = false;
    void finish() {
      if (fired) return;
      fired = true;
      loadInterstitial();
      onDismissed?.call();
    }

    await UnityAds.showVideoAd(
      placementId: _interstitialPlacement,
      onComplete: (_) => finish(),
      onFailed: (_, __, ___) => finish(),
      onSkipped: (_) => finish(),
    );
    return true;
  }

  // ── Rewarded ────────────────────────────────────────────────────
  void loadRewarded() {
    if (!_initialized || _rewardedReady) return;
    UnityAds.load(
      placementId: _rewardedPlacement,
      onComplete: (_) => _rewardedReady = true,
      onFailed: (_, __, ___) => _rewardedReady = false,
    );
  }

  /// [onEarned] fires ONLY on full completion (Unity's onComplete) —
  /// skipping never earns the reward, matching AdMob's rewarded behaviour.
  Future<bool> showRewarded({
    required VoidCallback onEarned,
    VoidCallback? onDismissed,
  }) async {
    if (HiveService.getProgress().isPremium) {
      onDismissed?.call();
      return false;
    }
    if (!_rewardedReady) {
      onDismissed?.call();
      return false;
    }
    _rewardedReady = false;
    var fired = false;
    void finish() {
      if (fired) return;
      fired = true;
      loadRewarded();
      onDismissed?.call();
    }

    await UnityAds.showVideoAd(
      placementId: _rewardedPlacement,
      onComplete: (_) {
        onEarned();
        finish();
      },
      onFailed: (_, __, ___) => finish(),
      onSkipped: (_) => finish(),
    );
    return true;
  }
}

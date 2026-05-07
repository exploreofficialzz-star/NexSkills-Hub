import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'hive_service.dart';

class AdService {
  static InterstitialAd? _interstitialAd;
  static RewardedAd? _rewardedAd;
  static bool _isInterstitialLoading = false;
  static bool _isRewardedLoading = false;

  static String get _bannerId => Platform.isIOS
      ? AdConstants.iosBannerId
      : AdConstants.androidBannerId;

  static String get _interstitialId => Platform.isIOS
      ? AdConstants.iosInterstitialId
      : AdConstants.androidInterstitialId;

  static String get _rewardedId => Platform.isIOS
      ? AdConstants.iosRewardedId
      : AdConstants.androidRewardedId;

  static String get _nativeId => Platform.isIOS
      ? AdConstants.iosNativeId
      : AdConstants.androidNativeId;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _preloadInterstitial();
    _preloadRewarded();
  }

  // ─── Banner Ad ───────────────────────────────────────────────
  static BannerAd createBanner() {
    return BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
  }

  // ─── Interstitial Ad ─────────────────────────────────────────
  static void _preloadInterstitial() {
    if (_isInterstitialLoading) return;
    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _interstitialAd!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  static Future<bool> showInterstitial({
    VoidCallback? onDismissed,
  }) async {
    final progress = HiveService.getProgress();
    if (progress.isPremium) {
      onDismissed?.call();
      return false;
    }
    if (!progress.canShowInterstitial) {
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
        onDismissed?.call();
        HiveService.recordInterstitialShown();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _preloadInterstitial();
        onDismissed?.call();
      },
    );

    await _interstitialAd!.show();
    return true;
  }

  // ─── Rewarded Ad ─────────────────────────────────────────────
  static void _preloadRewarded() {
    if (_isRewardedLoading) return;
    _isRewardedLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isRewardedLoading = false;
        },
      ),
    );
  }

  static Future<bool> showRewarded({
    required Function(RewardItem reward) onRewarded,
    VoidCallback? onDismissed,
  }) async {
    final progress = HiveService.getProgress();
    if (progress.isPremium) return false;
    if (_rewardedAd == null) {
      _preloadRewarded();
      return false;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _preloadRewarded();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _preloadRewarded();
        onDismissed?.call();
      },
    );

    await _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      onRewarded(reward);
    });
    return true;
  }

  static void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}

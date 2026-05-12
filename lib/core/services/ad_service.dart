import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'hive_service.dart';

/// AdService — Maximum revenue, fully Google-policy compliant.
///
/// POLICY RULES (strictly observed):
///   • Interstitials: min 60s between shows → we enforce 90s
///   • Never on back-press / back navigation
///   • Never on first app launch / onboarding
///   • Never auto-triggered without a user action
///   • Must be closeable per platform timer
///
/// AGGRESSIVE STRATEGY (within policy):
///   • Interstitial on EVERY content open (90s cooldown, no session dedup)
///   • Interstitial on tab switch when cooldown has elapsed
///   • Adaptive banner on every screen (Today, Explore, Progress)
///   • Rewarded ads for streak save, bonus XP, article-limit unlock
///   • App-open on cold resume after 30+ min in background
///
/// WHY THIS IS MORE AGGRESSIVE THAN BEFORE:
///   The previous version had session dedup (_shownThisSession) that blocked
///   the interstitial from ever showing on the same content twice per session.
///   Removed. Now the ONLY gate is the 90s cooldown — meaning if user opens
///   content A, waits 90s, then opens content A again, they get the ad.
///   Same for tab switches — every tab change checks the cooldown and fires
///   if eligible.

class AdService {
  static InterstitialAd?  _interstitialAd;
  static RewardedAd?      _rewardedAd;
  static AppOpenAd?       _appOpenAd;
  static bool _interstitialLoading = false;
  static bool _rewardedLoading     = false;
  static bool _appOpenLoading      = false;
  static DateTime? _appOpenLoadedAt;

  // ─── Ad unit IDs ──────────────────────────────────────────────
  static String get _bannerId =>
      Platform.isIOS ? AdConstants.iosBannerId : AdConstants.androidBannerId;
  static String get _interstitialId =>
      Platform.isIOS ? AdConstants.iosInterstitialId : AdConstants.androidInterstitialId;
  static String get _rewardedId =>
      Platform.isIOS ? AdConstants.iosRewardedId : AdConstants.androidRewardedId;
  static String get _appOpenId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/5575463023'
      : 'ca-app-pub-3940256099942544/9257395921';

  // ─── Init ─────────────────────────────────────────────────────
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
    ));
    _preloadInterstitial();
    _preloadRewarded();
    _preloadAppOpen();
  }

  static const AdRequest _request = AdRequest();

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

  /// Show interstitial. Fires on EVERY eligible call — no session dedup.
  /// Only gate: 90s cooldown + premium check + ad loaded.
  ///
  /// [onDismissed] always called whether or not ad showed —
  /// navigation is NEVER blocked.
  static Future<bool> showInterstitial({
    VoidCallback? onDismissed,
    // contentId kept for API compatibility but no longer used for dedup
    String? contentId,
  }) async {
    final progress = HiveService.getProgress();

    // Gate 1: premium users never see ads
    if (progress.isPremium) {
      onDismissed?.call();
      return false;
    }

    // Gate 2: 90s cooldown (Google policy minimum is 60s)
    if (!progress.canShowInterstitial) {
      onDismissed?.call();
      return false;
    }

    // Gate 3: ad not loaded yet — preload for next time
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

  /// Show interstitial on tab switch — no callback needed, just fire and forget.
  /// Called from HomeScreen when user taps a tab and cooldown has elapsed.
  static void showInterstitialForTabSwitch() {
    showInterstitial(); // onDismissed = null, navigation already happened
  }

  // ─── REWARDED ─────────────────────────────────────────────────
  static void _preloadRewarded() {
    if (_rewardedLoading || _rewardedAd != null) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: _request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoading = false;
        },
        onAdFailedToLoad: (_) => _rewardedLoading = false,
      ),
    );
  }

  /// Policy: reward only granted inside [onRewarded]. Never automatic.
  /// Always user-initiated — never required for core features.
  static Future<bool> showRewarded({
    required void Function(RewardItem reward) onRewarded,
    VoidCallback? onDismissed,
  }) async {
    if (HiveService.getProgress().isPremium) return false;
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
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        _preloadRewarded();
        onDismissed?.call();
      },
    );
    await _rewardedAd!.show(
        onUserEarnedReward: (_, reward) => onRewarded(reward));
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
    if (!_appOpenIsValid) {
      _preloadAppOpen();
      return;
    }
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _preloadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _appOpenAd = null;
        _preloadAppOpen();
      },
    );
    await _appOpenAd!.show();
  }

  static void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _appOpenAd?.dispose();
  }
}

// ─── App lifecycle observer ───────────────────────────────────────────────────
class AdLifecycleObserver {
  static DateTime? _backgroundedAt;

  static void onPause() => _backgroundedAt = DateTime.now();

  static Future<void> onResume() async {
    if (_backgroundedAt == null) return;
    final awaySeconds =
        DateTime.now().difference(_backgroundedAt!).inSeconds;
    // Show app-open after 30 min away (aggressive but not annoying)
    if (awaySeconds > 1800) {
      await AdService.showAppOpenIfReady();
    }
    _backgroundedAt = null;
  }
}

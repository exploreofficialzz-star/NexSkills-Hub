import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'hive_service.dart';

/// AdService — Aggressive but fully policy-compliant ad strategy
///
/// Interstitial policy (Google):
///  • Min 60 seconds between shows → we use 90s (safety margin)
///  • Never on back-press or back navigation
///  • Never auto-triggered; always tied to a user navigation action
///  • Not shown on app first launch / onboarding
///
/// Session dedup rule (UX + policy best practice):
///  • Each content item (by ID) shows an interstitial AT MOST ONCE per
///    app session. Repeat opens of the same content skip the ad.
///  • The 90s cooldown is ALSO enforced, so whichever gate fires first wins.
///
/// Ad placements:
///  1. Adaptive banner — content viewer (below video info), Explore, Today
///  2. Interstitial — before opening content (once/item/session + 90s cooldown)
///  3. Rewarded — streak save, bonus lesson, article-limit unlock
///  4. App-open — cold resume after 30+ min away

class AdService {
  // ─── Session interstitial dedup ───────────────────────────────
  // Cleared when app comes back from a long background (AdLifecycleObserver)
  static final Set<String> _shownThisSession = {};

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

  /// Show interstitial before navigating to content.
  ///
  /// [contentId] — unique ID of the content item (resource.id / step.url).
  ///   If provided, the interstitial only shows ONCE per session for that item.
  ///   Pass null for non-content navigation (e.g. opening Premium screen).
  ///
  /// [onDismissed] — always called regardless of whether the ad showed,
  ///   so navigation is NEVER blocked.
  static Future<bool> showInterstitial({
    String? contentId,
    VoidCallback? onDismissed,
  }) async {
    final progress = HiveService.getProgress();

    // Gate 1: premium users never see ads
    if (progress.isPremium) { onDismissed?.call(); return false; }

    // Gate 2: session dedup — same content item only gets one interstitial
    if (contentId != null && _shownThisSession.contains(contentId)) {
      onDismissed?.call();
      return false;
    }

    // Gate 3: 90s cooldown between any interstitials
    if (!progress.canShowInterstitial) { onDismissed?.call(); return false; }

    // Gate 4: ad not loaded yet
    if (_interstitialAd == null) {
      _preloadInterstitial();
      onDismissed?.call();
      return false;
    }

    // All gates passed — mark this item as shown for the session
    if (contentId != null) _shownThisSession.add(contentId);

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

  /// Policy: reward only granted inside [onRewarded], never automatically.
  /// Always user-initiated — never required for core features.
  static Future<bool> showRewarded({
    required void Function(RewardItem reward) onRewarded,
    VoidCallback? onDismissed,
  }) async {
    if (HiveService.getProgress().isPremium) return false;
    if (_rewardedAd == null) { _preloadRewarded(); return false; }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _rewardedAd = null; _preloadRewarded(); onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _rewardedAd = null; _preloadRewarded(); onDismissed?.call();
      },
    );
    await _rewardedAd!.show(onUserEarnedReward: (_, reward) => onRewarded(reward));
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
          _appOpenAd = ad; _appOpenLoading = false;
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
    _appOpenAd?.dispose();
  }
}

// ─── App lifecycle observer ───────────────────────────────────────────────────
class AdLifecycleObserver {
  static DateTime? _backgroundedAt;

  static void onPause() => _backgroundedAt = DateTime.now();

  static Future<void> onResume() async {
    if (_backgroundedAt == null) return;
    final awaySeconds = DateTime.now().difference(_backgroundedAt!).inSeconds;
    if (awaySeconds > 1800) {
      // Clear session dedup after 30 min away — fresh session
      AdService._shownThisSession.clear();
      await AdService.showAppOpenIfReady();
    }
    _backgroundedAt = null;
  }
}

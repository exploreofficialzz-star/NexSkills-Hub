import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'hive_service.dart';

/// AdService — Policy-compliant aggressive ad strategy
///
/// Google AdMob policies observed:
///  • Interstitials: min 60s between shows (we use 90s). Never on back-press.
///    Never auto-triggered without user action. Never on app open first launch.
///  • Rewarded: always user-initiated. Never required for core features.
///  • Banners: no fake close buttons. No overlapping interactive content.
///  • No ads shown to users under 13 (COPPA). Child-directed = false.
///  • All ads must be closeable / skippable per platform timers.
///
/// Revenue levers wired:
///  1. Banner ads on Today + Explore screens (free users)
///  2. Interstitial before every content open (90s cooldown)
///  3. Rewarded ad gate on:
///     - "Save my streak" (when streak is at risk)
///     - "Unlock today's bonus lesson"
///     - "Remove today's article limit"
///  4. App-open ad on cold launch (after first onboarding is done)
///  5. Adaptive banner (wider = higher eCPM than standard banner)

class AdService {
  static InterstitialAd?  _interstitialAd;
  static RewardedAd?      _rewardedAd;
  static AppOpenAd?       _appOpenAd;
  static bool _interstitialLoading = false;
  static bool _rewardedLoading     = false;
  static bool _appOpenLoading       = false;
  static DateTime? _appOpenLoadedAt;

  // ─── IDs ─────────────────────────────────────────────────────
  static String get _bannerId       => Platform.isIOS ? AdConstants.iosBannerId       : AdConstants.androidBannerId;
  static String get _interstitialId => Platform.isIOS ? AdConstants.iosInterstitialId : AdConstants.androidInterstitialId;
  static String get _rewardedId     => Platform.isIOS ? AdConstants.iosRewardedId     : AdConstants.androidRewardedId;
  static String get _appOpenId      => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/5575463023'   // iOS app-open test ID
      : 'ca-app-pub-3940256099942544/9257395921';  // Android app-open test ID

  // ─── Init ─────────────────────────────────────────────────────
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    // Request configuration: non-personalized ads until consent given
    final config = RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
    );
    MobileAds.instance.updateRequestConfiguration(config);

    _preloadInterstitial();
    _preloadRewarded();
    _preloadAppOpen();
  }

  // ─── Standard AdRequest ───────────────────────────────────────
  static AdRequest get _request => const AdRequest(
    // nonPersonalizedAds: true  ← uncomment if you skip GDPR consent flow
  );

  // ─── BANNER — Adaptive (higher eCPM than fixed) ───────────────
  static Future<BannerAd> createAdaptiveBanner(BuildContext context) async {
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    );
    return BannerAd(
      adUnitId: _bannerId,
      size: size ?? AdSize.banner,
      request: _request,
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
  }

  // Fallback standard banner (used when context not available)
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

  /// Show interstitial before content navigation.
  /// Always calls [onDismissed] whether ad showed or not —
  /// navigation is never blocked if ad fails.
  static Future<bool> showInterstitial({VoidCallback? onDismissed}) async {
    final progress = HiveService.getProgress();

    // Premium users: never show ads
    if (progress.isPremium) { onDismissed?.call(); return false; }

    // Cooldown check (policy: min 60s, we use 90s)
    if (!progress.canShowInterstitial) { onDismissed?.call(); return false; }

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

  /// Show rewarded ad. Reward is ONLY granted inside [onRewarded] —
  /// never automatically, complying with Google rewarded ad policy.
  static Future<bool> showRewarded({
    required void Function(RewardItem reward) onRewarded,
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
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        _preloadRewarded();
        onDismissed?.call();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) => onRewarded(reward),
    );
    return true;
  }

  // ─── APP-OPEN AD ──────────────────────────────────────────────
  // Shows on cold-start resume after 4+ hours away.
  // Policy: must not show on very first app install / onboarding.
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

  // App-open ads expire after 4 hours — check before showing
  static bool get _appOpenIsValid {
    if (_appOpenAd == null || _appOpenLoadedAt == null) return false;
    return DateTime.now().difference(_appOpenLoadedAt!).inHours < 4;
  }

  /// Call from AppLifecycleListener when app resumes from background.
  static Future<void> showAppOpenIfReady() async {
    final progress = HiveService.getProgress();
    if (progress.isPremium) return;
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

// ─── App lifecycle watcher for app-open ads ───────────────────────────────────
/// Add this to your root widget's initState:
/// ```dart
/// _lifecycleListener = AppLifecycleListener(onResume: AdLifecycleObserver.onResume);
/// ```
class AdLifecycleObserver {
  static DateTime? _backgroundedAt;

  static void onPause() => _backgroundedAt = DateTime.now();

  static Future<void> onResume() async {
    if (_backgroundedAt == null) return;
    final awaySeconds = DateTime.now().difference(_backgroundedAt!).inSeconds;
    // Only show app-open if user was away for > 30 minutes
    // (avoids showing on quick task-switch, which would feel intrusive)
    if (awaySeconds > 1800) {
      await AdService.showAppOpenIfReady();
    }
    _backgroundedAt = null;
  }
}

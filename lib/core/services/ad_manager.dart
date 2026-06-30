import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'hive_service.dart';
import 'unity_ads_service.dart';

/// AdManager — precise, professionally-placed ad orchestration.
///
/// Placement rules (per product spec):
///
/// TODAY TAB
///   • Banner   : inline between streak card and lesson (always)
///   • Interstitial: EVERY "Start Today's Lesson" tap (60s cooldown guards freq)
///
/// MY PATH TAB
///   • Interstitial: ODD steps (1, 3, 5, 7…) → show ad
///                   EVEN steps (2, 4, 6, 8…) → navigate directly, no ad
///   • Native ad : inserted every 4 steps in the step list
///
/// EXPLORE TAB
///   • Banner   : at the bottom of the scrollable list
///   • Interstitial: every 4th content open (clicks 4, 8, 12…)
///   • Native ad : every 3 items in the feed
///
/// GLOBAL RULES
///   • Premium users → zero ads
///   • 60-second global cooldown between interstitials (AdMob policy min)
///   • Auto-reload immediately after every ad dismiss
///   • App-open ads: excluded per product decision
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  // ── Test IDs (Google's official test units) ───────────────────
  static const _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewardedId     = 'ca-app-pub-3940256099942544/5224354917';
  static const _testBannerId       = 'ca-app-pub-3940256099942544/6300978111';
  static const _testRewardedIntId  = 'ca-app-pub-3940256099942544/5354046379';
  static const _testNativeId       = 'ca-app-pub-3940256099942544/2247696110';

  // ── Live-mode switch ──────────────────────────────────────────
  // false = AdConstants real IDs (production revenue, both networks live)
  static const _useTestIds = false;

  // ── ID getters ─────────────────────────────────────────────────
  // _useTestIds=true  → test IDs (loads in any build, no revenue)
  // _useTestIds=false → AdConstants real IDs (production revenue)
  String get _interstitialId => _useTestIds ? _testInterstitialId
      : Platform.isIOS ? AdConstants.iosInterstitialId : AdConstants.androidInterstitialId;

  String get _rewardedId => _useTestIds ? _testRewardedId
      : Platform.isIOS ? AdConstants.iosRewardedId : AdConstants.androidRewardedId;

  String get _bannerId => _useTestIds ? _testBannerId
      : Platform.isIOS ? AdConstants.iosBannerId : AdConstants.androidBannerId;

  String get _rewardedIntId => _useTestIds ? _testRewardedIntId
      : Platform.isIOS ? AdConstants.iosRewardedInterstitialId : AdConstants.androidRewardedInterstitialId;

  String get _nativeId => _useTestIds ? _testNativeId
      : Platform.isIOS ? AdConstants.iosNativeId : AdConstants.androidNativeId;

  String get nativeAdUnitId => _nativeId;

  // ── Ad instances ───────────────────────────────────────────────
  InterstitialAd?         _interstitial;
  RewardedAd?             _rewarded;
  RewardedInterstitialAd? _rewardedInterstitial;

  bool _interstitialLoading = false;
  bool _rewardedLoading     = false;
  bool _rewardedIntLoading  = false;

  // ── 60-second global cooldown ──────────────────────────────────
  DateTime? _lastShownAt;
  static const _cooldownSeconds = AdConstants.interstitialCooldownSeconds; // 90s

  // ── Explore click counter ──────────────────────────────────────
  // Pattern: every 4th content open gets an ad (clicks 4, 8, 12…)
  int _exploreClickCount = 0;

  bool get isInterstitialReady => _interstitial != null;
  bool get isRewardedReady     => _rewarded != null;

  static const _request = AdRequest();

  Timer? _retryTimer;

  // ── Init (postFrameCallback only) ─────────────────────────────
  // Both networks preload in parallel — AdMob is primary, Unity fills
  // the gap whenever AdMob has nothing ready at show-time.
  //
  // Also starts a 45s background retry loop. AdMob frequently returns
  // "no fill" for brand-new ad units while Google's systems ramp up
  // demand for that unit (commonly 24–72h) — this is an account/inventory
  // constraint, not something a single load() call can fix. Retrying
  // periodically maximises the odds a creative is actually ready by the
  // time the user taps something, rather than only retrying reactively
  // on every failed show() call.
  Future<void> init() async {
    loadInterstitial();
    loadRewarded();
    loadRewardedInterstitial();
    UnityAdsService.instance.loadInterstitial();
    UnityAdsService.instance.loadRewarded();

    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_interstitial == null) loadInterstitial();
      if (_rewarded == null) loadRewarded();
      if (_rewardedInterstitial == null) loadRewardedInterstitial();
      UnityAdsService.instance.loadInterstitial();
      UnityAdsService.instance.loadRewarded();
    });
  }

  // ─────────────────────────────────────────────────────────────
  // INTERSTITIAL — core
  // ─────────────────────────────────────────────────────────────
  Future<void> loadInterstitial() async {
    if (_interstitialLoading || _interstitial != null) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: _request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _interstitialLoading = false;
          ad.setImmersiveMode(true);
        },
        onAdFailedToLoad: (_) => _interstitialLoading = false,
      ),
    );
  }

  bool _isCoolingDown() =>
      _lastShownAt != null &&
      DateTime.now().difference(_lastShownAt!).inSeconds < _cooldownSeconds;

  /// Raw show — [onDismissed] ALWAYS fires, navigation never blocked.
  /// Mediation: AdMob is tried first; if it has no creative ready, Unity
  /// Ads is attempted before giving up. This is the single waterfall used
  /// by every interstitial placement rule below.
  Future<bool> showInterstitial({VoidCallback? onDismissed}) async {
    if (HiveService.getProgress().isPremium) { onDismissed?.call(); return false; }
    if (_isCoolingDown())                    { onDismissed?.call(); return false; }

    if (_interstitial == null) {
      loadInterstitial();
      // AdMob has nothing ready — try Unity before giving up entirely.
      final shownByUnity = await UnityAdsService.instance.showInterstitial(
        onDismissed: onDismissed,
      );
      if (shownByUnity) _lastShownAt = DateTime.now();
      return shownByUnity;
    }
    _interstitial!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _interstitial = null;
        _lastShownAt = DateTime.now();
        loadInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _interstitial = null;
        loadInterstitial();
        onDismissed?.call();
      },
    );
    await _interstitial!.show();
    return true;
  }

  /// Timeout fallback (Today tab "Start Lesson" — 3s max wait).
  Future<void> showInterstitialWithTimeout({
    required VoidCallback onDismissed,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_interstitial == null) {
      loadInterstitial();
      await Future.delayed(timeout);
      onDismissed();
      return;
    }
    await showInterstitial(onDismissed: onDismissed);
  }

  // ─────────────────────────────────────────────────────────────
  // TODAY TAB — "Start Today's Lesson"
  // Attempt interstitial on EVERY tap. 60s cooldown is the guard.
  // ─────────────────────────────────────────────────────────────
  Future<void> showInterstitialForTodayLesson({
    required VoidCallback onDismissed,
  }) async {
    if (HiveService.getProgress().isPremium) { onDismissed(); return; }
    // Every tap attempts an ad — cooldown naturally limits to 1/min
    await showInterstitialWithTimeout(onDismissed: onDismissed);
  }

  // ─────────────────────────────────────────────────────────────
  // MY PATH TAB — step-based rule
  // Odd steps  (1, 3, 5, 7…) → show interstitial
  // Even steps (2, 4, 6, 8…) → navigate directly, no ad
  // ─────────────────────────────────────────────────────────────
  Future<void> showInterstitialOnLessonTap({
    required VoidCallback onDismissed,
    required int stepOrder,
  }) async {
    if (HiveService.getProgress().isPremium) { onDismissed(); return; }
    if (stepOrder.isOdd) {
      await showInterstitial(onDismissed: onDismissed);
    } else {
      onDismissed(); // Even steps — no ad
    }
  }

  // ─────────────────────────────────────────────────────────────
  // EXPLORE TAB — every-4th-click rule
  // Clicks 4, 8, 12… → interstitial
  // Clicks 1, 2, 3, 5, 6, 7… → navigate directly
  // ─────────────────────────────────────────────────────────────
  Future<void> showInterstitialOnExploreClick({
    required VoidCallback onDismissed,
  }) async {
    if (HiveService.getProgress().isPremium) { onDismissed(); return; }
    _exploreClickCount++;
    if (_exploreClickCount % 4 == 0) {
      await showInterstitial(onDismissed: onDismissed);
    } else {
      onDismissed();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // REWARDED (locked lesson unlock — opt-in)
  // ─────────────────────────────────────────────────────────────
  Future<void> loadRewarded() async {
    if (_rewardedLoading || _rewarded != null) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: _request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { _rewarded = ad; _rewardedLoading = false; },
        onAdFailedToLoad: (_) => _rewardedLoading = false,
      ),
    );
  }

  Future<void> showRewarded({
    required void Function(RewardItem) onEarned,
    VoidCallback? onDismissed,
  }) async {
    if (HiveService.getProgress().isPremium) { onDismissed?.call(); return; }
    if (_rewarded == null) {
      loadRewarded();
      // AdMob rewarded not ready — try Unity's rewarded placement.
      // Unity's plugin has no RewardItem object of its own, so we build a
      // real RewardItem (amount=1, type='unity_reward') to satisfy the
      // shared onEarned(RewardItem) signature used throughout the app.
      await UnityAdsService.instance.showRewarded(
        onEarned: () => onEarned(RewardItem(1, 'unity_reward')),
        onDismissed: onDismissed,
      );
      return;
    }
    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _rewarded = null; loadRewarded(); onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _rewarded = null; loadRewarded(); onDismissed?.call();
      },
    );
    await _rewarded!.show(onUserEarnedReward: (_, r) => onEarned(r));
  }

  // ─────────────────────────────────────────────────────────────
  // REWARDED INTERSTITIAL (XP boost — opt-in)
  // ─────────────────────────────────────────────────────────────
  Future<void> loadRewardedInterstitial() async {
    if (_rewardedIntLoading || _rewardedInterstitial != null) return;
    _rewardedIntLoading = true;
    RewardedInterstitialAd.load(
      adUnitId: _rewardedIntId,
      request: _request,
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) { _rewardedInterstitial = ad; _rewardedIntLoading = false; },
        onAdFailedToLoad: (_) => _rewardedIntLoading = false,
      ),
    );
  }

  Future<void> showRewardedInterstitial({
    required void Function(RewardItem) onEarned,
    VoidCallback? onDismissed,
  }) async {
    if (HiveService.getProgress().isPremium) { onDismissed?.call(); return; }
    if (_rewardedInterstitial == null) {
      loadRewardedInterstitial(); onDismissed?.call(); return;
    }
    _rewardedInterstitial!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _rewardedInterstitial = null;
        loadRewardedInterstitial(); onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _rewardedInterstitial = null;
        loadRewardedInterstitial(); onDismissed?.call();
      },
    );
    await _rewardedInterstitial!.show(onUserEarnedReward: (_, r) => onEarned(r));
  }

  // ─────────────────────────────────────────────────────────────
  // BANNER (each screen creates its own instance)
  // ─────────────────────────────────────────────────────────────
  BannerAd createBannerAd([AdSize size = AdSize.banner]) => BannerAd(
        adUnitId: _bannerId,
        size: size,
        request: _request,
        listener: BannerAdListener(
          onAdLoaded: (_) {}, // no-op — caller checks via _loaded flag
          onAdFailedToLoad: (ad, _) => ad.dispose(),
        ),
      );

  void dispose() {
    _retryTimer?.cancel();
    _interstitial?.dispose();
    _rewarded?.dispose();
    _rewardedInterstitial?.dispose();
  }
}

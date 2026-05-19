import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'hive_service.dart';

/// AdManager — centralized ad orchestration singleton.
///
/// Strategy (aggressive, per product spec):
///   • Interstitial attempted on EVERY lesson tap and EVERY content click.
///   • 60-second global cooldown (AdMob policy minimum) prevents back-to-back ads.
///   • Auto-reload immediately after each ad is dismissed.
///   • Premium users: zero ads, all paths bypass immediately.
///   • App-open ads: NOT included per product decision.
///   • Tab-switch ads: NOT included per product decision.
///
/// Ad formats included:
///   ✓ Banner (sticky footer + inline)
///   ✓ Interstitial (lessons + content clicks)
///   ✓ Rewarded (locked lesson unlock)
///   ✓ Rewarded Interstitial (XP boost, opt-in)
///   ✗ App-open (excluded per product decision)
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  // ── Test IDs (Google official) ─────────────────────────────────
  static const _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewardedId     = 'ca-app-pub-3940256099942544/5224354917';
  static const _testBannerId       = 'ca-app-pub-3940256099942544/6300978111';
  static const _testRewardedIntId  = 'ca-app-pub-3940256099942544/5354046379';
  static const _testNativeId       = 'ca-app-pub-3940256099942544/2247696110';

  // ── Real IDs — replace before release ─────────────────────────
  static const _realInterstitialId = 'ca-app-pub-REPLACE/REPLACE';
  static const _realRewardedId     = 'ca-app-pub-REPLACE/REPLACE';
  static const _realBannerId       = 'ca-app-pub-REPLACE/REPLACE';
  static const _realRewardedIntId  = 'ca-app-pub-REPLACE/REPLACE';
  static const _realNativeId       = 'ca-app-pub-REPLACE/REPLACE';

  String get _interstitialId => kDebugMode ? _testInterstitialId : _realInterstitialId;
  String get _rewardedId     => kDebugMode ? _testRewardedId     : _realRewardedId;
  String get _bannerId       => kDebugMode ? _testBannerId       : _realBannerId;
  String get _rewardedIntId  => kDebugMode ? _testRewardedIntId  : _realRewardedIntId;
  String get _nativeId       => kDebugMode ? _testNativeId       : _realNativeId;

  // ── Ad instances ───────────────────────────────────────────────
  InterstitialAd?         _interstitial;
  RewardedAd?             _rewarded;
  RewardedInterstitialAd? _rewardedInterstitial;

  bool _interstitialLoading = false;
  bool _rewardedLoading     = false;
  bool _rewardedIntLoading  = false;

  // 60-second global interstitial cooldown (AdMob policy minimum)
  DateTime? _lastInterstitialShownAt;
  static const _cooldownSeconds = 60;

  bool get isInterstitialReady => _interstitial != null;
  bool get isRewardedReady     => _rewarded != null;

  static const _request = AdRequest();

  // ── Init — called from HomeScreen postFrameCallback only ───────
  Future<void> init() async {
    loadInterstitial();
    loadRewarded();
    loadRewardedInterstitial();
  }

  // ─────────────────────────────────────────────────────────────
  // INTERSTITIAL
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

  /// Attempt to show an interstitial.
  ///
  /// [onDismissed] is ALWAYS called — navigation is never blocked.
  /// Returns true if an ad was actually displayed.
  ///
  /// Aggressive: call this on every lesson tap and every content click.
  /// The 60-second cooldown prevents back-to-back ads while keeping
  /// the experience monetised at the maximum allowable frequency.
  Future<bool> showInterstitial({VoidCallback? onDismissed}) async {
    final progress = HiveService.getProgress();
    if (progress.isPremium) {
      onDismissed?.call();
      return false;
    }

    // 60-second global cooldown
    if (_lastInterstitialShownAt != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialShownAt!).inSeconds;
      if (elapsed < _cooldownSeconds) {
        onDismissed?.call();
        return false;
      }
    }

    if (_interstitial == null) {
      loadInterstitial(); // start preloading for next time
      onDismissed?.call();
      return false;
    }

    _interstitial!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        _lastInterstitialShownAt = DateTime.now();
        loadInterstitial(); // reload immediately after dismiss
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitial = null;
        loadInterstitial();
        onDismissed?.call();
      },
    );
    await _interstitial!.show();
    return true;
  }

  /// Show interstitial with a timeout fallback.
  /// If the ad is not ready within [timeout], [onDismissed] fires
  /// immediately so navigation is never blocked.
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
  // REWARDED  (locked lesson unlock — opt-in only)
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
    if (_rewarded == null) { loadRewarded(); onDismissed?.call(); return; }
    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _rewarded = null; loadRewarded();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _rewarded = null; loadRewarded();
        onDismissed?.call();
      },
    );
    await _rewarded!.show(onUserEarnedReward: (_, r) => onEarned(r));
  }

  // ─────────────────────────────────────────────────────────────
  // REWARDED INTERSTITIAL  (XP boost — opt-in only)
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
        ad.dispose(); _rewardedInterstitial = null; loadRewardedInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _rewardedInterstitial = null; loadRewardedInterstitial();
        onDismissed?.call();
      },
    );
    await _rewardedInterstitial!.show(onUserEarnedReward: (_, r) => onEarned(r));
  }

  // ─────────────────────────────────────────────────────────────
  // BANNER  (created on demand per screen)
  // ─────────────────────────────────────────────────────────────
  BannerAd createBannerAd([AdSize size = AdSize.banner]) => BannerAd(
        adUnitId: _bannerId,
        size: size,
        request: _request,
        listener: BannerAdListener(onAdFailedToLoad: (ad, _) => ad.dispose()),
      );

  // ─────────────────────────────────────────────────────────────
  // NATIVE  (created on demand per slot in Explore)
  // ─────────────────────────────────────────────────────────────
  String get nativeAdUnitId => _nativeId;

  // ─────────────────────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────────────────────
  void dispose() {
    _interstitial?.dispose();
    _rewarded?.dispose();
    _rewardedInterstitial?.dispose();
  }
}

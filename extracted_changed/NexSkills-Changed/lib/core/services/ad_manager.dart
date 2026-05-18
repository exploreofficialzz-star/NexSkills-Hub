import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'hive_service.dart';

/// AdManager — centralized ad orchestration singleton.
///
/// Responsibilities:
///   - Every-other-tap interstitial rule per named section
///   - 60-second global interstitial cooldown (AdMob policy minimum)
///   - Auto-reload immediately after each ad is dismissed
///   - Per-section tap counters persisted in Hive across restarts
///   - Test IDs in debug mode, real IDs in release
///   - NEVER blocks navigation — [onDismissed] is always called
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  static const _tapCounterBox = 'ad_tap_counters';

  // ── Test IDs (Google's official test units) ──────────────────
  static const _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const _testRewardedIntId = 'ca-app-pub-3940256099942544/5354046379';

  // ── Real IDs — replace with values from AdMob console ────────
  static const _realInterstitialId = 'ca-app-pub-REPLACE/REPLACE';
  static const _realRewardedId = 'ca-app-pub-REPLACE/REPLACE';
  static const _realBannerId = 'ca-app-pub-REPLACE/REPLACE';
  static const _realRewardedIntId = 'ca-app-pub-REPLACE/REPLACE';

  String get _interstitialId =>
      kDebugMode ? _testInterstitialId : _realInterstitialId;
  String get _rewardedId => kDebugMode ? _testRewardedId : _realRewardedId;
  String get _bannerId => kDebugMode ? _testBannerId : _realBannerId;
  String get _rewardedIntId =>
      kDebugMode ? _testRewardedIntId : _realRewardedIntId;

  // ── Ad instances ─────────────────────────────────────────────
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  RewardedInterstitialAd? _rewardedInterstitial;

  bool _interstitialLoading = false;
  bool _rewardedLoading = false;
  bool _rewardedIntLoading = false;

  DateTime? _lastInterstitialShownAt;
  static const _cooldownSeconds = 60; // AdMob policy minimum

  bool get isInterstitialReady => _interstitial != null;
  bool get isRewardedReady => _rewarded != null;

  static const _request = AdRequest();

  // ── Init — call ONLY from postFrameCallback, never in main() ─
  Future<void> init() async {
    if (!Hive.isBoxOpen(_tapCounterBox)) {
      await Hive.openBox<int>(_tapCounterBox);
    }
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

  /// Show interstitial. [onDismissed] is ALWAYS called — navigation is
  /// never blocked even if the ad fails or the cooldown is active.
  /// Returns true if an ad was actually shown.
  Future<bool> showInterstitial({VoidCallback? onDismissed}) async {
    final progress = HiveService.getProgress();
    if (progress.isPremium) {
      onDismissed?.call();
      return false;
    }

    // 60-second global cooldown
    if (_lastInterstitialShownAt != null) {
      final elapsed =
          DateTime.now().difference(_lastInterstitialShownAt!).inSeconds;
      if (elapsed < _cooldownSeconds) {
        onDismissed?.call();
        return false;
      }
    }

    if (_interstitial == null) {
      loadInterstitial();
      onDismissed?.call();
      return false;
    }

    _interstitial!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        _lastInterstitialShownAt = DateTime.now();
        loadInterstitial(); // pre-load next immediately
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

  /// Show interstitial with a [timeout] fallback. If the ad is not ready
  /// in time, [onDismissed] fires immediately so navigation is never blocked.
  Future<void> showInterstitialWithTimeout({
    required VoidCallback onDismissed,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_interstitial == null) {
      loadInterstitial();
      // Wait briefly for the ad, then navigate regardless
      await Future.delayed(timeout);
      onDismissed();
      return;
    }
    // Ad is ready — show it, onDismissed fires after it closes
    await showInterstitial(onDismissed: onDismissed);
  }

  /// Every-other-tap interstitial for a named section.
  ///
  /// Tap counter is persisted in Hive so it survives restarts.
  /// Odd taps (1, 3, 5…) → show interstitial.
  /// Even taps (2, 4, 6…) → skip ad, navigate immediately.
  ///
  /// [sectionKey] — unique string per section, e.g. 'path_cards', 'lesson_taps'.
  Future<void> showInterstitialForSection(
    String sectionKey, {
    required VoidCallback onDismissed,
  }) async {
    final progress = HiveService.getProgress();
    if (progress.isPremium) {
      onDismissed();
      return;
    }

    // Read and increment the per-section counter
    final box = Hive.box<int>(_tapCounterBox);
    final current = box.get(sectionKey, defaultValue: 0)!;
    final next = current + 1;
    await box.put(sectionKey, next);

    // Odd taps → ad; even taps → skip
    if (next % 2 == 1) {
      await showInterstitial(onDismissed: onDismissed);
    } else {
      onDismissed();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // REWARDED
  // ─────────────────────────────────────────────────────────────
  Future<void> loadRewarded() async {
    if (_rewardedLoading || _rewarded != null) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: _request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _rewardedLoading = false;
        },
        onAdFailedToLoad: (_) => _rewardedLoading = false,
      ),
    );
  }

  Future<void> showRewarded({
    required void Function(RewardItem) onEarned,
    VoidCallback? onDismissed,
  }) async {
    if (HiveService.getProgress().isPremium) {
      onDismissed?.call();
      return;
    }
    if (_rewarded == null) {
      loadRewarded();
      onDismissed?.call();
      return;
    }
    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded = null;
        loadRewarded();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewarded = null;
        loadRewarded();
        onDismissed?.call();
      },
    );
    await _rewarded!.show(onUserEarnedReward: (_, r) => onEarned(r));
  }

  // ─────────────────────────────────────────────────────────────
  // REWARDED INTERSTITIAL  (opt-in only — Progress tab XP boost)
  // ─────────────────────────────────────────────────────────────
  Future<void> loadRewardedInterstitial() async {
    if (_rewardedIntLoading || _rewardedInterstitial != null) return;
    _rewardedIntLoading = true;
    RewardedInterstitialAd.load(
      adUnitId: _rewardedIntId,
      request: _request,
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitial = ad;
          _rewardedIntLoading = false;
        },
        onAdFailedToLoad: (_) => _rewardedIntLoading = false,
      ),
    );
  }

  Future<void> showRewardedInterstitial({
    required void Function(RewardItem) onEarned,
    VoidCallback? onDismissed,
  }) async {
    if (HiveService.getProgress().isPremium) {
      onDismissed?.call();
      return;
    }
    if (_rewardedInterstitial == null) {
      loadRewardedInterstitial();
      onDismissed?.call();
      return;
    }
    _rewardedInterstitial!.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedInterstitial = null;
        loadRewardedInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedInterstitial = null;
        loadRewardedInterstitial();
        onDismissed?.call();
      },
    );
    await _rewardedInterstitial!
        .show(onUserEarnedReward: (_, r) => onEarned(r));
  }

  // ─────────────────────────────────────────────────────────────
  // BANNER
  // ─────────────────────────────────────────────────────────────
  BannerAd createBannerAd([AdSize size = AdSize.banner]) => BannerAd(
        adUnitId: _bannerId,
        size: size,
        request: _request,
        listener:
            BannerAdListener(onAdFailedToLoad: (ad, _) => ad.dispose()),
      );

  // ─────────────────────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────────────────────
  void dispose() {
    _interstitial?.dispose();
    _rewarded?.dispose();
    _rewardedInterstitial?.dispose();
  }
}

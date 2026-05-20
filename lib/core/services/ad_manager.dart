import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'hive_service.dart';

/// AdManager — aggressive ad orchestration.
///
/// Ad formats:
///   ✓ Banner        — sticky footer + inline Today/Explore
///   ✓ Interstitial  — every 2-3 content clicks / lesson taps
///   ✓ Rewarded      — locked lesson unlock (opt-in)
///   ✓ Rewarded Int  — XP boost (opt-in)
///   ✓ Native        — every 3 items in Explore list
///   ✗ App-open      — excluded per product decision
///   ✗ Tab-switch    — excluded per product decision
///
/// Interstitial strategy:
///   Two independent counters (content & lessons) each using a
///   randomised 2-3 threshold:  clicks 2→ad, 3→ad, 2→ad, 3→ad …
///   The 60-second cooldown ensures AdMob policy compliance.
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();
  final _rng = Random();

  // ── Test IDs ───────────────────────────────────────────────────
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

  // ── 60-second global cooldown ──────────────────────────────────
  DateTime? _lastShownAt;
  static const _cooldownSeconds = 60;

  // ── Content click counter (Explore) ───────────────────────────
  // Threshold alternates 2 → 3 → 2 → 3 …
  int _contentClicks  = 0;
  int _contentThresh  = 2; // first ad after 2nd click

  // ── Lesson tap counter (My Path) ──────────────────────────────
  int _lessonTaps    = 0;
  int _lessonThresh  = 2; // first ad after 2nd lesson tap

  bool get isInterstitialReady => _interstitial != null;
  bool get isRewardedReady     => _rewarded != null;

  static const _request = AdRequest();

  // ── Init — postFrameCallback only ─────────────────────────────
  Future<void> init() async {
    loadInterstitial();
    loadRewarded();
    loadRewardedInterstitial();
  }

  // ─────────────────────────────────────────────────────────────
  // INTERSTITIAL — core show logic
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

  bool _isCoolingDown() {
    if (_lastShownAt == null) return false;
    return DateTime.now().difference(_lastShownAt!).inSeconds < _cooldownSeconds;
  }

  /// Raw show — used internally. [onDismissed] always fires.
  Future<bool> showInterstitial({VoidCallback? onDismissed}) async {
    if (HiveService.getProgress().isPremium) { onDismissed?.call(); return false; }
    if (_isCoolingDown())                    { onDismissed?.call(); return false; }
    if (_interstitial == null) {
      loadInterstitial();
      onDismissed?.call();
      return false;
    }
    _interstitial!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        _lastShownAt = DateTime.now();
        loadInterstitial();
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

  /// Show with a 3-second timeout fallback (Today tab "Start Lesson").
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
  // AGGRESSIVE CONTENT CLICK  (Explore tab)
  // Ad fires every 2-3 content clicks — randomised threshold.
  // 60s cooldown ensures AdMob compliance.
  // ─────────────────────────────────────────────────────────────
  Future<void> showInterstitialOnContentClick({
    required VoidCallback onDismissed,
  }) async {
    if (HiveService.getProgress().isPremium) { onDismissed(); return; }
    _contentClicks++;
    if (_contentClicks >= _contentThresh) {
      _contentClicks = 0;
      // Alternate 2 → 3 → 2 → 3 with slight randomness
      _contentThresh = 2 + _rng.nextInt(2); // 2 or 3
      await showInterstitial(onDismissed: onDismissed);
    } else {
      onDismissed();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // AGGRESSIVE LESSON TAP  (My Path tab)
  // Same 2-3 pattern but tracked independently from content clicks.
  // ─────────────────────────────────────────────────────────────
  Future<void> showInterstitialOnLessonTap({
    required VoidCallback onDismissed,
  }) async {
    if (HiveService.getProgress().isPremium) { onDismissed(); return; }
    _lessonTaps++;
    if (_lessonTaps >= _lessonThresh) {
      _lessonTaps = 0;
      _lessonThresh = 2 + _rng.nextInt(2); // 2 or 3
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
        ad.dispose(); _rewarded = null; loadRewarded(); onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _rewarded = null; loadRewarded(); onDismissed?.call();
      },
    );
    await _rewarded!.show(onUserEarnedReward: (_, r) => onEarned(r));
  }

  // ─────────────────────────────────────────────────────────────
  // REWARDED INTERSTITIAL
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
  // BANNER  (created on demand — each screen owns its instance)
  // ─────────────────────────────────────────────────────────────
  BannerAd createBannerAd([AdSize size = AdSize.banner]) => BannerAd(
        adUnitId: _bannerId,
        size: size,
        request: _request,
        listener: BannerAdListener(onAdFailedToLoad: (ad, _) => ad.dispose()),
      );

  // ─────────────────────────────────────────────────────────────
  // NATIVE  (unit ID exposed; each slot creates its own NativeAd)
  // ─────────────────────────────────────────────────────────────
  String get nativeAdUnitId => _nativeId;

  void dispose() {
    _interstitial?.dispose();
    _rewarded?.dispose();
    _rewardedInterstitial?.dispose();
  }
}

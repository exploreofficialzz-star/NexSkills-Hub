import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'ad_manager.dart';

/// AdService — SDK initialisation + legacy ad helpers.
///
/// IMPORTANT: as of this revision, AdService no longer maintains its own
/// InterstitialAd/RewardedAd/RewardedInterstitialAd instances. It previously
/// did, in parallel with AdManager, which meant BOTH classes independently
/// called InterstitialAd.load() / RewardedAd.load() for the exact same
/// ad unit IDs at app start — two concurrent load requests racing each
/// other for the same inventory, plus two disconnected ready-state flags
/// and two disconnected cooldown clocks for what should be one ad slot.
/// Concretely, this caused the "bonus XP" rewarded ad to behave
/// differently on path_detail_screen (which called AdManager.showRewarded)
/// than on content_viewer_screen/resource_viewer_screen (which called
/// AdService.showRewarded) — same ad unit, two unrelated readiness states.
///
/// AdService now delegates every show*() call to AdManager.instance, which
/// is the single source of truth for every interstitial/rewarded/rewarded-
/// interstitial instance in the app. This removes the duplicate load calls
/// entirely while keeping every existing call site (shared_widgets.dart,
/// content_viewer_screen.dart, resource_viewer_screen.dart) unchanged —
/// none of them inspect the bool return value, so the signatures below
/// stay identical on purpose.
///
/// App-open ads are intentionally NOT included per product decision.
class AdService {
  static String get _bannerId =>
      Platform.isIOS ? AdConstants.iosBannerId : AdConstants.androidBannerId;

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

  // ── Adaptive / standard banner ─────────────────────────────────
  // Banner has no duplication issue — each screen creates its own
  // independent BannerAd instance by design (that's how AdMob banners
  // work), so this stays exactly as it was.
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

  // ── Interstitial — delegates to AdManager's single shared instance ──
  /// [onDismissed] is always called — navigation is never blocked.
  static Future<bool> showInterstitial({
    VoidCallback? onDismissed,
    String? contentId,
  }) async {
    return AdManager.instance.showInterstitial(onDismissed: onDismissed);
  }

  // ── Rewarded — delegates to AdManager's single shared instance ──────
  static Future<bool> showRewarded({
    required void Function(RewardItem reward) onRewarded,
    VoidCallback? onDismissed,
  }) async {
    var earned = false;
    await AdManager.instance.showRewarded(
      onEarned: (r) { earned = true; onRewarded(r); },
      onDismissed: onDismissed,
    );
    return earned;
  }

  // ── Rewarded Interstitial — delegates to AdManager's shared instance ──
  static Future<bool> showRewardedInterstitial({
    required void Function(RewardItem reward) onRewarded,
    VoidCallback? onDismissed,
  }) async {
    var earned = false;
    await AdManager.instance.showRewardedInterstitial(
      onEarned: (r) { earned = true; onRewarded(r); },
      onDismissed: onDismissed,
    );
    return earned;
  }

  /// No-op — AdManager.instance.dispose() now owns the actual ad instances.
  static void dispose() {}
}

// ── Lifecycle observer (app-resume handler) ────────────────────────────────────
class AdLifecycleObserver {
  static void onPause() {}   // Nothing to do — no app-open ad
  static void onResume() {}  // Nothing to do — no app-open ad
}

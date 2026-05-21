import 'ad_service.dart';
import 'hive_service.dart';

/// Fires an interstitial ad every [threshold] content clicks.
/// Shared singleton so the count accumulates across Explore AND Paths tabs.
///
/// Usage:
/// ```dart
/// // In _openResource() or _openStep():
/// AdClickCounter.instance.onContentClick(onAdReady: () {
///   // navigate to content
/// }, onSkip: () {
///   // navigate to content (no ad this time)
/// });
/// ```
class AdClickCounter {
  AdClickCounter._();
  static final AdClickCounter instance = AdClickCounter._();

  int _clickCount = 0;

  /// How many clicks before an interstitial fires.
  /// 2 = every 2nd click shows an ad (aggressive, policy-compliant).
  static const int threshold = 2;

  /// Call this every time a user taps any content item (video, article, lesson).
  /// [onAdReady] — called AFTER the ad is dismissed, use it to navigate.
  /// [onSkip]    — called when no ad fires this click, navigate immediately.
  void onContentClick({
    required void Function() onAdReady,
    required void Function() onSkip,
  }) {
    _clickCount++;

    final progress = HiveService.getProgress();
    // Premium users: never block navigation with an ad
    if (progress.isPremium) {
      onSkip();
      return;
    }

    if (_clickCount >= threshold) {
      _clickCount = 0; // reset counter
      // Try to show interstitial; onDismissed fires onAdReady so
      // navigation happens after the ad closes.
      // If ad not ready (cooldown/not loaded), falls through to onSkip.
      AdService.showInterstitial(
        onDismissed: onAdReady,
      ).then((showed) {
        if (!showed) onSkip();
      });
    } else {
      onSkip();
    }
  }

  /// Reset counter — call when user goes premium.
  void reset() => _clickCount = 0;
}

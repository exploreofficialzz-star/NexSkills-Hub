/// PaywallGate — content is always free in NexSkills Hub.
///
/// Premium was replaced by "Remove Ads" (a time-limited consumable purchase).
/// This class is kept as a no-op shim so call sites compile without changes;
/// it simply calls [onAllowed] immediately every time.
class PaywallGate {
  static Future<void> checkAndProceed({
    required dynamic context,
    required String type,
    required void Function() onAllowed,
  }) async {
    onAllowed();
  }
}

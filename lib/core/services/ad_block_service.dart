import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'hive_service.dart';

/// Detects whether the user has an ad blocker active.
///
/// Strategy (two-pronged — more reliable than a single check):
///
///   1. HTTP PROBE — Try to reach known AdMob/DoubleClick endpoints.
///      If general internet works but ad domains are unreachable → blocked.
///
///   2. BANNER LOAD TEST — Load a real BannerAd. If it consistently fails
///      with error code 3 (no fill) it might just be no demand; if the
///      HTTP probe also fails then we're confident it's a blocker.
///
/// Result is cached for 10 minutes so we don't re-probe on every screen.

class AdBlockService {
  AdBlockService._();
  static final AdBlockService instance = AdBlockService._();

  bool? _cachedResult;
  DateTime? _lastCheck;
  static const _cacheDuration = Duration(minutes: 10);

  // Known ad-serving endpoints — if these fail when internet works → blocked
  static const _adProbes = [
    'https://googleads.g.doubleclick.net/pagead/id',
    'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js',
    'https://adservice.google.com/adsid/integrator.js',
  ];

  // A neutral endpoint to confirm general internet is up
  static const _neutralProbe = 'https://clients3.google.com/generate_204';

  /// Returns true if ads appear to be blocked.
  /// Returns false if ads load normally or if the check is inconclusive.
  Future<bool> isAdBlocked() async {
    // Premium users — never check (irrelevant)
    if (HiveService.getProgress().isPremium) return false;

    // Return cached result if fresh
    if (_cachedResult != null &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < _cacheDuration) {
      return _cachedResult!;
    }

    _cachedResult = await _runCheck();
    _lastCheck = DateTime.now();
    return _cachedResult!;
  }

  Future<bool> _runCheck() async {
    // Step 1: confirm internet is actually up
    final hasInternet = await _probe(_neutralProbe);
    if (!hasInternet) return false; // No internet — not an ad blocker issue

    // Step 2: probe all ad domains
    int blocked = 0;
    for (final url in _adProbes) {
      final reachable = await _probe(url);
      if (!reachable) blocked++;
    }

    // If majority of ad domains are unreachable but internet is up → blocked
    return blocked >= 2;
  }

  Future<bool> _probe(String url) async {
    try {
      final response = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 4));
      return response.statusCode < 500;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Force a fresh check (e.g. after user taps "I've disabled my ad blocker")
  Future<bool> recheckNow() async {
    _cachedResult = null;
    _lastCheck = null;
    return isAdBlocked();
  }

  /// Call this after a banner fails to load — may indicate blocking.
  /// We also run the HTTP probe to confirm.
  Future<bool> onBannerLoadFailed(LoadAdError error) async {
    // Error code 3 = no fill (normal, not a blocker).
    // Anything that suggests network-level interference warrants a probe.
    if (error.code == 3) return false;
    return isAdBlocked();
  }
}

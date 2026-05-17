import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/learning_path.dart';
import 'path_service.dart';

/// ContentHealthService — background URL availability checker.
///
/// Runs once per day (24-hour TTL), performs HTTP HEAD requests for every
/// content URL in learning_paths.json, caches results in the
/// 'content_health_log' Hive box, and exposes [isUnavailable(url)].
///
/// Unavailable criteria:
///   - HTTP 4xx / 5xx response
///   - Network timeout / connection error
///   - Redirect chain resolving to a login page pattern
class ContentHealthService {
  ContentHealthService._();
  static final ContentHealthService instance = ContentHealthService._();

  static const _boxName = 'content_health_log';
  static const _lastCheckKey = '__last_check__';
  static const _unavailablePrefix = 'u_';
  static const _logPrefix = 'log_';
  static const _reportedPrefix = 'rep_';
  static const _ttlHours = 24;

  // Login-page URL patterns — treat redirects to these as unavailable
  static const _loginPatterns = [
    'login', 'signin', 'sign-in', 'auth', 'account/login',
  ];

  static Future<void> initBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
  }

  static Box<String> get _box => Hive.box<String>(_boxName);

  // ─────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────

  /// Run the daily check in the background (non-blocking).
  /// Safe to call from initState or postFrameCallback.
  static void runDailyCheckInBackground() {
    Future.microtask(_runDailyCheck);
  }

  /// Returns true if the URL was flagged unavailable in the last check.
  static bool isUnavailable(String url) {
    if (!Hive.isBoxOpen(_boxName)) return false;
    return _box.containsKey('$_unavailablePrefix${url.hashCode}');
  }

  /// Report a broken link — records a user report entry in Hive.
  static Future<void> reportBrokenLink(String url, String title) async {
    if (!Hive.isBoxOpen(_boxName)) return;
    final entry =
        '${DateTime.now().toIso8601String()} | USER_REPORTED | $url | $title';
    await _box.put('$_reportedPrefix${url.hashCode}', entry);
  }

  // ─────────────────────────────────────────────────────────────
  // PRIVATE
  // ─────────────────────────────────────────────────────────────

  static Future<void> _runDailyCheck() async {
    if (!Hive.isBoxOpen(_boxName)) return;

    // Respect 24-hour TTL
    final lastStr = _box.get(_lastCheckKey);
    if (lastStr != null) {
      final last = DateTime.tryParse(lastStr);
      if (last != null &&
          DateTime.now().difference(last).inHours < _ttlHours) {
        return;
      }
    }

    List<LearningPath> paths;
    try {
      paths = await PathService.loadAll();
    } catch (_) {
      return; // Assets not ready — skip
    }

    // Collect all unique URLs
    final urls = <String, String>{}; // url -> step title
    for (final path in paths) {
      for (final step in path.steps) {
        if (step.url.isNotEmpty) {
          urls[step.url] = step.title;
        }
      }
    }

    // Check all URLs concurrently, max 10 at a time to avoid hammering
    final urlList = urls.entries.toList();
    for (var i = 0; i < urlList.length; i += 10) {
      final batch = urlList.sublist(
        i,
        (i + 10).clamp(0, urlList.length),
      );
      await Future.wait(
        batch.map((e) => _checkUrl(e.key, e.value)),
        eagerError: false,
      );
    }

    await _box.put(_lastCheckKey, DateTime.now().toIso8601String());
  }

  static Future<void> _checkUrl(String url, String title) async {
    final key = url.hashCode;
    try {
      final response = await http
          .head(
            Uri.parse(url),
            headers: {
              'User-Agent': 'NexSkillsHub/1.0',
              'Accept': '*/*',
            },
          )
          .timeout(const Duration(seconds: 10));

      // Check if the final URL looks like a login redirect
      final finalUrl = response.headers['location'] ?? '';
      final isLoginRedirect = _loginPatterns
          .any((p) => finalUrl.toLowerCase().contains(p));

      final isAvailable = !isLoginRedirect &&
          response.statusCode >= 200 &&
          response.statusCode < 400;

      // Write log entry
      final logEntry =
          '${DateTime.now().toIso8601String()} | ${response.statusCode} | ${isAvailable ? "OK" : "FAIL"} | $url';
      await _box.put('$_logPrefix$key', logEntry);

      if (isAvailable) {
        await _box.delete('$_unavailablePrefix$key');
      } else {
        await _box.put('$_unavailablePrefix$key',
            '${DateTime.now().toIso8601String()} | ${response.statusCode} | $url');
      }
    } on TimeoutException {
      await _box.put('$_unavailablePrefix$key',
          '${DateTime.now().toIso8601String()} | TIMEOUT | $url');
    } catch (e) {
      // Don't mark as unavailable on generic network errors —
      // the device might just be offline. Only mark on definitive failures.
      await _box.put('$_logPrefix${key}_err',
          '${DateTime.now().toIso8601String()} | ERROR | $e | $url');
    }
  }
}

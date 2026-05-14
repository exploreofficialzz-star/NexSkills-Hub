import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

enum ConnectivityStatus { online, interfaceOnly, offline }

/// Multi-probe connectivity service.
/// Distinguishes: offline / interface-only (no data) / fully online.
/// Separately tracks whether ad domains are reachable (ad block detection).
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();
  final _statusCtrl   = StreamController<ConnectivityStatus>.broadcast();
  final _adBlockCtrl  = StreamController<bool>.broadcast();

  ConnectivityStatus _status  = ConnectivityStatus.online;
  bool               _adBlocked = false;
  DateTime?          _lastAdBlockCheck;

  ConnectivityStatus get current   => _status;
  bool               get adBlocked => _adBlocked;

  Stream<ConnectivityStatus> get stream        => _statusCtrl.stream;
  Stream<bool>               get adBlockStream => _adBlockCtrl.stream;

  // ── Neutral probes — confirm general internet ──────────────────
  static const _neutralProbes = [
    'https://clients3.google.com/generate_204',  // returns 204, zero body
    'https://connectivitycheck.gstatic.com/generate_204',
    'https://www.apple.com/library/test/success.html',
  ];

  // ── Ad-serving probes — blocked by ad blockers ─────────────────
  static const _adProbes = [
    'https://googleads.g.doubleclick.net/pagead/id',
    'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js',
    'https://adservice.google.com/adsid/integrator.js',
    'https://securepubads.g.doubleclick.net/gampad/ads',
    'https://www.googletagservices.com/tag/js/gpt.js',
  ];

  Future<void> init() async {
    _status = await _checkConnectivity();
    _statusCtrl.add(_status);

    _adBlocked = await _checkAdBlock();
    _adBlockCtrl.add(_adBlocked);

    // React to interface changes
    _connectivity.onConnectivityChanged.listen((_) async {
      await _runFullCheck();
    });

    // 30s heartbeat — catches captive portals & SIM data exhaustion
    Timer.periodic(const Duration(seconds: 30), (_) async {
      await _runFullCheck();
    });

    // Ad-block check every 5 minutes (less frequent, more expensive)
    Timer.periodic(const Duration(minutes: 5), (_) async {
      final blocked = await _checkAdBlock();
      if (blocked != _adBlocked) {
        _adBlocked = blocked;
        _adBlockCtrl.add(_adBlocked);
      }
    });
  }

  Future<void> _runFullCheck() async {
    final next = await _checkConnectivity();
    if (next != _status) {
      _status = next;
      _statusCtrl.add(_status);
    }
  }

  /// Force an immediate check — call after user toggles airplane mode etc.
  Future<ConnectivityStatus> check() async {
    _status = await _checkConnectivity();
    _statusCtrl.add(_status);
    return _status;
  }

  /// Force an immediate ad-block check.
  Future<bool> checkAdBlock() async {
    _adBlocked = await _checkAdBlock();
    _adBlockCtrl.add(_adBlocked);
    return _adBlocked;
  }

  // ── Private ───────────────────────────────────────────────────
  Future<ConnectivityStatus> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    final hasInterface = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);

    if (!hasInterface) return ConnectivityStatus.offline;

    // Probe at least 2 neutral endpoints for reliability
    int reached = 0;
    for (final url in _neutralProbes) {
      if (await _probe(url, timeoutSeconds: 5)) {
        reached++;
        if (reached >= 2) break;
      }
    }
    return reached >= 1
        ? ConnectivityStatus.online
        : ConnectivityStatus.interfaceOnly;
  }

  Future<bool> _checkAdBlock() async {
    // Skip if we checked recently (< 5 min)
    if (_lastAdBlockCheck != null &&
        DateTime.now().difference(_lastAdBlockCheck!).inMinutes < 5) {
      return _adBlocked;
    }

    // Only check when we have real internet
    if (_status != ConnectivityStatus.online) return false;

    _lastAdBlockCheck = DateTime.now();

    int blocked = 0;
    for (final url in _adProbes) {
      final reachable = await _probe(url, timeoutSeconds: 4);
      if (!reachable) blocked++;
    }
    // Majority blocked → ad blocker active
    return blocked >= 3;
  }

  Future<bool> _probe(String url, {int timeoutSeconds = 5}) async {
    try {
      final response = await http
          .head(Uri.parse(url))
          .timeout(Duration(seconds: timeoutSeconds));
      return response.statusCode < 500;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _statusCtrl.close();
    _adBlockCtrl.close();
  }
}

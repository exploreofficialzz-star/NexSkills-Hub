import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Three states the app can be in:
///   online       — has interface AND confirmed live data
///   interfaceOnly— has WiFi/mobile interface but data isn't flowing
///                  (captive portal, SIM with no balance, etc.)
///   offline      — no network interface at all
enum ConnectivityStatus { online, interfaceOnly, offline }

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<ConnectivityStatus>.broadcast();

  ConnectivityStatus _current = ConnectivityStatus.online;
  ConnectivityStatus get current => _current;

  Stream<ConnectivityStatus> get stream => _controller.stream;

  // Lightweight endpoints used to confirm real data flow.
  // We try each in order and succeed on first 204/200 response.
  static const _probeUrls = [
    'https://clients3.google.com/generate_204', // returns HTTP 204, zero body
    'https://connectivitycheck.gstatic.com/generate_204',
    'https://www.apple.com/library/test/success.html', // iOS captive portal check
  ];

  Future<void> init() async {
    // Check once at startup
    _current = await _checkStatus();
    _controller.add(_current);

    // Re-check whenever the interface changes
    _connectivity.onConnectivityChanged.listen((_) async {
      final next = await _checkStatus();
      if (next != _current) {
        _current = next;
        _controller.add(_current);
      }
    });

    // Periodic heartbeat every 30s — catches captive portals that don't
    // trigger an interface change event
    Timer.periodic(const Duration(seconds: 30), (_) async {
      final next = await _checkStatus();
      if (next != _current) {
        _current = next;
        _controller.add(_current);
      }
    });
  }

  /// Returns the current status without waiting for a stream event.
  Future<ConnectivityStatus> check() async {
    _current = await _checkStatus();
    return _current;
  }

  Future<ConnectivityStatus> _checkStatus() async {
    // Step 1: check interface (fast, local)
    final results = await _connectivity.checkConnectivity();
    final hasInterface = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);

    if (!hasInterface) return ConnectivityStatus.offline;

    // Step 2: confirm actual data flows by probing a known endpoint
    final hasData = await _probeInternet();
    return hasData ? ConnectivityStatus.online : ConnectivityStatus.interfaceOnly;
  }

  Future<bool> _probeInternet() async {
    for (final url in _probeUrls) {
      try {
        final response = await http
            .head(Uri.parse(url))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode < 400) return true;
      } on SocketException {
        // No route to host
      } on TimeoutException {
        // Probe timed out (captive portal / no data)
      } catch (_) {
        // Any other failure — try next probe
      }
    }
    return false;
  }

  void dispose() => _controller.close();
}

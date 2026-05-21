import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/connectivity_service.dart';
import '../core/constants/app_constants.dart';

/// Wraps the entire app with connection awareness.
///
/// Behaviour:
///   online           → nothing shown, content renders normally
///   interfaceOnly    → amber banner at top: "Connected but no internet data"
///   offline          → full overlay screen with retry button
///
/// Usage in main.dart:
/// ```dart
/// home: NetworkAwareWrapper(child: isOnboarded ? HomeScreen() : OnboardingScreen())
/// ```
class NetworkAwareWrapper extends StatefulWidget {
  final Widget child;
  const NetworkAwareWrapper({super.key, required this.child});

  @override
  State<NetworkAwareWrapper> createState() => _NetworkAwareWrapperState();
}

class _NetworkAwareWrapperState extends State<NetworkAwareWrapper>
    with SingleTickerProviderStateMixin {
  late ConnectivityStatus _status;
  late StreamSubscription<ConnectivityStatus> _sub;
  late AnimationController _bannerController;
  late Animation<Offset> _bannerSlide;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _status = ConnectivityService.instance.current;

    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bannerSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bannerController,
      curve: Curves.easeOutCubic,
    ));

    _sub = ConnectivityService.instance.stream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
        if (status == ConnectivityStatus.interfaceOnly) {
          _bannerController.forward();
        } else {
          _bannerController.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() => _checking = true);
    await ConnectivityService.instance.check();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Stack(
      children: [
        // ── Main app content ──────────────────────────────────
        widget.child,

        // ── Interface-only amber banner (slides in from top) ──
        if (_status == ConnectivityStatus.interfaceOnly)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _bannerSlide,
              child: Material(
                color: Colors.transparent,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: NexColors.warning,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Connected — no internet data',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text(
                                'Check your data plan or WiFi connection.',
                                style: TextStyle(
                                    color: Colors.black87, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _retry,
                          child: _checking
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black),
                                )
                              : const Text('Retry',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ── Full offline screen ───────────────────────────────
        if (_status == ConnectivityStatus.offline)
          Positioned.fill(
            child: Material(
              color: c.background,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated wifi-off icon
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.8, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (_, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: NexColors.error.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('📡',
                                style: TextStyle(fontSize: 46)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text('No internet connection',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          )),
                      const SizedBox(height: 12),
                      Text(
                        "NexSkills needs internet to fetch your\ndaily lessons and fresh content.\n\nYour progress is saved offline.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Tips
                      _OfflineTip(
                          icon: '📶',
                          text: 'Turn WiFi off and back on',
                          c: c),
                      const SizedBox(height: 12),
                      _OfflineTip(
                          icon: '💳',
                          text: 'Check your mobile data balance',
                          c: c),
                      const SizedBox(height: 12),
                      _OfflineTip(
                          icon: '✈️',
                          text: 'Make sure Airplane Mode is off',
                          c: c),

                      const SizedBox(height: 40),

                      // Retry button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _checking ? null : _retry,
                          icon: _checking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Icon(Icons.refresh, color: Colors.white),
                          label: Text(
                            _checking
                                ? 'Checking connection...'
                                : 'Try Again',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OfflineTip extends StatelessWidget {
  final String icon, text;
  final NexColors c;
  const _OfflineTip(
      {required this.icon, required this.text, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text,
              style:
                  TextStyle(color: c.textSecondary, fontSize: 14)),
        ),
      ],
    );
  }
}

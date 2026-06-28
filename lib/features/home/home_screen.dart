import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/ad_manager.dart';
import '../../core/services/content_health_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/hive_service.dart';
import '../today/today_screen.dart';
import '../paths/paths_screen.dart';
import '../explore/explore_screen.dart';
import '../progress/progress_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(ThemeMode)? onThemeModeChanged;
  const HomeScreen({super.key, this.onThemeModeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  late AnimationController _navController;
  // Signals ExploreScreen to refresh when the tab is selected or app resumes.
  final _exploreRefresh = ValueNotifier<int>(0);

  static const _items = [
    _NavItem(icon: Icons.today_outlined,      activeIcon: Icons.today,      label: 'Today'),
    _NavItem(icon: Icons.route_outlined,      activeIcon: Icons.route,      label: 'My Path'),
    _NavItem(icon: Icons.explore_outlined,    activeIcon: Icons.explore,    label: 'Explore'),
    _NavItem(icon: Icons.bar_chart_outlined,  activeIcon: Icons.bar_chart,  label: 'Progress'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Post-frame: safe to load ads and run background tasks.
    // Ads are NEVER loaded before the first frame (AdMob policy).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AdManager.instance.init();
      AdService.preloadAllPostFrame();
      ContentHealthService.runDailyCheckInBackground();
      // Request notification permissions and schedule daily reminder
      _setupNotifications();
    });
  }

  Future<void> _setupNotifications() async {
    try {
      // Request permission (Android 13+ / iOS require explicit grant)
      final granted = await NotificationService.requestPermissions();
      if (!granted) return;
      // Schedule daily reminder at 8:00 AM
      final progress = HiveService.getProgress();
      await NotificationService.scheduleDailyReminder(
        hour: 8,
        minute: 0,
        streakDays: progress.streakDays,
      );
      // Schedule streak warning at 8 PM if user has an active streak
      if (progress.streakDays > 0) {
        await NotificationService.scheduleStreakWarning(progress.streakDays);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _exploreRefresh.dispose();
    _navController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Nudge explore to refresh stale content when user returns to the app.
      _exploreRefresh.value++;
    }
  }

  void _onTap(int i) {
    if (i == _currentIndex) return;
    setState(() => _currentIndex = i);
    _navController.forward(from: 0);
    // Tell explore to check for stale content every time the tab is opened.
    if (i == 2) _exploreRefresh.value++;
  }

  Widget _buildScreen(int i) => switch (i) {
        0 => const TodayScreen(),
        1 => const PathsScreen(),
        2 => ExploreScreen(refreshTrigger: _exploreRefresh),
        3 => ProgressScreen(onThemeModeChanged: widget.onThemeModeChanged),
        _ => const TodayScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      extendBody: true,
      body: RepaintBoundary(
        child: IndexedStack(
          index: _currentIndex,
          children: List.generate(4, _buildScreen),
        ),
      ),
      bottomNavigationBar: _FloatingNav(
        currentIndex: _currentIndex,
        items: _items,
        onTap: _onTap,
        controller: _navController,
      ),
    );
  }
}

class _FloatingNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final void Function(int) onTap;
  final AnimationController controller;

  const _FloatingNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: c.navBackground,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: c.navBorder, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.55)
                  : Colors.black.withOpacity(0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: NexColors.primary.withOpacity(isDark ? 0.12 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? NexColors.primary.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1, end: selected ? 1.2 : 1),
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.elasticOut,
                          builder: (_, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Icon(
                            selected ? items[i].activeIcon : items[i].icon,
                            color: selected ? NexColors.primary : c.textMuted,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            color: selected ? NexColors.primary : c.textMuted,
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          child: Text(items[i].label),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(top: 3),
                          width: selected ? 5 : 0,
                          height: selected ? 5 : 0,
                          decoration: const BoxDecoration(
                            color: NexColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

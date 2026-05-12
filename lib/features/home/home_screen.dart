import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/ad_service.dart';
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
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navController;

  final _items = const [
    _NavItem(icon: Icons.today_outlined,     activeIcon: Icons.today,     label: 'Today'),
    _NavItem(icon: Icons.route_outlined,     activeIcon: Icons.route,     label: 'My Path'),
    _NavItem(icon: Icons.explore_outlined,   activeIcon: Icons.explore,   label: 'Explore'),
    _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Progress'),
  ];

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _navController.dispose();
    super.dispose();
  }

  void _onTap(int i) {
    if (i == _currentIndex) return;

    // ── Aggressive interstitial on tab switch ──────────────────
    // Policy compliant: user action (tap) triggered, 90s cooldown enforced
    // inside showInterstitialForTabSwitch(). Fires and forgets — tab switch
    // happens immediately regardless of whether ad shows.
    final progress = HiveService.getProgress();
    if (!progress.isPremium && progress.canShowInterstitial) {
      AdService.showInterstitialForTabSwitch();
    }

    setState(() => _currentIndex = i);
    _navController.forward(from: 0);
  }

  Widget _buildScreen(int i) => switch (i) {
        0 => const TodayScreen(),
        1 => const PathsScreen(),
        2 => const ExploreScreen(),
        3 => ProgressScreen(onThemeModeChanged: widget.onThemeModeChanged),
        _ => const TodayScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(4, _buildScreen),
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

// ─── Floating pill nav ────────────────────────────────────────────────────────
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: c.navBackground,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: c.navBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.5)
                  : Colors.black.withOpacity(0.10),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: NexColors.primary.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1, end: selected ? 1.18 : 1),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.elasticOut,
                        builder: (_, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Icon(
                          selected ? items[i].activeIcon : items[i].icon,
                          color: selected ? NexColors.primary : c.textMuted,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          color: selected ? NexColors.primary : c.textMuted,
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        child: Text(items[i].label),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(top: 3),
                        width: selected ? 4 : 0,
                        height: selected ? 4 : 0,
                        decoration: const BoxDecoration(
                          color: NexColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
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
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

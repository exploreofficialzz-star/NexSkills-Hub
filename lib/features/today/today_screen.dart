import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/learning_path.dart';
import '../../core/models/user_progress.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/path_service.dart';
import '../../core/services/ad_manager.dart';
import '../../core/services/connectivity_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/mediated_banner_widget.dart';
import '../paths/content_viewer_screen.dart';
import '../premium/premium_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen>
    with AutomaticKeepAliveClientMixin {
  UserProgress? _progress;
  LearningPath? _path;
  PathStep? _todayStep;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final progress = HiveService.getProgress();
    final path = await PathService.getActivePath(
        progress.activeCategory, progress.activeLevel);

    PathStep? todayStep;
    if (path != null) {
      final completed = progress.completedSteps[path.id] ?? [];
      try {
        todayStep =
            path.steps.firstWhere((s) => !completed.contains(s.order));
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _progress = progress;
        _path = path;
        _todayStep = todayStep;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Start Today's Lesson — shows interstitial BEFORE navigating.
  /// Uses a 3-second timeout so navigation is never blocked if the ad
  /// isn't ready (Section 2.1 / 5.1 graceful degradation).
  void _startLesson() {
    if (_todayStep == null || _path == null) return;

    void navigate() {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContentViewerScreen(
            step: _todayStep!,
            pathId: _path!.id,
            pathCategory: _path!.category,
            onComplete: _load,
          ),
        ),
      );
    }

    // TODAY TAB RULE: attempt interstitial on EVERY "Start Today's Lesson" tap.
    // 60-second cooldown is the only governor — AdMob policy compliance.
    AdManager.instance.showInterstitialForTodayLesson(onDismissed: navigate);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.colors;

    if (_loading) {
      return Scaffold(
        backgroundColor: c.background,
        body: Center(
            child: CircularProgressIndicator(color: NexColors.primary)),
      );
    }

    final progress = _progress!;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: NexColors.primary,
          backgroundColor: c.card,
          child: CustomScrollView(
            // BouncingScrollPhysics for smooth feel (Section 2.2c)
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(progress, c),
                    const SizedBox(height: 24),

                    // RepaintBoundary around streak card — animates independently
                    RepaintBoundary(child: _buildStreakCard(progress)),
                    const SizedBox(height: 16),

                    // Banner ad between streak and lesson — AdMob primary, Unity fallback
                    const MediatedBannerWidget(label: 'Advertisement'),
                    const SizedBox(height: 16),

                    _buildTodayLesson(c),
                    const SizedBox(height: 20),

                    // Isolated WeeklyGoal widget — its animation never
                    // rebuilds the rest of the Today tab (Section 2.2d)
                    RepaintBoundary(
                      child: _WeeklyGoalCard(progress: progress, c: c),
                    ),
                    const SizedBox(height: 20),
                    _buildQuickStats(progress, c),
                    const SizedBox(height: 20),
                    if (!progress.isPremium) _buildPremiumNudge(c),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserProgress p, NexColors c) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting,
            style: TextStyle(
                color: c.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('Ready to level up? 🚀',
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8)),
      ],
    );
  }

  Widget _buildStreakCard(UserProgress p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5A52E0), NexColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 42)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.streakDays} Day Streak',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                Text(
                  p.streakDays == 0
                      ? 'Start your streak today!'
                      : 'Keep it alive — learn something today',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85), fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${p.totalXP}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              Text('XP',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayLesson(NexColors c) {
    if (_todayStep == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: NexColors.accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NexColors.accent.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('Path Complete!',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'You completed this path. Head to My Path to unlock the next level.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final step = _todayStep!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's Lesson",
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: NexColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      step.isYoutube ? '📹 Video' : '📝 Article',
                      style: const TextStyle(
                          color: NexColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(step.duration,
                      style: TextStyle(color: c.textMuted, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              Text(step.title,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.3)),
              const SizedBox(height: 6),
              Text(step.sourceName,
                  style: TextStyle(color: c.textMuted, fontSize: 13)),
              if (step.note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(step.note,
                            style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startLesson,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Start Today's Lesson",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(UserProgress p, NexColors c) {
    return Row(
      children: [
        Expanded(
            child: StatPill(
                label: 'Total XP',
                value: '⭐ ${p.totalXP}',
                color: NexColors.gold)),
        const SizedBox(width: 12),
        Expanded(
            child: StatPill(
                label: 'Lessons',
                value: '📚 ${p.totalLessonsCompleted}',
                color: NexColors.primary)),
        const SizedBox(width: 12),
        Expanded(
            child: StatPill(
                label: 'Badges',
                value: '🏅 ${p.earnedBadges.length}',
                color: NexColors.accentOrange)),
      ],
    );
  }

  Widget _buildPremiumNudge(NexColors c) {
    return GestureDetector(
      onTap: () => RemoveAdsModal.show(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              NexColors.primary.withOpacity(0.15),
              NexColors.accent.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: NexColors.primary.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            const Text('👑', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Go Ad-Free from \$3.99/week',
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text('Remove all ads · All tracks unlocked',
                      style: TextStyle(color: c.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: NexColors.primary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WeeklyGoalCard — isolated StatefulWidget so its TweenAnimationBuilder
// never triggers a rebuild of the rest of TodayScreen. (Section 2.2d)
// ─────────────────────────────────────────────────────────────────────────────
class _WeeklyGoalCard extends StatefulWidget {
  final UserProgress progress;
  final NexColors c;

  const _WeeklyGoalCard({required this.progress, required this.c});

  @override
  State<_WeeklyGoalCard> createState() => _WeeklyGoalCardState();
}

class _WeeklyGoalCardState extends State<_WeeklyGoalCard> {
  late double _targetProgress;

  @override
  void initState() {
    super.initState();
    final p = widget.progress;
    final goal = (p.dailyGoalMinutes / 10).round() * 5;
    final done = p.totalLessonsCompleted % 7;
    _targetProgress = goal > 0 ? (done / goal).clamp(0.0, 1.0) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final c = widget.c;
    final goal = (p.dailyGoalMinutes / 10).round() * 5;
    final done = p.totalLessonsCompleted % 7;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text('Weekly Goal',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          // TweenAnimationBuilder only rebuilds this widget, not TodayScreen
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _targetProgress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: c.progressTrack,
                color: NexColors.accent,
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('$done of $goal lessons this week',
              style: TextStyle(color: c.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Inline banner widget ─────────────────────────────────────────────────────


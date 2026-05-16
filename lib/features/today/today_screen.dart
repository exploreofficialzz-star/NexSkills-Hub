import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/learning_path.dart';
import '../../core/models/user_progress.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/path_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/ad_click_counter.dart';
import '../../core/services/connectivity_service.dart';
import '../../shared/widgets/shared_widgets.dart';
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
  PathStep?     _todayStep;
  bool          _loading = true;

  // Inline banner ad between streak card and lesson
  BannerAd? _bannerAd;
  bool      _bannerLoaded = false;

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
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    if (HiveService.getProgress().isPremium) return;
    if (ConnectivityService.instance.adBlocked) return;
    final ad = AdService.createBanner();
    await ad.load();
    if (mounted) setState(() { _bannerAd = ad; _bannerLoaded = true; });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

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
      ).then((_) {
        AdClickCounter.instance.onContentClick(
          onAdReady: () {},
          onSkip:    () {},
        );
      });
    }

    AdClickCounter.instance.onContentClick(
      onAdReady: navigate,
      onSkip:    navigate,
    );
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
            slivers: [
              SliverPadding(
                // Extra bottom padding so content clears the floating nav
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(progress, c),
                    const SizedBox(height: 24),
                    _buildStreakCard(progress),
                    const SizedBox(height: 16),

                    // ── Banner ad between streak and lesson ────────
                    if (_bannerLoaded && _bannerAd != null) ...[
                      _InlineBanner(ad: _bannerAd!, c: c),
                      const SizedBox(height: 16),
                    ],

                    _buildTodayLesson(c),
                    const SizedBox(height: 20),
                    _buildWeeklyGoal(progress, c),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
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

  Widget _buildWeeklyGoal(UserProgress p, NexColors c) {
    final goal = (p.dailyGoalMinutes / 10).round() * 5;
    final done = p.totalLessonsCompleted % 7;
    final progress = goal > 0 ? (done / goal).clamp(0.0, 1.0) : 0.0;

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
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: c.progressTrack,
              color: NexColors.accent,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text('$done of $goal lessons this week',
              style: TextStyle(color: c.textMuted, fontSize: 13)),
        ],
      ),
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
      onTap: () {
        AdService.showInterstitial(onDismissed: () {
          if (mounted) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()));
          }
        });
      },
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

class _InlineBanner extends StatelessWidget {
  final BannerAd ad;
  final NexColors c;
  const _InlineBanner({required this.ad, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Advertisement',
            style: TextStyle(
                color: c.textMuted, fontSize: 9, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border, width: 0.5),
          ),
          alignment: Alignment.center,
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ],
    );
  }
}

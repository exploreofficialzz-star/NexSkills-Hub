import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/learning_path.dart';
import '../../core/models/user_progress.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/path_service.dart';
import '../../core/services/ad_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../paths/content_viewer_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  UserProgress? _progress;
  LearningPath? _path;
  PathStep? _todayStep;
  bool _loading = true;

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
        todayStep = path.steps
            .firstWhere((s) => !completed.contains(s.order));
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

  void _startLesson() {
    if (_todayStep == null || _path == null) return;
    AdService.showInterstitial(onDismissed: () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContentViewerScreen(
              step: _todayStep!,
              pathId: _path!.id,
              onComplete: () {
                _load();
              },
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final progress = _progress!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(progress),
              const SizedBox(height: 24),
              _buildStreakCard(progress),
              const SizedBox(height: 20),
              _buildTodayLesson(),
              const SizedBox(height: 20),
              _buildWeeklyGoal(progress),
              const SizedBox(height: 20),
              const BannerAdWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserProgress p) {
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
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        const Text('Ready to level up? 🚀',
            style: TextStyle(
                color: AppColors.textPrimary,
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
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.8),
            AppColors.primary,
          ],
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
                Text(
                  '${p.streakDays} Day Streak',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  p.streakDays == 0
                      ? 'Start your streak today!'
                      : 'Keep it alive — learn something today',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text('${p.totalXP}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              Text('XP',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayLesson() {
    if (_todayStep == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        child: const Column(
          children: [
            Text('🎉', style: TextStyle(fontSize: 40)),
            SizedBox(height: 12),
            Text('Path Complete!',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text(
              'You completed this learning path. Head to My Path to unlock the next level.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final step = _todayStep!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Today's Lesson",
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
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
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      step.isYoutube ? '📹 Video' : '📝 Article',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(step.duration,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              Text(step.title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.3)),
              const SizedBox(height: 6),
              Text(step.sourceName,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
              if (step.note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Text('💡',
                          style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(step.note,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
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

  Widget _buildWeeklyGoal(UserProgress p) {
    final completed = p.totalLessonsCompleted;
    final goal = (p.dailyGoalMinutes / 10).round() * 5;
    final progress = (completed % 7) / 7;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🎯', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('Weekly Goal',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.surface,
              color: AppColors.accent,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text('${(completed % 7)} of $goal lessons this week',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

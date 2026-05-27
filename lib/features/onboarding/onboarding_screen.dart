import 'package:flutter/material.dart';
import '../../shared/widgets/app_icon_widget.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/user_progress.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/notification_service.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  String _selectedCategory = 'ai';
  String _selectedLevel = 'beginner';
  int _dailyGoalMinutes = 20;
  bool _finishing = false;

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);

    final progress = UserProgress(
      activeCategory: _selectedCategory,
      activeLevel: _selectedLevel,
      dailyGoalMinutes: _dailyGoalMinutes,
    );
    await HiveService.saveProgress(progress);

    // Notifications are best-effort — never block navigation
    try {
      await NotificationService.requestPermissions();
      await NotificationService.scheduleDailyReminder(hour: 9, minute: 0);
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.colors picks up dark/light/system automatically
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(c),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildCategoryPage(c),
                  _buildLevelPage(c),
                  _buildGoalPage(c),
                ],
              ),
            ),
            _buildBottom(c),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(NexColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon left-aligned, large, with app name beside it
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppIconWidget(size: 72),
              const SizedBox(width: 14),
              Text(
                'NexSkills Hub',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i <= _currentPage
                        ? NexColors.primary
                        : c.progressTrack,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPage(NexColors c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text('What do you want\nto master?',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -1)),
          const SizedBox(height: 8),
          Text('Pick your primary learning track',
              style: TextStyle(color: c.textSecondary, fontSize: 16)),
          const SizedBox(height: 32),
          ...AppCategories.all.map((cat) => _CategoryTile(
                meta: cat,
                selected: _selectedCategory == cat.id,
                onTap: () => setState(() => _selectedCategory = cat.id),
              )),
        ],
      ),
    );
  }

  Widget _buildLevelPage(NexColors c) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text("What's your\ncurrent level?",
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -1)),
          const SizedBox(height: 8),
          Text('We will tailor your learning path',
              style: TextStyle(color: c.textSecondary, fontSize: 16)),
          const SizedBox(height: 32),
          _LevelTile(
            emoji: '🟢', title: 'Beginner',
            subtitle: "I'm starting fresh — new to this topic",
            selected: _selectedLevel == 'beginner',
            onTap: () => setState(() => _selectedLevel = 'beginner'),
          ),
          const SizedBox(height: 12),
          _LevelTile(
            emoji: '🟡', title: 'Intermediate',
            subtitle: 'I know the basics and want to go deeper',
            selected: _selectedLevel == 'intermediate',
            onTap: () => setState(() => _selectedLevel = 'intermediate'),
          ),
          const SizedBox(height: 12),
          _LevelTile(
            emoji: '🔴', title: 'Advanced',
            subtitle: 'I want expert-level content only',
            selected: _selectedLevel == 'advanced',
            onTap: () => setState(() => _selectedLevel = 'advanced'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPage(NexColors c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text('Set your\ndaily goal',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -1)),
          const SizedBox(height: 8),
          Text('Consistency beats intensity every time',
              style: TextStyle(color: c.textSecondary, fontSize: 16)),
          const SizedBox(height: 40),
          ...[
            (10, '⏱️', 'Casual',    'Quick daily habit, 1 lesson'),
            (20, '🎯', 'Serious',   '2 lessons per day'),
            (30, '🔥', 'Committed', '3 lessons — accelerate fast'),
          ].map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GoalTile(
                  minutes: g.$1, emoji: g.$2,
                  title: g.$3, subtitle: g.$4,
                  selected: _dailyGoalMinutes == g.$1,
                  onTap: () => setState(() => _dailyGoalMinutes = g.$1),
                ),
              )),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NexColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NexColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Text('🔔', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "We'll send a daily reminder at 9 AM to keep your streak alive.",
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottom(NexColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _finishing ? null : _nextPage,
          child: _finishing
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(
                  _currentPage < 2 ? 'Continue' : "Let's Go 🚀",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

// ─── Category tile ──────────────────────────────────────────────────────────
class _CategoryTile extends StatelessWidget {
  final CategoryMeta meta;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryTile({required this.meta, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? meta.color.withOpacity(0.12) : c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? meta.color : c.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Text(meta.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.title,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  Text(meta.description,
                      style: TextStyle(color: c.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: meta.color, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Level tile ─────────────────────────────────────────────────────────────
class _LevelTile extends StatelessWidget {
  final String emoji, title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _LevelTile({required this.emoji, required this.title,
      required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? NexColors.primary.withOpacity(0.12) : c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? NexColors.primary : c.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: TextStyle(color: c.textMuted, fontSize: 13)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: NexColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Goal tile ──────────────────────────────────────────────────────────────
class _GoalTile extends StatelessWidget {
  final int minutes;
  final String emoji, title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _GoalTile({required this.minutes, required this.emoji,
      required this.title, required this.subtitle,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? NexColors.accent.withOpacity(0.10) : c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? NexColors.accent : c.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$title · $minutes min/day',
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: TextStyle(color: c.textMuted, fontSize: 13)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: NexColors.accent, size: 22),
          ],
        ),
      ),
    );
  }
}

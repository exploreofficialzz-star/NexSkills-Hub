import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/learning_path.dart';
import '../../core/models/user_progress.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/path_service.dart';
import '../../core/services/ad_manager.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'path_detail_screen.dart';

/// Section key for path-card tap counter — persisted in Hive.
class PathsScreen extends StatefulWidget {
  const PathsScreen({super.key});

  @override
  State<PathsScreen> createState() => _PathsScreenState();
}

class _PathsScreenState extends State<PathsScreen>
    with AutomaticKeepAliveClientMixin {
  String _selectedCategory = 'ai';
  List<LearningPath> _paths = [];
  UserProgress? _progress;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _progress = HiveService.getProgress();
    _selectedCategory = _progress!.activeCategory;
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    if (mounted) setState(() => _loading = true);
    final paths = await PathService.byCategory(_selectedCategory);
    if (mounted) {
      setState(() {
        _paths = paths;
        _loading = false;
      });
    }
  }

  void _selectCategory(String id) {
    setState(() => _selectedCategory = id);
    _loadPaths();
  }

  /// Tap a path card — every-other-tap interstitial rule (Section 3.1).
  /// Tap 1 → ad; Tap 2 → skip; Tap 3 → ad; etc.
  /// Counter is persisted in Hive across restarts via AdManager.
  void _openPath(LearningPath path) {
    AdManager.instance.showInterstitial(
      onDismissed: () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PathDetailScreen(
              path: path,
              onStepComplete: () =>
                  setState(() => _progress = HiveService.getProgress()),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(c),
            const SizedBox(height: 4),
            _buildCategoryBar(c),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? ShimmerList(count: 3)
                  : _paths.isEmpty
                      ? _buildEmpty(c)
                      : _buildPathList(c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(NexColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Learning Path',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          Text('Structured. Sequential. Effective.',
              style: TextStyle(color: c.textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(NexColors c) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: AppCategories.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = AppCategories.all[i];
          final selected = _selectedCategory == cat.id;
          return GestureDetector(
            onTap: () => _selectCategory(cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? cat.color : c.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? cat.color : c.border,
                  width: 0.5,
                ),
              ),
              child: Text(
                '${cat.icon} ${cat.title.split(' ').first}',
                style: TextStyle(
                  color: selected ? Colors.white : c.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(NexColors c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📚', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('No paths yet',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Learning paths for this track are coming soon.',
              style: TextStyle(color: c.textMuted, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPathList(NexColors c) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      itemCount: _paths.length,
      itemBuilder: (_, i) {
        final path = _paths[i];
        final completed = _progress!.completedCount(path.id);
        return _PathCard(
          path: path,
          completedSteps: completed,
          isLocked: false,
          onTap: () => _openPath(path),
        );
      },
    );
  }
}

// ─── Path Card ────────────────────────────────────────────────────────────────
class _PathCard extends StatelessWidget {
  final LearningPath path;
  final int completedSteps;
  final bool isLocked;
  final VoidCallback onTap;

  const _PathCard({
    required this.path,
    required this.completedSteps,
    required this.isLocked,
    required this.onTap,
  });

  Color get _levelColor => switch (path.level) {
        'beginner' => NexColors.success,
        'intermediate' => NexColors.warning,
        _ => NexColors.error,
      };

  String get _levelEmoji => switch (path.level) {
        'beginner' => '🟢',
        'intermediate' => '🟡',
        _ => '🔴',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final progressVal =
        path.totalSteps > 0 ? completedSteps / path.totalSteps : 0.0;
    final isComplete =
        completedSteps >= path.totalSteps && path.totalSteps > 0;

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isLocked ? c.surface : c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isComplete ? NexColors.accent : c.border,
            width: isComplete ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_levelEmoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _levelColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    path.level.toUpperCase(),
                    style: TextStyle(
                        color: _levelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5),
                  ),
                ),
                const Spacer(),
                if (isLocked)
                  Icon(Icons.lock, color: c.textMuted, size: 18)
                else if (isComplete)
                  const Icon(Icons.check_circle,
                      color: NexColors.accent, size: 22),
              ],
            ),
            const SizedBox(height: 12),
            Text(path.title,
                style: TextStyle(
                    color: isLocked ? c.textMuted : c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(path.description,
                style:
                    TextStyle(color: c.textMuted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            if (!isLocked) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressVal.clamp(0.0, 1.0),
                  backgroundColor: c.progressTrack,
                  color: isComplete ? NexColors.accent : NexColors.primary,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isComplete
                    ? '✅ Completed!'
                    : '$completedSteps / ${path.totalSteps} lessons',
                style: TextStyle(
                    color: isComplete ? NexColors.accent : c.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

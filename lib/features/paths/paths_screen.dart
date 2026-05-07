import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/learning_path.dart';
import '../../core/models/user_progress.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/path_service.dart';
import '../../core/services/ad_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'path_detail_screen.dart';

class PathsScreen extends StatefulWidget {
  const PathsScreen({super.key});

  @override
  State<PathsScreen> createState() => _PathsScreenState();
}

class _PathsScreenState extends State<PathsScreen> {
  String _selectedCategory = 'ai';
  List<LearningPath> _paths = [];
  UserProgress? _progress;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _progress = HiveService.getProgress();
    _selectedCategory = _progress!.activeCategory;
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    setState(() => _loading = true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCategoryBar(),
            Expanded(
              child: _loading
                  ? const ShimmerList(count: 3)
                  : _buildPathList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Learning Path',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                Text('Structured. Sequential. Effective.',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar() {
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? cat.color : AppColors.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${cat.icon} ${cat.title.split(' ').first}',
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : AppColors.textMuted,
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

  Widget _buildPathList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _paths.length,
      itemBuilder: (_, i) {
        final path = _paths[i];
        final progress = _progress!;
        final completed = progress.completedCount(path.id);
        final isLocked = path.prerequisitePathId != null &&
            progress.completedCount(path.prerequisitePathId!) <
                (PathService.getById(path.prerequisitePathId!).then(
                    (p) => p?.totalSteps ?? 0) as dynamic);
        return _PathCard(
          path: path,
          completedSteps: completed,
          isLocked: false, // simplified, full lock logic in detail
          onTap: () {
            AdService.showInterstitial(onDismissed: () {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PathDetailScreen(
                      path: path,
                      onStepComplete: () => setState(
                          () => _progress = HiveService.getProgress()),
                    ),
                  ),
                );
              }
            });
          },
        );
      },
    );
  }
}

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

  Color get _levelColor {
    switch (path.level) {
      case 'beginner':
        return AppColors.success;
      case 'intermediate':
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }

  String get _levelEmoji {
    switch (path.level) {
      case 'beginner':
        return '🟢';
      case 'intermediate':
        return '🟡';
      default:
        return '🔴';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = path.totalSteps > 0
        ? completedSteps / path.totalSteps
        : 0.0;
    final isComplete = completedSteps >= path.totalSteps;

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isLocked ? AppColors.locked : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: isComplete
              ? Border.all(color: AppColors.accent, width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$_levelEmoji',
                    style: const TextStyle(fontSize: 20)),
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
                  const Icon(Icons.lock,
                      color: AppColors.textMuted, size: 18)
                else if (isComplete)
                  const Icon(Icons.check_circle,
                      color: AppColors.accent, size: 22),
              ],
            ),
            const SizedBox(height: 12),
            Text(path.title,
                style: TextStyle(
                    color: isLocked
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(path.description,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.4)),
            const SizedBox(height: 16),
            if (!isLocked) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.surface,
                  color: isComplete ? AppColors.accent : AppColors.primary,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isComplete
                    ? '✅ Completed!'
                    : '$completedSteps / ${path.totalSteps} lessons',
                style: TextStyle(
                    color: isComplete
                        ? AppColors.accent
                        : AppColors.textMuted,
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

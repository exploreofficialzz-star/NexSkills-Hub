import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/learning_path.dart';
import '../../core/models/user_progress.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/ad_service.dart';
import 'content_viewer_screen.dart';

class PathDetailScreen extends StatefulWidget {
  final LearningPath path;
  final VoidCallback? onStepComplete;

  const PathDetailScreen(
      {super.key, required this.path, this.onStepComplete});

  @override
  State<PathDetailScreen> createState() => _PathDetailScreenState();
}

class _PathDetailScreenState extends State<PathDetailScreen> {
  late UserProgress _progress;

  @override
  void initState() {
    super.initState();
    _progress = HiveService.getProgress();
  }

  void _openStep(PathStep step) {
    AdService.showInterstitial(onDismissed: () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContentViewerScreen(
              step: step,
              pathId: widget.path.id,
              onComplete: () {
                setState(
                    () => _progress = HiveService.getProgress());
                widget.onStepComplete?.call();
              },
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final completed =
        _progress.completedSteps[widget.path.id] ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final step = widget.path.steps[i];
                  final isDone = completed.contains(step.order);
                  final isLocked = !isDone &&
                      step.order > 1 &&
                      !completed.contains(step.order - 1);

                  return _StepTile(
                    step: step,
                    isDone: isDone,
                    isLocked: isLocked,
                    isActive: !isDone && !isLocked,
                    onTap: isLocked ? null : () => _openStep(step),
                  );
                },
                childCount: widget.path.steps.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final completed =
        (_progress.completedSteps[widget.path.id] ?? []).length;
    final total = widget.path.totalSteps;
    final levelColor = widget.path.level == 'beginner'
        ? AppColors.success
        : widget.path.level == 'intermediate'
            ? AppColors.warning
            : AppColors.error;

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withOpacity(0.8), AppColors.background],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.path.level.toUpperCase(),
                      style: TextStyle(
                          color: levelColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.path.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('$completed / $total lessons complete',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final PathStep step;
  final bool isDone;
  final bool isLocked;
  final bool isActive;
  final VoidCallback? onTap;

  const _StepTile({
    required this.step,
    required this.isDone,
    required this.isLocked,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLocked
              ? AppColors.locked
              : isDone
                  ? AppColors.success.withOpacity(0.08)
                  : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(
                  color: AppColors.primary.withOpacity(0.5), width: 1.5)
              : isDone
                  ? Border.all(
                      color: AppColors.success.withOpacity(0.3))
                  : null,
        ),
        child: Row(
          children: [
            _buildStepIcon(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step ${step.order}',
                    style: TextStyle(
                        color: isLocked
                            ? AppColors.textMuted
                            : AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    step.title,
                    style: TextStyle(
                        color: isLocked
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        step.isYoutube ? '📹' : '📝',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${step.sourceName} · ${step.duration}',
                        style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12),
                      ),
                    ],
                  ),
                  if (step.note.isNotEmpty && isActive) ...[
                    const SizedBox(height: 8),
                    Text(
                      '💡 ${step.note}',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isLocked)
              const Icon(Icons.lock_outline,
                  color: AppColors.textMuted, size: 18)
            else if (isDone)
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 24)
            else
              const Icon(Icons.play_circle_outline,
                  color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone
            ? AppColors.success.withOpacity(0.2)
            : isLocked
                ? AppColors.surface
                : AppColors.primary.withOpacity(0.15),
      ),
      child: Center(
        child: Text(
          isDone ? '✓' : '${step.order}',
          style: TextStyle(
            color: isDone
                ? AppColors.success
                : isLocked
                    ? AppColors.textMuted
                    : AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

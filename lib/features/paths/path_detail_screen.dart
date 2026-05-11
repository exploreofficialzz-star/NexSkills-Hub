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

  const PathDetailScreen({super.key, required this.path, this.onStepComplete});

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
    AdService.showInterstitial(
      contentId: '${widget.path.id}_${step.order}',
      onDismissed: () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContentViewerScreen(
                step: step,
                pathId: widget.path.id,
                pathCategory: widget.path.category, // ← wired correctly
                onComplete: () {
                  setState(() => _progress = HiveService.getProgress());
                  widget.onStepComplete?.call();
                },
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final completed = _progress.completedSteps[widget.path.id] ?? [];

    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(c, completed),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final step = widget.path.steps[i];
                  final isDone   = completed.contains(step.order);
                  final isLocked = !isDone &&
                      step.order > 1 &&
                      !completed.contains(step.order - 1);

                  return _StepTile(
                    step: step,
                    isDone:   isDone,
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

  Widget _buildAppBar(NexColors c, List<int> completed) {
    final total = widget.path.totalSteps;
    final levelColor = switch (widget.path.level) {
      'beginner'     => NexColors.success,
      'intermediate' => NexColors.warning,
      _              => NexColors.error,
    };

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: c.background,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                NexColors.primary.withOpacity(0.9),
                c.background,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.path.level.toUpperCase(),
                      style: TextStyle(
                          color: levelColor, fontSize: 11,
                          fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.path.title,
                      style: const TextStyle(color: Colors.white, fontSize: 26,
                          fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text('${completed.length} / $total lessons complete',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75), fontSize: 13)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0
                          ? (completed.length / total).clamp(0.0, 1.0)
                          : 0,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      color: Colors.white,
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Step Tile ────────────────────────────────────────────────────────────────
class _StepTile extends StatelessWidget {
  final PathStep step;
  final bool isDone, isLocked, isActive;
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
    final c = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDone
              ? NexColors.success.withOpacity(0.07)
              : isLocked
                  ? c.surface
                  : c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? NexColors.primary.withOpacity(0.5)
                : isDone
                    ? NexColors.success.withOpacity(0.3)
                    : c.border,
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            _buildStepIcon(c),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Step ${step.order}',
                      style: TextStyle(
                          color: isLocked ? c.textMuted : NexColors.primary,
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 3),
                  Text(step.title,
                      style: TextStyle(
                          color: isLocked ? c.textMuted : c.textPrimary,
                          fontSize: 15, fontWeight: FontWeight.w600,
                          height: 1.3)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(step.isYoutube ? '📹' : '📝',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('${step.sourceName} · ${step.duration}',
                            style: TextStyle(color: c.textMuted, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  if (step.note.isNotEmpty && isActive) ...[
                    const SizedBox(height: 8),
                    Text('💡 ${step.note}',
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 12,
                            fontStyle: FontStyle.italic, height: 1.4)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isLocked)
              Icon(Icons.lock_outline, color: c.textMuted, size: 18)
            else if (isDone)
              const Icon(Icons.check_circle, color: NexColors.success, size: 24)
            else
              const Icon(Icons.play_circle_outline,
                  color: NexColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIcon(NexColors c) {
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone
            ? NexColors.success.withOpacity(0.15)
            : isLocked
                ? c.border
                : NexColors.primary.withOpacity(0.15),
      ),
      child: Center(
        child: Text(
          isDone ? '✓' : '${step.order}',
          style: TextStyle(
            color: isDone
                ? NexColors.success
                : isLocked
                    ? c.textMuted
                    : NexColors.primary,
            fontSize: 14, fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

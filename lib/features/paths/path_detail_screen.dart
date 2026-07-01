import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/learning_path.dart';
import '../../core/models/user_progress.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/ad_manager.dart';
import '../../core/services/content_health_service.dart';
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

  /// Open a lesson step.
  /// Aggressive: attempts interstitial on EVERY tap (60s cooldown guards frequency).
  /// This naturally results in an ad every 1–2 lessons.
  void _openStep(PathStep step, {bool isPremiumLocked = false}) {
    if (isPremiumLocked) {
      _showRewardedUnlock(step);
      return;
    }
    if (ContentHealthService.isUnavailable(step.url)) {
      _showUnavailableDialog(step);
      return;
    }

    // MY PATH RULE: odd steps (1,3,5,7…) → interstitial; even steps → no ad.
    AdManager.instance.showInterstitialOnLessonTap(
      onDismissed: () => _navigateToContent(step),
      stepOrder: step.order,
    );
  }

  void _navigateToContent(PathStep step) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContentViewerScreen(
          step: step,
          pathId: widget.path.id,
          pathCategory: widget.path.category,
          onComplete: () {
            setState(() => _progress = HiveService.getProgress());
            widget.onStepComplete?.call();
          },
        ),
      ),
    );
  }

  void _showRewardedUnlock(PathStep step) {
    showDialog(
      context: context,
      builder: (_) => _RewardedUnlockDialog(
        step: step,
        onUnlocked: () => _navigateToContent(step),
      ),
    );
  }

  void _showUnavailableDialog(PathStep step) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Content Unavailable'),
        content: Text('"${step.title}" is currently unavailable. Would you like to report this?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Dismiss')),
          TextButton(
            onPressed: () {
              ContentHealthService.reportBrokenLink(step.url, step.title);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Broken link reported — thank you!')),
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final completed = _progress.completedSteps[widget.path.id] ?? [];

    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(c, completed),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            sliver: SliverList(
              // Native ad inserted after every 4 steps
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  // Every 5th slot (index 4, 9, 14…) is a native ad
                  final isPremium = HiveService.getProgress().isPremium;
                  if (!isPremium && i % 5 == 4) {
                    return _PathNativeAdSlot(c: c);
                  }
                  // Map list index → step index (accounting for ad slots)
                  final adsBefore = i ~/ 5;
                  final stepIdx   = i - adsBefore;
                  if (stepIdx >= widget.path.steps.length) return const SizedBox.shrink();

                  final step = widget.path.steps[stepIdx];
                  final isDone = completed.contains(step.order);
                  final isLocked = !isDone &&
                      step.order > 1 &&
                      !completed.contains(step.order - 1);
                  final isUnavailable = ContentHealthService.isUnavailable(step.url);

                  return _StepTile(
                    step: step,
                    isDone: isDone,
                    isLocked: isLocked,
                    isActive: !isDone && !isLocked,
                    isUnavailable: isUnavailable,
                    onTap: () => _openStep(step),
                  );
                },
                childCount: _totalSlots(widget.path.steps.length),
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
      'beginner' => NexColors.success,
      'intermediate' => NexColors.warning,
      _ => NexColors.error,
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
              colors: [NexColors.primary.withOpacity(0.9), c.background],
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      style: const TextStyle(
                          color: Colors.white, fontSize: 26,
                          fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text('${completed.length} / $total lessons complete',
                      style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? (completed.length / total).clamp(0.0, 1.0) : 0,
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


// ─── Helper ───────────────────────────────────────────────────────────────────
int _totalSlots(int stepCount) {
  // Total list items = steps + native ad slots (one per every 5)
  final adSlots = stepCount ~/ 4; // ad after every 4 steps
  return stepCount + adSlots;
}

// ─── Native Ad Slot in Path Detail ────────────────────────────────────────────
class _PathNativeAdSlot extends StatefulWidget {
  final NexColors c;
  const _PathNativeAdSlot({required this.c});
  @override
  State<_PathNativeAdSlot> createState() => _PathNativeAdSlotState();
}

class _PathNativeAdSlotState extends State<_PathNativeAdSlot> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = NativeAd(
      adUnitId: AdManager.instance.nativeAdUnitId,
      listener: NativeAdListener(
        onAdLoaded: (_) { if (mounted) setState(() => _loaded = true); },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() { _ad = null; _loaded = false; });
        },
      ),
      request: const AdRequest(),
      // Reverted to the previous small template/size — the medium/330
      // size didn't fit well in the path step list context.
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: widget.c.card,
        cornerRadius: 12,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: NexColors.primary,
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: widget.c.textPrimary,
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: widget.c.textMuted,
          style: NativeTemplateFontStyle.normal,
          size: 12,
        ),
      ),
    )..load();
  }

  @override
  void dispose() { _ad?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // No ad loaded (still loading, or failed) → render nothing at all.
    // Previously this always showed a bordered "Advertisement" placeholder
    // box even when there was no creative to show, which is exactly the
    // empty-container problem being fixed here.
    if (!_loaded || _ad == null) return const SizedBox.shrink();

    final c = widget.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 80,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: AdWidget(ad: _ad!),
    );
  }
}

// ─── Rewarded Unlock Dialog ───────────────────────────────────────────────────
class _RewardedUnlockDialog extends StatelessWidget {
  final PathStep step;
  final VoidCallback onUnlocked;
  const _RewardedUnlockDialog({required this.step, required this.onUnlocked});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Text('🎬', style: TextStyle(fontSize: 24)),
        SizedBox(width: 8),
        Text('Unlock Lesson'),
      ]),
      content: Text('Watch a short ad to unlock "${step.title}" for this session.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            AdManager.instance.showRewarded(
              onEarned: (_) => onUnlocked(),
              onDismissed: () {},
            );
          },
          child: const Text('Watch Ad'),
        ),
      ],
    );
  }
}

// ─── Step Tile ────────────────────────────────────────────────────────────────
class _StepTile extends StatelessWidget {
  final PathStep step;
  final bool isDone, isLocked, isActive, isUnavailable;
  final VoidCallback? onTap;

  const _StepTile({
    required this.step,
    required this.isDone,
    required this.isLocked,
    required this.isActive,
    required this.isUnavailable,
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
              : isLocked ? c.surface : c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnavailable
                ? NexColors.error.withOpacity(0.4)
                : isActive
                    ? NexColors.primary.withOpacity(0.5)
                    : isDone
                        ? NexColors.success.withOpacity(0.3)
                        : c.border,
            width: isActive || isUnavailable ? 1.5 : 0.5,
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
                  Row(
                    children: [
                      Text('Step ${step.order}',
                          style: TextStyle(
                              color: isLocked ? c.textMuted : NexColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3)),
                      if (isUnavailable) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: NexColors.error.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Unavailable',
                              style: TextStyle(
                                  color: NexColors.error,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(step.title,
                      style: TextStyle(
                          color: isLocked || isUnavailable ? c.textMuted : c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
                            color: c.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            height: 1.4)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isUnavailable)
              Icon(Icons.link_off, color: NexColors.error, size: 20)
            else if (isLocked)
              Icon(Icons.lock_outline, color: c.textMuted, size: 18)
            else if (isDone)
              const Icon(Icons.check_circle, color: NexColors.success, size: 24)
            else
              const Icon(Icons.play_circle_outline, color: NexColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIcon(NexColors c) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone
            ? NexColors.success.withOpacity(0.15)
            : isLocked ? c.border : NexColors.primary.withOpacity(0.15),
      ),
      child: Center(
        child: Text(
          isDone ? '✓' : '${step.order}',
          style: TextStyle(
            color: isDone ? NexColors.success : isLocked ? c.textMuted : NexColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

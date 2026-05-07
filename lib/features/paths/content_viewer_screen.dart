import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/learning_path.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/ad_service.dart';

class ContentViewerScreen extends StatefulWidget {
  final PathStep step;
  final String pathId;
  final VoidCallback? onComplete;

  const ContentViewerScreen({
    super.key,
    required this.step,
    required this.pathId,
    this.onComplete,
  });

  @override
  State<ContentViewerScreen> createState() => _ContentViewerScreenState();
}

class _ContentViewerScreenState extends State<ContentViewerScreen> {
  YoutubePlayerController? _ytController;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    if (widget.step.isYoutube) {
      _ytController = YoutubePlayerController(
        initialVideoId: widget.step.youtubeVideoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
        ),
      );
    }
    final p = HiveService.getProgress();
    _completed = p.isStepCompleted(widget.pathId, widget.step.order);
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  Future<void> _markComplete() async {
    final prev = HiveService.getProgress();
    final prevBadges = List<String>.from(prev.earnedBadges);

    final updated = await HiveService.completeStep(
        widget.pathId, widget.step.order, 10);

    setState(() => _completed = true);

    // Check for new badges
    for (final badge in updated.earnedBadges) {
      if (!prevBadges.contains(badge)) {
        await NotificationService.showBadgeNotification(_badgeName(badge));
      }
    }

    // Update streak notification
    await NotificationService.scheduleDailyReminder(
      hour: 9,
      minute: 0,
      streakDays: updated.streakDays,
    );
    if (updated.streakDays > 1) {
      await NotificationService.scheduleStreakWarning(updated.streakDays);
    }

    widget.onComplete?.call();

    if (mounted) {
      _showCompleteDialog(updated.totalXP, updated.streakDays);
    }
  }

  String _badgeName(String id) {
    const names = {
      'first_step': 'First Step',
      'streak_3': '3-Day Streak',
      'streak_7': '7-Day Streak',
      'streak_30': '30-Day Streak',
      'xp_100': '100 XP Club',
      'xp_500': '500 XP Legend',
      'lessons_10': '10 Lessons Done',
    };
    return names[id] ?? id;
  }

  void _showCompleteDialog(int totalXP, int streak) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 50)),
            const SizedBox(height: 12),
            const Text('Lesson Complete!',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('+10 XP  ·  🔥 $streak day streak',
                style: const TextStyle(
                    color: AppColors.accent, fontSize: 15)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  AdService.showInterstitial(
                      onDismissed: () => Navigator.pop(context));
                },
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          widget.step.title,
          style: const TextStyle(fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_completed)
            TextButton(
              onPressed: _markComplete,
              child: const Text('Mark Done',
                  style: TextStyle(color: AppColors.accent)),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.check_circle,
                  color: AppColors.success, size: 22),
            ),
        ],
      ),
      body: widget.step.isYoutube
          ? _buildYouTubeView()
          : _buildWebView(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildYouTubeView() {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _ytController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.primary,
        onEnded: (_) {
          if (!_completed) _markComplete();
        },
      ),
      builder: (context, player) => Column(
        children: [
          player,
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.step.title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('By ${widget.step.sourceName}  ·  ${widget.step.duration}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13)),
                  if (widget.step.note.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text('💡',
                              style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(widget.step.note,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.step.url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_completed) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      color: AppColors.surface,
      child: ElevatedButton.icon(
        onPressed: _markComplete,
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Mark as Complete',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/learning_path.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/ad_service.dart';
import '../../shared/widgets/shared_widgets.dart';

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

  // In-content banner ad
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

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
    _loadBannerAd();
  }

  Future<void> _loadBannerAd() async {
    final progress = HiveService.getProgress();
    if (progress.isPremium) return; // no ads for premium
    final ad = AdService.createBanner();
    await ad.load();
    if (mounted) setState(() { _bannerAd = ad; _bannerLoaded = true; });
  }

  @override
  void dispose() {
    _ytController?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _markComplete() async {
    final prev = HiveService.getProgress();
    final prevBadges = List<String>.from(prev.earnedBadges);
    final updated = await HiveService.completeStep(
        widget.pathId, widget.step.order, 10);

    setState(() => _completed = true);

    for (final badge in updated.earnedBadges) {
      if (!prevBadges.contains(badge)) {
        try { await NotificationService.showBadgeNotification(_badgeName(badge)); }
        catch (_) {}
      }
    }

    try {
      await NotificationService.scheduleDailyReminder(
        hour: 9, minute: 0, streakDays: updated.streakDays);
      if (updated.streakDays > 1) {
        await NotificationService.scheduleStreakWarning(updated.streakDays);
      }
    } catch (_) {}

    widget.onComplete?.call();
    if (mounted) _showCompleteDialog(updated.totalXP, updated.streakDays);
  }

  String _badgeName(String id) => const {
    'first_step': 'First Step',
    'streak_3':   '3-Day Streak',
    'streak_7':   '7-Day Streak',
    'streak_30':  '30-Day Streak',
    'xp_100':     '100 XP Club',
    'xp_500':     '500 XP Legend',
    'lessons_10': '10 Lessons Done',
  }[id] ?? id;

  void _showCompleteDialog(int totalXP, int streak) {
    final c = context.colors;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 50)),
            const SizedBox(height: 12),
            Text('Lesson Complete!',
                style: TextStyle(color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('+10 XP  ·  🔥 $streak day streak',
                style: const TextStyle(color: NexColors.accent, fontSize: 15)),
            const SizedBox(height: 20),
            // Offer bonus lesson via rewarded ad
            _RewardedBonusButton(streak: streak),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // back to paths
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
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(
          widget.step.title,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_completed)
            TextButton(
              onPressed: _markComplete,
              child: const Text('Mark Done',
                  style: TextStyle(color: NexColors.accent, fontWeight: FontWeight.w700)),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.check_circle, color: NexColors.success, size: 22),
            ),
        ],
      ),
      body: widget.step.isYoutube
          ? _buildYouTubeView(c)
          : _buildWebView(),
      bottomNavigationBar: _buildBottomBar(c),
    );
  }

  Widget _buildYouTubeView(NexColors c) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _ytController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: NexColors.primary,
        onEnded: (_) { if (!_completed) _markComplete(); },
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
                      style: TextStyle(
                          color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('By ${widget.step.sourceName}  ·  ${widget.step.duration}',
                      style: TextStyle(color: c.textMuted, fontSize: 13)),
                  if (widget.step.note.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(widget.step.note,
                                style: TextStyle(
                                    color: c.textSecondary, fontSize: 14, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Banner ad in the empty space below video info ───
                  if (_bannerLoaded && _bannerAd != null) ...[
                    const SizedBox(height: 24),
                    _InContentBannerAd(ad: _bannerAd!),
                  ],

                  // ── Affiliate course CTA ───────────────────────────
                  const SizedBox(height: 24),
                  _CourseUpgradeCTA(category: 'ai'), // placeholder — wire category from path
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

  Widget _buildBottomBar(NexColors c) {
    if (_completed) return const SizedBox.shrink();
    return Container(
      color: c.surface,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: ElevatedButton.icon(
        onPressed: _markComplete,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
        label: const Text('Mark as Complete',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ─── In-content banner ad ─────────────────────────────────────────────────────
// Clearly separated from content — policy compliant, no fake close buttons
class _InContentBannerAd extends StatelessWidget {
  final BannerAd ad;
  const _InContentBannerAd({required this.ad});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Divider(color: c.border),
        const SizedBox(height: 4),
        Text('Advertisement',
            style: TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Container(
          alignment: Alignment.center,
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
        const SizedBox(height: 4),
        Divider(color: c.border),
      ],
    );
  }
}

// ─── Rewarded bonus lesson button (shown in completion dialog) ────────────────
class _RewardedBonusButton extends StatelessWidget {
  final int streak;
  const _RewardedBonusButton({required this.streak});

  @override
  Widget build(BuildContext context) {
    final progress = HiveService.getProgress();
    if (progress.isPremium) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          AdService.showRewarded(
            onRewarded: (_) async {
              // Grant +50 bonus XP
              final p = HiveService.getProgress();
              p.totalXP += 50;
              await HiveService.saveProgress(p);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎁 +50 Bonus XP earned!'),
                    backgroundColor: NexColors.accent,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          );
        },
        icon: const Icon(Icons.play_circle_outline, size: 18),
        label: const Text('Watch Ad → +50 Bonus XP'),
        style: OutlinedButton.styleFrom(
          foregroundColor: NexColors.accent,
          side: const BorderSide(color: NexColors.accent),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ─── Contextual course upsell (affiliate) ─────────────────────────────────────
class _CourseUpgradeCTA extends StatelessWidget {
  final String category;
  const _CourseUpgradeCTA({required this.category});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cat = AppCategories.byId(category);
    if (cat == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NexColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(cat.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text('Go deeper',
                  style: TextStyle(
                      color: NexColors.primary,
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Get certified in ${cat.title}',
              style: TextStyle(
                  color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Top-rated courses from Udemy & Coursera.',
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: NexColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Browse Courses →',
                style: TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/learning_path.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/revenue_config.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/mediated_banner_widget.dart';

class ContentViewerScreen extends StatefulWidget {
  final PathStep step;
  final String pathId;
  final String pathCategory; // ← pass from PathDetailScreen
  final VoidCallback? onComplete;

  const ContentViewerScreen({
    super.key,
    required this.step,
    required this.pathId,
    required this.pathCategory,
    this.onComplete,
  });

  @override
  State<ContentViewerScreen> createState() => _ContentViewerScreenState();
}

class _ContentViewerScreenState extends State<ContentViewerScreen> {
  YoutubePlayerController? _ytController;
  bool _completed     = false;
  bool _ytError       = false; // true when channel blocks embedding (Error 150)

  @override
  void initState() {
    super.initState();
    _completed = HiveService.getProgress()
        .isStepCompleted(widget.pathId, widget.step.order);

    if (widget.step.isYoutube) {
      _ytController = YoutubePlayerController(
        initialVideoId: widget.step.youtubeVideoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
          forceHD: false,
        ),
      );
      // Listen for errors — Error 150 = embedding disabled by channel
      _ytController!.addListener(_onYtListener);
    }
  }

  void _onYtListener() {
    if (_ytController!.value.hasError && !_ytError) {
      setState(() => _ytError = true);
    }
  }

  @override
  void dispose() {
    _ytController?.removeListener(_onYtListener);
    _ytController?.dispose();
    super.dispose();
  }

  Future<void> _markComplete() async {
    final prev     = HiveService.getProgress();
    final prevBadges = List<String>.from(prev.earnedBadges);
    final updated  = await HiveService.completeStep(
        widget.pathId, widget.step.order, 10);

    if (mounted) setState(() => _completed = true);

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
    'first_step': 'First Step',    'streak_3': '3-Day Streak',
    'streak_7':   '7-Day Streak',  'streak_30': '30-Day Streak',
    'xp_100':     '100 XP Club',   'xp_500': '500 XP Legend',
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
                style: TextStyle(color: c.textPrimary, fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('+10 XP  ·  🔥 $streak day streak',
                style: const TextStyle(color: NexColors.accent, fontSize: 15)),
            const SizedBox(height: 20),
            _RewardedBonusButton(),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
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
        title: Text(widget.step.title,
            style: TextStyle(color: c.textPrimary, fontSize: 15),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_completed)
            TextButton(
              onPressed: _markComplete,
              child: const Text('Mark Done',
                  style: TextStyle(
                      color: NexColors.accent, fontWeight: FontWeight.w700)),
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

  // ─── YouTube view with Error 150 fallback ─────────────────────────────────
  Widget _buildYouTubeView(NexColors c) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _ytController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: NexColors.primary,
        onEnded: (_) { if (!_completed) _markComplete(); },
      ),
      builder: (context, player) {
        return Column(
          children: [
            // If Error 150, replace player with a nice fallback card
            _ytError ? _buildEmbedErrorFallback(c) : player,

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + meta
                    Text(widget.step.title,
                        style: TextStyle(color: c.textPrimary, fontSize: 18,
                            fontWeight: FontWeight.w700, height: 1.3)),
                    const SizedBox(height: 8),
                    Text('By ${widget.step.sourceName}  ·  ${widget.step.duration}',
                        style: TextStyle(color: c.textMuted, fontSize: 13)),

                    // Note
                    if (widget.step.note.isNotEmpty) ...[
                      const SizedBox(height: 14),
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
                                  style: TextStyle(color: c.textSecondary,
                                      fontSize: 13, height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Banner ad — AdMob primary, Unity fallback ──
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        Divider(color: c.border),
                        const SizedBox(height: 4),
                        const MediatedBannerWidget(label: 'Advertisement'),
                        const SizedBox(height: 4),
                        Divider(color: c.border),
                      ],
                    ),

                    // ── Rewarded XP ────────────────────────────────
                    const SizedBox(height: 20),
                    _RewardedBonusButton(),

                    // ── Affiliate CTA — uses CORRECT category ──────
                    const SizedBox(height: 20),
                    _AffiliateCTA(category: widget.pathCategory),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Error 150 fallback — clean card with "Watch on YouTube" button ────────
  Widget _buildEmbedErrorFallback(NexColors c) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('▶️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            'This video can\'t play inside the app',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'The creator disabled in-app playback.\nWatch it free on YouTube.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final url = Uri.parse(widget.step.url);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: const Text('Open in YouTube',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000), // YouTube red
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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


// ─── Rewarded +50 XP ──────────────────────────────────────────────────────────
class _RewardedBonusButton extends StatelessWidget {
  const _RewardedBonusButton();

  @override
  Widget build(BuildContext context) {
    if (HiveService.getProgress().isPremium) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          AdService.showRewarded(
            onRewarded: (_) async {
              final p = HiveService.getProgress();
              p.totalXP += 50;
              await HiveService.saveProgress(p);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('🎁 +50 Bonus XP earned!'),
                  backgroundColor: NexColors.accent,
                  duration: Duration(seconds: 2),
                ));
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

// ─── Affiliate CTA — uses correct category from the path ─────────────────────
class _AffiliateCTA extends StatelessWidget {
  final String category;
  const _AffiliateCTA({required this.category});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final offers = RevenueConfig.offersByCategory[category] ?? [];
    if (offers.isEmpty) return const SizedBox.shrink();
    final offer = offers.first;

    return GestureDetector(
      onTap: () async {
        final url = Uri.parse(offer.baseUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
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
                Text(offer.platformEmoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text('Go deeper', style: TextStyle(
                    color: NexColors.primary, fontSize: 12,
                    fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NexColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(offer.salePrice,
                      style: const TextStyle(color: NexColors.success,
                          fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(offer.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offer.title,
                          style: TextStyle(color: c.textPrimary, fontSize: 14,
                              fontWeight: FontWeight.w700, height: 1.2)),
                      const SizedBox(height: 2),
                      Text(offer.subtitle,
                          style: TextStyle(color: c.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: NexColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('View on ${offer.platformName} →',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text('We may earn a commission · No extra cost to you',
                  style: TextStyle(color: c.textMuted, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }
}

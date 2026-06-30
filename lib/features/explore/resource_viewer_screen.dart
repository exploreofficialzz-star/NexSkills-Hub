import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/resource_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/revenue_config.dart';
import '../../shared/widgets/mediated_banner_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class ResourceViewerScreen extends StatefulWidget {
  final ResourceModel resource;
  const ResourceViewerScreen({super.key, required this.resource});

  @override
  State<ResourceViewerScreen> createState() => _ResourceViewerScreenState();
}

class _ResourceViewerScreenState extends State<ResourceViewerScreen> {
  YoutubePlayerController? _ytController;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.resource.isBookmarked;
    HiveService.markRead(widget.resource.id);

    if (widget.resource.isYoutube) {
      _ytController = YoutubePlayerController(
        initialVideoId: widget.resource.youtubeVideoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  Future<void> _toggleBookmark() async {
    await HiveService.toggleBookmark(widget.resource.id);
    setState(() => _isBookmarked = !_isBookmarked);
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
          widget.resource.sourceName,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? NexColors.primary : c.textMuted,
            ),
            onPressed: _toggleBookmark,
          ),
        ],
      ),
      body: widget.resource.isYoutube
          ? _buildYouTubeView(c)
          : _buildWebView(),
    );
  }

  // ─── YouTube layout ─────────────────────────────────────────────────────────
  Widget _buildYouTubeView(NexColors c) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _ytController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: NexColors.primary,
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
                  // ── Video title + meta ─────────────────────────
                  Text(widget.resource.title,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.3)),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.resource.sourceName}  ·  ${_timeAgo(widget.resource.publishedAt)}',
                    style: TextStyle(color: c.textMuted, fontSize: 13),
                  ),

                  // ── Description ───────────────────────────────
                  if (widget.resource.description != null &&
                      widget.resource.description!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border, width: 0.5),
                      ),
                      child: Text(
                        widget.resource.description!
                            .replaceAll(RegExp(r'<[^>]*>'), ''),
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 13, height: 1.5),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  // ── Banner ad — AdMob primary, Unity fallback ───
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

                  // ── Rewarded bonus XP ─────────────────────────
                  const SizedBox(height: 20),
                  _RewardedXPButton(),

                  // ── Affiliate course CTA ───────────────────────
                  const SizedBox(height: 20),
                  _AffiliateCTA(category: widget.resource.category),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── WebView (articles) ─────────────────────────────────────────────────────
  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.resource.url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }
}

// ─── In-content banner ad ──────────────────────────────────────────────────────


// ─── Rewarded +50 XP button ────────────────────────────────────────────────────
class _RewardedXPButton extends StatelessWidget {
  const _RewardedXPButton();

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

// ─── Affiliate course CTA ──────────────────────────────────────────────────────
class _AffiliateCTA extends StatelessWidget {
  final String category;
  const _AffiliateCTA({required this.category});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final offers = RevenueConfig.offersByCategory[category] ?? [];
    if (offers.isEmpty) return const SizedBox.shrink();

    // Pick offer deterministically based on category
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
                Text('Go deeper',
                    style: TextStyle(
                        color: NexColors.primary,
                        fontSize: 12, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NexColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(offer.salePrice,
                      style: const TextStyle(
                          color: NexColors.success,
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
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14, fontWeight: FontWeight.w700,
                              height: 1.2)),
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
              child: Text(
                'View on ${offer.platformName} →',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'We may earn a commission · No extra cost to you',
                style: TextStyle(color: c.textMuted, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

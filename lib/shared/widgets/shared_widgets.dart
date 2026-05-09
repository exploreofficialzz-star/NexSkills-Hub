import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/resource_model.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/hive_service.dart';

// ─── Adaptive Banner Widget ───────────────────────────────────────────────────
/// Higher eCPM than standard banner — uses full available width.
/// Policy compliant: fixed position, clearly separated from content.
class AdaptiveBannerWidget extends StatefulWidget {
  const AdaptiveBannerWidget({super.key});

  @override
  State<AdaptiveBannerWidget> createState() => _AdaptiveBannerWidgetState();
}

class _AdaptiveBannerWidgetState extends State<AdaptiveBannerWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null && !HiveService.getProgress().isPremium) {
      _load();
    }
  }

  Future<void> _load() async {
    final ad = await AdService.createAdaptiveBanner(context);
    ad.load().then((_) {
      if (mounted) setState(() { _ad = ad; _loaded = true; });
    });
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = HiveService.getProgress();
    if (progress.isPremium || !_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    final c = context.colors;
    return Container(
      color: c.surface,
      alignment: Alignment.center,
      width:  _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}

// Keep old name as alias so existing screens don't break
class BannerAdWidget extends AdaptiveBannerWidget {
  const BannerAdWidget({super.key});
}

// ─── Streak-save Rewarded Prompt ──────────────────────────────────────────────
/// Show this when a user's streak is at risk (no lesson done today).
/// Policy compliant: user-initiated, optional, reward clearly described.
class StreakSavePrompt extends StatelessWidget {
  final VoidCallback onSaved;
  final VoidCallback onDismissed;

  const StreakSavePrompt({
    super.key,
    required this.onSaved,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text('🔥', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text(
            'Your streak is at risk!',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Watch a short ad to save your streak for today — free.",
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                AdService.showRewarded(
                  onRewarded: (_) => onSaved(),
                  onDismissed: onDismissed,
                );
              },
              icon: const Icon(Icons.play_circle_outline, color: Colors.white),
              label: const Text('Watch Ad — Save Streak'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NexColors.accentOrange,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () { Navigator.pop(context); onDismissed(); },
            child: Text('No thanks',
                style: TextStyle(color: c.textMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Bonus Lesson Rewarded Prompt ────────────────────────────────────────────
/// Shown after completing today's required lesson.
/// Policy: optional, clearly user-initiated.
class BonusLessonPrompt extends StatelessWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onDismissed;

  const BonusLessonPrompt({
    super.key,
    required this.onUnlocked,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text('🎁', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text('Want a bonus lesson?',
              style: TextStyle(color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Watch a short ad to unlock an extra lesson and earn +50 XP.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                AdService.showRewarded(
                  onRewarded: (_) => onUnlocked(),
                  onDismissed: onDismissed,
                );
              },
              icon: const Icon(Icons.play_circle_outline, color: Colors.white),
              label: const Text('Watch Ad — Get Bonus Lesson'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () { Navigator.pop(context); onDismissed(); },
            child: Text('No thanks', style: TextStyle(color: c.textMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Resource Card ────────────────────────────────────────────────────────────
class ResourceCard extends StatelessWidget {
  final ResourceModel resource;
  final VoidCallback onTap;
  final VoidCallback? onBookmark;

  const ResourceCard({
    super.key,
    required this.resource,
    required this.onTap,
    this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (resource.thumbnail != null) _buildThumbnail(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TypeBadge(type: resource.type),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(resource.sourceName,
                            style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (onBookmark != null)
                        GestureDetector(
                          onTap: onBookmark,
                          child: Icon(
                            resource.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: resource.isBookmarked ? NexColors.primary : c.textMuted,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(resource.title,
                      style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (resource.description != null) ...[
                    const SizedBox(height: 6),
                    Text(resource.description!.replaceAll(RegExp(r'<[^>]*>'), ''),
                        style: TextStyle(color: c.textMuted, fontSize: 13),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Text(_timeAgo(resource.publishedAt),
                      style: TextStyle(color: c.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: CachedNetworkImage(
        imageUrl: resource.thumbnail!,
        height: 160, width: double.infinity, fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 160, color: const Color(0xFF1E2438),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: NexColors.primary)),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 160, color: const Color(0xFF1E2438),
          child: const Icon(Icons.image_not_supported, color: Color(0xFF6B7494), size: 40),
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0)  return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isVideo   = type == 'video';
    final isPodcast = type == 'podcast';
    final color = isVideo ? NexColors.primary : isPodcast ? NexColors.accentOrange : NexColors.accent;
    final label = isVideo ? '📹 Video' : isPodcast ? '🎙 Podcast' : '📝 Article';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Shimmer ──────────────────────────────────────────────────────────────────
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Shimmer.fromColors(
      baseColor:      c.card,
      highlightColor: c.surface,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 220,
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int count;
  const ShimmerList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: count,
    padding: const EdgeInsets.all(16),
    itemBuilder: (_, __) => const ShimmerCard(),
  );
}

// ─── Stat Pill ────────────────────────────────────────────────────────────────
class StatPill extends StatelessWidget {
  final String label, value;
  final Color color;

  const StatPill({super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Theme toggle tile (for Settings / Progress screen) ───────────────────────
class ThemeToggleTile extends StatelessWidget {
  final ThemeMode current;
  final void Function(ThemeMode) onChanged;

  const ThemeToggleTile({super.key, required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final options = [
      (ThemeMode.system, '⚙️', 'System'),
      (ThemeMode.dark,   '🌙', 'Dark'),
      (ThemeMode.light,  '☀️', 'Light'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: options.map((o) {
          final selected = current == o.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? NexColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(o.$2, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(o.$3,
                        style: TextStyle(
                          color: selected ? Colors.white : c.textMuted,
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

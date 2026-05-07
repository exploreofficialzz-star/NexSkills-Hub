import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/constants/app_constants.dart';
import '../core/models/resource_model.dart';
import '../core/services/ad_service.dart';
import '../core/services/hive_service.dart';

// ─── Banner Ad Widget ────────────────────────────────────────────
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final progress = HiveService.getProgress();
    if (!progress.isPremium) {
      _ad = AdService.createBanner()
        ..load().then((_) {
          if (mounted) setState(() => _loaded = true);
        });
    }
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
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}

// ─── Resource Card ───────────────────────────────────────────────
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
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
                        child: Text(
                          resource.sourceName,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onBookmark != null)
                        GestureDetector(
                          onTap: onBookmark,
                          child: Icon(
                            resource.isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: resource.isBookmarked
                                ? AppColors.primary
                                : AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    resource.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (resource.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      resource.description!
                          .replaceAll(RegExp(r'<[^>]*>'), ''),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _timeAgo(resource.publishedAt),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
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
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 160,
          color: AppColors.surface,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 160,
          color: AppColors.surface,
          child: const Icon(Icons.image_not_supported,
              color: AppColors.textMuted, size: 40),
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} months ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

// ─── Type Badge ──────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isVideo = type == 'video';
    final isPodcast = type == 'podcast';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isVideo
            ? AppColors.primary.withOpacity(0.2)
            : isPodcast
                ? AppColors.accentOrange.withOpacity(0.2)
                : AppColors.accent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isVideo ? '📹 Video' : isPodcast ? '🎙 Podcast' : '📝 Article',
        style: TextStyle(
          color: isVideo
              ? AppColors.primary
              : isPodcast
                  ? AppColors.accentOrange
                  : AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Shimmer Loader ──────────────────────────────────────────────
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.card,
      highlightColor: AppColors.surface,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int count;
  const ShimmerList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, __) => const ShimmerCard(),
    );
  }
}

// ─── Stat Pill ───────────────────────────────────────────────────
class StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const StatPill({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/resource_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/rss_service.dart';
import '../../core/services/ad_manager.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'video_player_screen.dart';
import 'resource_viewer_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
  String _selectedCategory = 'all';
  String _selectedType = 'all';
  List<ResourceModel> _items = [];
  Set<String> _consumedIds = {};
  bool _loading = true;
  bool _refreshing = false;
  String? _error;


  static const _categories = [
    ('all', '🌐', 'All'),
    ('ai', '🤖', 'AI'),
    ('cybersecurity', '🔐', 'Cyber'),
    ('nocode', '⚡', 'No-Code'),
    ('data', '📊', 'Data'),
    ('cloud', '☁️', 'Cloud'),
  ];

  static const _types = [
    ('all', 'All'),
    ('video', 'Videos'),
    ('article', 'Articles'),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _consumedIds = HiveService.getAllConsumedIds();
    _loadFromCache();
    _fetchFresh();
    // Sticky banner removed — it overlapped the floating nav bar.
  }

  @override
  void dispose() {
    super.dispose();
  }


  void _loadFromCache() {
    const allCats = ['ai', 'cybersecurity', 'nocode', 'data', 'cloud'];
    final raw = _selectedCategory == 'all'
        ? allCats.expand((c) => HiveService.getResourcesByCategory(c)).toList()
        : HiveService.getResourcesByCategory(_selectedCategory);
    if (mounted) setState(() {
      _items = _sortWithConsumedAtBottom(raw);
      if (raw.isNotEmpty) _loading = false;
    });
  }

  /// Smart feed — interleaves content from ALL categories and mixes
  /// videos with articles so no single source dominates.
  ///
  /// Algorithm:
  ///   1. Separate unconsumed / consumed
  ///   2. Within each group: group by category, sort each by date
  ///   3. Round-robin across categories (ai → cyber → nocode → data → cloud)
  ///   4. Insert a video every 3rd slot when available
  ///   5. Consumed items sink to the bottom
  List<ResourceModel> _sortWithConsumedAtBottom(List<ResourceModel> src) {
    final unconsumed = src.where((r) => !_consumedIds.contains(r.id)).toList();
    final consumed   = src.where((r) => _consumedIds.contains(r.id)).toList();
    return [..._interleave(unconsumed), ..._interleave(consumed)];
  }

  List<ResourceModel> _interleave(List<ResourceModel> items) {
    if (items.isEmpty) return items;

    // Separate videos and articles
    final videos   = items.where(_isVideo).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final articles = items.where((r) => !_isVideo(r)).toList();

    // Group articles by category in a fixed order for consistency
    const catOrder = ['ai', 'cybersecurity', 'nocode', 'data', 'cloud'];
    final groups = <String, List<ResourceModel>>{
      for (final cat in catOrder) cat: [],
    };
    for (final r in articles) {
      groups.putIfAbsent(r.category, () => []);
      groups[r.category]!.add(r);
    }
    // Sort each group newest-first
    for (final g in groups.values) {
      g.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    }

    final result = <ResourceModel>[];
    final keys = groups.keys.where((k) => groups[k]!.isNotEmpty).toList();
    int videoIdx = 0;
    int totalAdded = 0;

    bool hasMore = true;
    while (hasMore) {
      hasMore = false;
      for (final key in keys) {
        final list = groups[key]!;
        if (list.isEmpty) continue;

        // Insert a video every 3rd article slot
        if (videoIdx < videos.length && totalAdded % 3 == 2) {
          result.add(videos[videoIdx++]);
          totalAdded++;
          hasMore = true;
        }

        result.add(list.removeAt(0));
        totalAdded++;
        hasMore = true;
      }
    }

    // Append remaining videos at end
    if (videoIdx < videos.length) {
      result.addAll(videos.sublist(videoIdx));
    }

    return result;
  }

  Future<void> _fetchFresh() async {
    if (mounted) setState(() { _refreshing = true; _error = null; });
    try {
      await RssService.fetchAll();
      _consumedIds = HiveService.getAllConsumedIds();
      _loadFromCache();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not fetch. Check your connection.');
    } finally {
      if (mounted) setState(() { _refreshing = false; _loading = false; });
    }
  }

  // Robust video detection — checks stored type AND URL pattern
  bool _isVideo(ResourceModel r) => r.type == 'video' || r.isYoutube;

  List<ResourceModel> get _filtered {
    var list = _items;
    if (_selectedCategory != 'all') {
      list = list.where((r) => r.category == _selectedCategory).toList();
    }
    if (_selectedType == 'video') {
      list = list.where(_isVideo).toList();
    } else if (_selectedType == 'article') {
      list = list.where((r) => !_isVideo(r)).toList();
    }
    return list;
  }

  void _openResource(ResourceModel r) {
    // Aggressive: interstitial every 2-3 content clicks
    AdManager.instance.showInterstitialOnContentClick(
      onDismissed: () {
        if (!mounted) return;
        if (_isVideo(r)) {
          // In-app YouTube player — no redirect
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => VideoPlayerScreen(resource: r)));
          _markConsumed(r);
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => ResourceViewerScreen(resource: r)))
          .then((_) => _markConsumed(r));
        }
      },
    );
  }

  void _markConsumed(ResourceModel r) {
    HiveService.markConsumed(r.id);
    HiveService.markRead(r.id);
    if (mounted) setState(() {
      _consumedIds = HiveService.getAllConsumedIds();
      _items = _sortWithConsumedAtBottom(_items);
    });
  }

  Future<void> _toggleBookmark(ResourceModel r) async {
    await HiveService.toggleBookmark(r.id);
    _loadFromCache();
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('Resets your watched/read list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await HiveService.clearConsumedItems();
      if (mounted) setState(() { _consumedIds = {}; _items = _sortWithConsumedAtBottom(_items); });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.colors;

    return RepaintBoundary(
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(c),
              _buildCategoryFilter(c),
              _buildTypeFilter(c),
              if (_error != null) _buildErrorBar(c),
              Expanded(
                child: _loading
                    ? const ShimmerList()
                    : RefreshIndicator(
                        onRefresh: _fetchFresh,
                        color: NexColors.primary,
                        backgroundColor: c.card,
                        child: _buildList(c),
                      ),
              ),
              // Banner removed — native ads every 3 items provide ad revenue
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(NexColors c) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Explore', style: TextStyle(color: c.textPrimary, fontSize: 28,
            fontWeight: FontWeight.w800, letterSpacing: -0.8)),
        Text('Fresh content from top sources',
            style: TextStyle(color: c.textMuted, fontSize: 13)),
      ])),
      GestureDetector(onTap: _clearHistory,
          child: Padding(padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.history_toggle_off, color: c.textMuted, size: 22))),
      _refreshing
          ? SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: NexColors.primary))
          : GestureDetector(onTap: _fetchFresh,
              child: Icon(Icons.refresh, color: c.textMuted)),
    ]),
  );

  Widget _buildErrorBar(NexColors c) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: Row(children: [
      const Icon(Icons.wifi_off, color: NexColors.error, size: 14),
      const SizedBox(width: 8),
      Expanded(child: Text(_error!, style: const TextStyle(color: NexColors.error, fontSize: 12))),
      GestureDetector(onTap: _fetchFresh,
          child: const Text('Retry', style: TextStyle(
              color: NexColors.primary, fontSize: 12, fontWeight: FontWeight.w700))),
    ]),
  );

  Widget _buildCategoryFilter(NexColors c) => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final cat = _categories[i];
        final sel = _selectedCategory == cat.$1;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? NexColors.primary : c.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? NexColors.primary : c.border, width: 0.5),
            ),
            child: Text('${cat.$2} ${cat.$3}',
                style: TextStyle(color: sel ? Colors.white : c.textMuted,
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        );
      },
    ),
  );

  Widget _buildTypeFilter(NexColors c) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
    child: Row(children: _types.map((t) {
      final sel = _selectedType == t.$1;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _selectedType = t.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: sel ? NexColors.accent.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sel ? NexColors.accent : c.textMuted.withOpacity(0.3)),
            ),
            child: Text(t.$2, style: TextStyle(
                color: sel ? NexColors.accent : c.textMuted,
                fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }).toList()),
  );

  Widget _buildList(NexColors c) {
    final items = _filtered;
    if (items.isEmpty) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Center(child: Column(children: [
          const Text('📡', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text('No content yet', style: TextStyle(color: c.textPrimary,
              fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Pull down to fetch latest content',
              style: TextStyle(color: c.textMuted, fontSize: 13)),
        ])),
      ]);
    }

    final isPremium = HiveService.getProgress().isPremium;

    // Interleave: native ad every 3 content items (aggressive)
    final withAds = <dynamic>[];
    int count = 0;
    for (final item in items) {
      withAds.add(item);
      count++;
      if (!isPremium && count % 3 == 0) withAds.add('native_ad');
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      itemCount: withAds.length,
      itemBuilder: (_, i) {
        if (withAds[i] == 'native_ad') return _NativeAdSlot(c: c);
        final r = withAds[i] as ResourceModel;
        final isConsumed = _consumedIds.contains(r.id);
        return GestureDetector(
          onLongPress: isConsumed ? () async {
            await HiveService.clearConsumedItems();
            if (mounted) setState(() {
              _consumedIds = {};
              _items = _sortWithConsumedAtBottom(_items);
            });
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('History cleared')));
          } : null,
          child: _ContentCard(
            resource: r,
            isVideo: _isVideo(r),
            isConsumed: isConsumed,
            onTap: () => _openResource(r),
            onBookmark: () => _toggleBookmark(r),
          ),
        );
      },
    );
  }
}

// ─── Content Card ─────────────────────────────────────────────────────────────
class _ContentCard extends StatelessWidget {
  final ResourceModel resource;
  final bool isVideo;
  final bool isConsumed;
  final VoidCallback onTap;
  final VoidCallback onBookmark;

  const _ContentCard({
    required this.resource,
    required this.isVideo,
    required this.isConsumed,
    required this.onTap,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isConsumed ? 0.62 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thumbnail (always shown — shimmer while loading) ──
              _Thumbnail(resource: resource, isVideo: isVideo),
              // ── Text body ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _TypeBadge(isVideo: isVideo),
                      if (isConsumed) ...[
                        const SizedBox(width: 8),
                        _ConsumedChip(isVideo: isVideo),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: onBookmark,
                        child: Icon(
                          resource.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: resource.isBookmarked ? NexColors.primary : c.textMuted,
                          size: 20,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(resource.title,
                        style: TextStyle(color: c.textPrimary, fontSize: 15,
                            fontWeight: FontWeight.w700, height: 1.35),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    if (resource.description != null &&
                        resource.description!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(resource.description!,
                          style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.4),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 8),
                    Text(resource.sourceName,
                        style: TextStyle(color: c.textMuted, fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Thumbnail ────────────────────────────────────────────────────────────────
class _Thumbnail extends StatelessWidget {
  final ResourceModel resource;
  final bool isVideo;
  const _Thumbnail({required this.resource, required this.isVideo});

  static const _catColors = {
    'ai':            Color(0xFF6C63FF),
    'cybersecurity': Color(0xFF00C853),
    'nocode':        Color(0xFFFF6D00),
    'data':          Color(0xFF0091EA),
    'cloud':         Color(0xFF00B8D4),
  };

  static const _catIcons = {
    'ai': '🤖', 'cybersecurity': '🔐', 'nocode': '⚡',
    'data': '📊', 'cloud': '☁️',
  };

  @override
  Widget build(BuildContext context) {
    // Compute effective thumbnail at render time.
    // If stored thumbnail is null, try clearbit logo from the article URL.
    // This handles old cached articles stored before the clearbit fallback was added.
    String? thumb = resource.thumbnail;
    if (thumb == null && resource.url.isNotEmpty) {
      try {
        final host = Uri.parse(resource.url).host.replaceAll('www.', '');
        if (host.isNotEmpty) thumb = 'https://logo.clearbit.com/$host';
      } catch (_) {}
    }
    const h = 190.0;
    final radius = const BorderRadius.vertical(top: Radius.circular(16));
    final isClearbit = thumb != null && thumb.contains('logo.clearbit.com');

    // No thumbnail at all → gradient placeholder
    if (thumb == null) {
      return _GradientPlaceholder(
          category: resource.category, sourceName: resource.sourceName,
          isVideo: isVideo, height: h, radius: radius);
    }

    return ClipRRect(
      borderRadius: radius,
      child: Stack(children: [
        // Image with shimmer placeholder
        CachedNetworkImage(
          imageUrl: thumb,
          width: double.infinity,
          height: isClearbit ? 100 : h,
          fit: isClearbit ? BoxFit.contain : BoxFit.cover,
          memCacheWidth: 640,
          memCacheHeight: 360,
          // ── Shimmer while loading ─────────────────────────────
          placeholder: (_, __) => _ShimmerBox(
              width: double.infinity, height: isClearbit ? 100 : h),
          // ── Gradient bg for clearbit logos ───────────────────
          imageBuilder: isClearbit
              ? (_, img) => Container(
                    width: double.infinity,
                    height: 100,
                    color: _catColors[resource.category]?.withOpacity(0.12)
                        ?? Colors.grey.withOpacity(0.1),
                    padding: const EdgeInsets.all(16),
                    child: Image(image: img, fit: BoxFit.contain),
                  )
              : null,
          errorWidget: (_, __, ___) => _GradientPlaceholder(
              category: resource.category, sourceName: resource.sourceName,
              isVideo: isVideo, height: h, radius: BorderRadius.zero),
        ),
        // Play button overlay on YouTube thumbnails
        if (isVideo && !isClearbit)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_filled, color: Colors.white, size: 58),
              ),
            ),
          ),
      ]),
    );
  }
}

// ─── Shimmer box ──────────────────────────────────────────────────────────────
class _ShimmerBox extends StatelessWidget {
  final double width, height;
  const _ShimmerBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Shimmer.fromColors(
      baseColor:      isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE0E0E0),
      highlightColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5),
      child: Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }
}

// ─── Gradient Placeholder ─────────────────────────────────────────────────────
class _GradientPlaceholder extends StatelessWidget {
  final String category, sourceName;
  final bool isVideo;
  final double height;
  final BorderRadius radius;

  const _GradientPlaceholder({
    required this.category, required this.sourceName,
    required this.isVideo, required this.height, required this.radius,
  });

  static const _colors = {
    'ai': Color(0xFF6C63FF), 'cybersecurity': Color(0xFF00C853),
    'nocode': Color(0xFFFF6D00), 'data': Color(0xFF0091EA), 'cloud': Color(0xFF00B8D4),
  };
  static const _icons = {
    'ai': '🤖', 'cybersecurity': '🔐', 'nocode': '⚡', 'data': '📊', 'cloud': '☁️',
  };

  @override
  Widget build(BuildContext context) {
    final base = _colors[category] ?? const Color(0xFF6C63FF);
    final icon = _icons[category] ?? '📄';
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: double.infinity, height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [base.withOpacity(0.6), base.withOpacity(0.15)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(icon, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Flexible(child: Text(sourceName,
              style: const TextStyle(color: Colors.white70, fontSize: 14,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
          if (isVideo) ...[
            const SizedBox(width: 14),
            const Icon(Icons.play_circle_outline, color: Colors.white60, size: 36),
          ],
        ]),
      ),
    );
  }
}

// ─── Type badge ───────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final bool isVideo;
  const _TypeBadge({required this.isVideo});
  @override
  Widget build(BuildContext context) {
    final color = isVideo ? NexColors.accent : NexColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35), width: 0.5),
      ),
      child: Text(isVideo ? '🎬 Video' : '📄 Article',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Consumed chip ────────────────────────────────────────────────────────────
class _ConsumedChip extends StatelessWidget {
  final bool isVideo;
  const _ConsumedChip({required this.isVideo});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: NexColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6)),
    child: Text(isVideo ? '✓ Watched' : '✓ Read',
        style: const TextStyle(color: NexColors.success, fontSize: 10,
            fontWeight: FontWeight.w600)),
  );
}

// ─── Native ad slot (every 3 items) ──────────────────────────────────────────
class _NativeAdSlot extends StatefulWidget {
  final NexColors c;
  const _NativeAdSlot({required this.c});
  @override
  State<_NativeAdSlot> createState() => _NativeAdSlotState();
}

class _NativeAdSlotState extends State<_NativeAdSlot> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = NativeAd(
      adUnitId: AdManager.instance.nativeAdUnitId,
      listener: NativeAdListener(
        onAdLoaded: (_) { if (mounted) setState(() => _loaded = true); },
        onAdFailedToLoad: (ad, _) { ad.dispose(); _ad = null; },
      ),
      request: const AdRequest(),
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
          style: NativeTemplateFontStyle.bold, size: 14,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: widget.c.textMuted,
          style: NativeTemplateFontStyle.normal, size: 12,
        ),
      ),
    )..load();
  }

  @override
  void dispose() { _ad?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      height: 80,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: _loaded && _ad != null
          ? AdWidget(ad: _ad!)
          : Center(child: Text('Advertisement',
              style: TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 0.5))),
    );
  }
}

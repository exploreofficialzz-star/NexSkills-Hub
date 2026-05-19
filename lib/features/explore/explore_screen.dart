import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/resource_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/rss_service.dart';
import '../../core/services/ad_manager.dart';
import '../../core/services/connectivity_service.dart';
import '../../shared/widgets/shared_widgets.dart';
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

  BannerAd? _bottomBanner;
  bool _bottomBannerLoaded = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBottomBanner());
  }

  @override
  void dispose() {
    _bottomBanner?.dispose();
    super.dispose();
  }

  Future<void> _loadBottomBanner() async {
    if (HiveService.getProgress().isPremium) return;
    final ad = AdManager.instance.createBannerAd(AdSize.banner);
    await ad.load();
    if (mounted) setState(() { _bottomBanner = ad; _bottomBannerLoaded = true; });
  }

  void _loadFromCache() {
    const allCats = ['ai', 'cybersecurity', 'nocode', 'data', 'cloud'];
    final raw = _selectedCategory == 'all'
        ? allCats.expand((cat) => HiveService.getResourcesByCategory(cat)).toList()
        : HiveService.getResourcesByCategory(_selectedCategory);
    if (mounted) {
      setState(() {
        _items = raw;
        if (raw.isNotEmpty) _loading = false;
      });
    }
  }

  Future<void> _fetchFresh() async {
    if (mounted) setState(() { _refreshing = true; _error = null; });
    try {
      await RssService.fetchAll();
      _consumedIds = HiveService.getAllConsumedIds();
      _loadFromCache();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not fetch content. Check your connection.');
    } finally {
      if (mounted) setState(() { _refreshing = false; _loading = false; });
    }
  }

  bool _isVideo(ResourceModel r) => r.type == 'video' || r.isYoutube;

  // ─── Build the display list for the current filters ───────────────────────
  List<ResourceModel> get _displayList {
    // 1. Apply category filter
    var list = _selectedCategory == 'all'
        ? _items
        : _items.where((r) => r.category == _selectedCategory).toList();

    // 2. Apply type filter
    if (_selectedType == 'video') {
      list = list.where(_isVideo).toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      return _consumedLast(list);
    }
    if (_selectedType == 'article') {
      list = list.where((r) => !_isVideo(r)).toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      return _consumedLast(list);
    }

    // 3. "All" — interleave videos and articles so both types are visible
    //    immediately without needing to scroll past a wall of one type.
    return _consumedLast(_interleave(list));
  }

  /// Interleave: 1 video → 2 articles → 1 video → 2 articles → …
  List<ResourceModel> _interleave(List<ResourceModel> items) {
    final videos = items.where(_isVideo).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final articles = items.where((r) => !_isVideo(r)).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    if (videos.isEmpty) return articles;
    if (articles.isEmpty) return videos;

    final result = <ResourceModel>[];
    int vi = 0, ai = 0;
    while (vi < videos.length || ai < articles.length) {
      if (vi < videos.length) result.add(videos[vi++]);
      if (ai < articles.length) result.add(articles[ai++]);
      if (ai < articles.length) result.add(articles[ai++]);
    }
    return result;
  }

  /// Move consumed items to the bottom, preserving their relative order.
  List<ResourceModel> _consumedLast(List<ResourceModel> items) {
    final fresh = items.where((r) => !_consumedIds.contains(r.id)).toList();
    final done  = items.where((r) =>  _consumedIds.contains(r.id)).toList();
    return [...fresh, ...done];
  }

  // ─── Open a resource ──────────────────────────────────────────────────────
  /// Videos and articles both open in ResourceViewerScreen.
  /// ResourceViewerScreen uses youtube_player_flutter for videos and
  /// flutter_inappwebview for articles — no external YouTube app needed.
  void _openResource(ResourceModel resource) {
    AdManager.instance.showInterstitial(
      onDismissed: () => _navigateTo(resource),
    );
  }

  void _navigateTo(ResourceModel resource) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResourceViewerScreen(resource: resource)),
    ).then((_) {
      // Mark as consumed only after the user returns from the viewer
      HiveService.markConsumed(resource.id);
      HiveService.markRead(resource.id);
      if (mounted) {
        setState(() {
          _consumedIds = HiveService.getAllConsumedIds();
          _loadFromCache();
        });
      }
    });
  }

  Future<void> _toggleBookmark(ResourceModel r) async {
    await HiveService.toggleBookmark(r.id);
    _loadFromCache();
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('Resets your watched/read list so all content appears fresh.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirm == true) {
      await HiveService.clearConsumedItems();
      if (mounted) setState(() { _consumedIds = {}; });
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
              if (_bottomBannerLoaded && _bottomBanner != null)
                _StickyBottomBanner(ad: _bottomBanner!, c: c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(NexColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explore',
                    style: TextStyle(color: c.textPrimary, fontSize: 28,
                        fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                Text('Fresh content from top sources',
                    style: TextStyle(color: c.textMuted, fontSize: 13)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _clearHistory,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.history_toggle_off, color: c.textMuted, size: 22),
            ),
          ),
          _refreshing
              ? SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: NexColors.primary))
              : GestureDetector(onTap: _fetchFresh,
                  child: Icon(Icons.refresh, color: c.textMuted)),
        ],
      ),
    );
  }

  Widget _buildErrorBar(NexColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: NexColors.error, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: NexColors.error, fontSize: 12))),
          GestureDetector(onTap: _fetchFresh,
              child: const Text('Retry',
                  style: TextStyle(color: NexColors.primary, fontSize: 12,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(NexColors c) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = _selectedCategory == cat.$1;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? NexColors.primary : c.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: selected ? NexColors.primary : c.border, width: 0.5),
              ),
              child: Text('${cat.$2} ${cat.$3}',
                  style: TextStyle(
                      color: selected ? Colors.white : c.textMuted,
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeFilter(NexColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: _types.map((t) {
          final selected = _selectedType == t.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedType = t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? NexColors.accent.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: selected ? NexColors.accent : c.textMuted.withOpacity(0.3)),
                ),
                child: Text(t.$2,
                    style: TextStyle(
                        color: selected ? NexColors.accent : c.textMuted,
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList(NexColors c) {
    final items = _displayList;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          Center(
            child: Column(
              children: [
                const Text('📡', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 16),
                Text('No content yet',
                    style: TextStyle(color: c.textPrimary, fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Pull down to fetch latest content',
                    style: TextStyle(color: c.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      );
    }

    final isPremium = HiveService.getProgress().isPremium;
    final withAds = <dynamic>[];
    int count = 0;
    for (final item in items) {
      withAds.add(item);
      count++;
      if (!isPremium && count % 5 == 0) withAds.add('native_ad');
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      itemCount: withAds.length,
      itemBuilder: (_, i) {
        final item = withAds[i];
        if (item == 'native_ad') return _NativeAdSlot(c: c);

        final resource = item as ResourceModel;
        final isConsumed = _consumedIds.contains(resource.id);
        final isVid = _isVideo(resource);

        return GestureDetector(
          onLongPress: isConsumed ? () async {
            await HiveService.clearConsumedItems();
            if (mounted) {
              setState(() { _consumedIds = {}; });
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('History cleared')));
            }
          } : null,
          child: _ResourceCard(
            resource: resource,
            isConsumed: isConsumed,
            isVideo: isVid,
            onTap: () => _openResource(resource),
            onBookmark: () => _toggleBookmark(resource),
          ),
        );
      },
    );
  }
}

// ─── Resource Card ────────────────────────────────────────────────────────────
class _ResourceCard extends StatelessWidget {
  final ResourceModel resource;
  final bool isConsumed;
  final bool isVideo;
  final VoidCallback onTap;
  final VoidCallback onBookmark;

  const _ResourceCard({
    required this.resource,
    required this.isConsumed,
    required this.isVideo,
    required this.onTap,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isConsumed ? 0.65 : 1.0,
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
              _Thumbnail(resource: resource, isVideo: isVideo, c: c),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(resource.title,
                        style: TextStyle(color: c.textPrimary, fontSize: 15,
                            fontWeight: FontWeight.w700, height: 1.35),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    if (resource.description != null &&
                        resource.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(resource.description!,
                          style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.4),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 10),
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
  final NexColors c;
  const _Thumbnail({required this.resource, required this.isVideo, required this.c});

  static const _catColors = {
    'ai': Color(0xFF6C63FF), 'cybersecurity': Color(0xFF00C853),
    'nocode': Color(0xFFFF6D00), 'data': Color(0xFF0091EA), 'cloud': Color(0xFF00B8D4),
  };
  static const _catIcons = {
    'ai': '🤖', 'cybersecurity': '🔐', 'nocode': '⚡', 'data': '📊', 'cloud': '☁️',
  };

  bool get _isClearbit =>
      resource.thumbnail != null && resource.thumbnail!.contains('logo.clearbit.com');

  @override
  Widget build(BuildContext context) {
    final thumb = resource.thumbnail;

    if (thumb == null) return _gradient();

    if (_isClearbit) {
      // Clearbit logos: small square logo centred on a subtle background
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Container(
          width: double.infinity, height: 80, color: c.surface,
          padding: const EdgeInsets.all(14),
          child: CachedNetworkImage(
            imageUrl: thumb, fit: BoxFit.contain,
            errorWidget: (_, __, ___) => _gradient(),
          ),
        ),
      );
    }

    // Full image (YouTube hqdefault or embedded article image)
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: CachedNetworkImage(
            imageUrl: thumb,
            memCacheWidth: 600, memCacheHeight: 340,
            width: double.infinity, height: 190, fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _gradient(),
          ),
        ),
        if (isVideo)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                color: Colors.black.withOpacity(0.32),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_filled, color: Colors.white, size: 58),
              ),
            ),
          ),
      ],
    );
  }

  Widget _gradient() {
    final base = _catColors[resource.category] ?? const Color(0xFF6C63FF);
    final icon = _catIcons[resource.category] ?? '📄';
    return Container(
      width: double.infinity, height: isVideo ? 190 : 80,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        gradient: LinearGradient(
          colors: [base.withOpacity(0.55), base.withOpacity(0.15)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: TextStyle(fontSize: isVideo ? 42 : 28)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(resource.sourceName,
                style: TextStyle(color: Colors.white.withOpacity(0.85),
                    fontSize: isVideo ? 16 : 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          if (isVideo) ...[
            const SizedBox(width: 16),
            const Icon(Icons.play_circle_outline, color: Colors.white70, size: 40),
          ],
        ],
      ),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────
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
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(isVideo ? '🎬 Video' : '📄 Article',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _ConsumedChip extends StatelessWidget {
  final bool isVideo;
  const _ConsumedChip({required this.isVideo});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: NexColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(isVideo ? '✓ Watched' : '✓ Read',
          style: const TextStyle(color: NexColors.success, fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Native Ad Slot ───────────────────────────────────────────────────────────
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
          textColor: Colors.white, backgroundColor: NexColors.primary,
          style: NativeTemplateFontStyle.bold, size: 14,
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
    );
    _ad!.load();
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
        color: c.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: _loaded && _ad != null
          ? AdWidget(ad: _ad!)
          : Center(child: Text('Advertisement',
              style: TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 0.5))),
    );
  }
}

// ─── Sticky Bottom Banner ─────────────────────────────────────────────────────
class _StickyBottomBanner extends StatelessWidget {
  final BannerAd ad;
  final NexColors c;
  const _StickyBottomBanner({required this.ad, required this.c});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        color: c.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 0.5, color: c.border),
            Padding(padding: const EdgeInsets.only(top: 4),
                child: Text('Advertisement',
                    style: TextStyle(color: c.textMuted, fontSize: 9, letterSpacing: 0.5))),
            SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

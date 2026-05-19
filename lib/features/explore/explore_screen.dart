import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/resource_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/rss_service.dart';
import '../../core/services/ad_manager.dart';
import '../../core/services/notification_service.dart';
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
    ('all',           '🌐', 'All'),
    ('ai',            '🤖', 'AI'),
    ('cybersecurity', '🔐', 'Cyber'),
    ('nocode',        '⚡', 'No-Code'),
    ('data',          '📊', 'Data'),
    ('cloud',         '☁️', 'Cloud'),
  ];

  static const _types = [
    ('all',     'All'),
    ('video',   'Videos'),
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
    final cached = _selectedCategory == 'all'
        ? allCats.expand((cat) => HiveService.getResourcesByCategory(cat)).toList()
        : HiveService.getResourcesByCategory(_selectedCategory);
    if (mounted) {
      setState(() {
        _items = _sortWithConsumedAtBottom(cached);
        if (cached.isNotEmpty) _loading = false;
      });
    }
  }

  List<ResourceModel> _sortWithConsumedAtBottom(List<ResourceModel> items) {
    final unconsumed = items.where((r) => !_consumedIds.contains(r.id)).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final consumed = items.where((r) => _consumedIds.contains(r.id)).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return [...unconsumed, ...consumed];
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

  List<ResourceModel> get _filtered {
    var list = _items;
    if (_selectedCategory != 'all') {
      list = list.where((r) => r.category == _selectedCategory).toList();
    }
    if (_selectedType != 'all') {
      // Use isVideoItem getter which checks both type field AND URL pattern
      if (_selectedType == 'video') {
        list = list.where((r) => _isVideoItem(r)).toList();
      } else {
        list = list.where((r) => !_isVideoItem(r)).toList();
      }
    }
    return list;
  }

  /// Robust video detection: checks both the stored type field AND the URL.
  /// This handles cases where type was not stored correctly in Hive.
  bool _isVideoItem(ResourceModel r) =>
      r.type == 'video' || r.isYoutube;

  void _openResource(ResourceModel resource) async {
    // For YouTube videos, try to open in YouTube app first
    if (_isVideoItem(resource)) {
      final launched = await launchUrl(
        Uri.parse(resource.url),
        mode: LaunchMode.externalApplication,
      ).catchError((_) => false);

      if (launched) {
        _markConsumedAfterDelay(resource);
        return;
      }
    }

    // Aggressive: attempt interstitial on EVERY content click.
    // 60s cooldown in AdManager prevents back-to-back ads.
    AdManager.instance.showInterstitial(
      onDismissed: () => _navigateToResource(resource),
    );
  }

  Future<void> _markConsumedAfterDelay(ResourceModel resource,
      {int seconds = 30}) async {
    await Future.delayed(Duration(seconds: seconds));
    await HiveService.markConsumed(resource.id);
    if (mounted) {
      setState(() {
        _consumedIds = HiveService.getAllConsumedIds();
        _items = _sortWithConsumedAtBottom(_items);
      });
    }
  }

  void _navigateToResource(ResourceModel resource) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResourceViewerScreen(resource: resource)),
    ).then((_) {
      HiveService.markConsumed(resource.id);
      HiveService.markRead(resource.id);
      if (mounted) {
        setState(() {
          _consumedIds = HiveService.getAllConsumedIds();
          _items = _sortWithConsumedAtBottom(_items);
        });
      }
    });
  }

  Future<void> _toggleBookmark(ResourceModel r) async {
    await HiveService.toggleBookmark(r.id);
    _loadFromCache();
  }

  Future<void> _clearConsumedHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('Resets your watched/read list so all content appears fresh again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirm == true) {
      await HiveService.clearConsumedItems();
      if (mounted) {
        setState(() {
          _consumedIds = {};
          _items = _sortWithConsumedAtBottom(_items);
        });
      }
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
              // Sticky bottom banner — free users only
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
                    style: TextStyle(
                        color: c.textPrimary, fontSize: 28,
                        fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                Text('Fresh content from top sources',
                    style: TextStyle(color: c.textMuted, fontSize: 13)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _clearConsumedHistory,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.history_toggle_off, color: c.textMuted, size: 22),
            ),
          ),
          _refreshing
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: NexColors.primary))
              : GestureDetector(onTap: _fetchFresh, child: Icon(Icons.refresh, color: c.textMuted)),
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
          GestureDetector(
            onTap: _fetchFresh,
            child: const Text('Retry',
                style: TextStyle(color: NexColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList(NexColors c) {
    final items = _filtered;
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
                    style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
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

    // Interleave native ad every 5 content items
    final withAds = <dynamic>[];
    int contentCount = 0;
    for (final item in items) {
      withAds.add(item);
      contentCount++;
      if (!isPremium && contentCount % 5 == 0) withAds.add('native_ad');
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
        final isVideo = _isVideoItem(resource);

        return GestureDetector(
          onLongPress: isConsumed ? () async {
            await HiveService.clearConsumedItems();
            if (mounted) {
              setState(() {
                _consumedIds = {};
                _items = _sortWithConsumedAtBottom(_items);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('History cleared')));
            }
          } : null,
          child: _ExploreResourceCard(
            resource: resource,
            isConsumed: isConsumed,
            isVideo: isVideo,
            onTap: () => _openResource(resource),
            onBookmark: () => _toggleBookmark(resource),
          ),
        );
      },
    );
  }
}

// ─── Resource Card ────────────────────────────────────────────────────────────
class _ExploreResourceCard extends StatelessWidget {
  final ResourceModel resource;
  final bool isConsumed;
  final bool isVideo;
  final VoidCallback onTap;
  final VoidCallback onBookmark;

  const _ExploreResourceCard({
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
              if (resource.thumbnail != null) _buildThumbnail(c),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildTypeBadge(),
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
                        style: TextStyle(
                            color: c.textPrimary, fontSize: 15,
                            fontWeight: FontWeight.w700, height: 1.35),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    if (resource.description != null && resource.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(resource.description!,
                          style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 10),
                    Text(resource.sourceName,
                        style: TextStyle(
                            color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(NexColors c) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: CachedNetworkImage(
            imageUrl: resource.thumbnail!,
            memCacheWidth: 600,
            memCacheHeight: 340,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              height: 180,
              color: c.surface,
              child: const Center(
                  child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40)),
            ),
          ),
        ),
        // Play button overlay on video thumbnails
        if (isVideo)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                color: Colors.black.withOpacity(0.3),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_filled, color: Colors.white, size: 52),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTypeBadge() {
    // Video: teal badge — Article: purple badge
    final color = isVideo ? NexColors.accent : NexColors.primary;
    final label = isVideo ? '🎬 Video' : '📄 Article';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(label,
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
        color: NexColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isVideo ? '✓ Watched' : '✓ Read',
        style: const TextStyle(
            color: NexColors.success, fontSize: 10, fontWeight: FontWeight.w600),
      ),
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
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Advertisement',
                  style: TextStyle(color: c.textMuted, fontSize: 9, letterSpacing: 0.5)),
            ),
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

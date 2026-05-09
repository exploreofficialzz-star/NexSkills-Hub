import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/resource_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/rss_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/notification_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'resource_viewer_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _selectedCategory = 'all';
  String _selectedType     = 'all';
  List<ResourceModel> _items = [];
  bool _loading    = true;
  bool _refreshing = false;
  String? _error;

  final _categories = const [
    ('all',          '🌐', 'All'),
    ('ai',           '🤖', 'AI'),
    ('cybersecurity','🔐', 'Cyber'),
    ('nocode',       '⚡', 'No-Code'),
    ('data',         '📊', 'Data'),
    ('cloud',        '☁️', 'Cloud'),
  ];

  final _types = const [
    ('all',     'All'),
    ('video',   'Videos'),
    ('article', 'Articles'),
  ];

  @override
  void initState() {
    super.initState();
    _loadFromCache();
    _fetchFresh();
  }

  void _loadFromCache() {
    final cached = _selectedCategory == 'all'
        ? ['ai', 'cybersecurity', 'nocode', 'data', 'cloud']
            .expand((cat) => HiveService.getResourcesByCategory(cat))
            .toList()
        : HiveService.getResourcesByCategory(_selectedCategory);
    cached.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    if (mounted) {
      setState(() {
        _items = cached;
        if (cached.isNotEmpty) _loading = false;
      });
    }
  }

  Future<void> _fetchFresh() async {
    if (mounted) setState(() { _refreshing = true; _error = null; });
    try {
      final before = _items.length;
      await RssService.fetchAll();
      _loadFromCache();
      final after = _items.length;
      if (after - before > 0 && mounted) {
        try { await NotificationService.showNewContentNotification('tech', after - before); }
        catch (_) {}
      }
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
      list = list.where((r) => r.type == _selectedType).toList();
    }
    return list;
  }

  void _openResource(ResourceModel resource) {
    // Pass contentId for session dedup — same article won't trigger
    // interstitial again within the same app session
    AdService.showInterstitial(
      contentId: resource.id,
      onDismissed: () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ResourceViewerScreen(resource: resource)),
          );
        }
      },
    );
  }

  Future<void> _toggleBookmark(ResourceModel r) async {
    await HiveService.toggleBookmark(r.id);
    _loadFromCache();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
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
          ],
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
          _refreshing
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: NexColors.primary))
              : GestureDetector(
                  onTap: _fetchFresh,
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
          Expanded(child: Text(_error!,
              style: const TextStyle(color: NexColors.error, fontSize: 12))),
          GestureDetector(
            onTap: _fetchFresh,
            child: const Text('Retry',
                style: TextStyle(color: NexColors.primary, fontSize: 12,
                    fontWeight: FontWeight.w700)),
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

    final progress = HiveService.getProgress();

    // ── Build list with ads every 4 content items ─────────────
    // Policy: ads clearly separated from content, no fake UI elements
    final withAds = <dynamic>[];
    int contentCount = 0;
    for (final item in items) {
      withAds.add(item);
      contentCount++;
      // Insert ad slot after every 4th content item (not every 3)
      if (!progress.isPremium && contentCount % 4 == 0) {
        withAds.add('ad');
      }
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      itemCount: withAds.length,
      itemBuilder: (_, i) {
        final item = withAds[i];
        if (item == 'ad') return _InListAdSlot(c: c);
        final resource = item as ResourceModel;
        return ResourceCard(
          resource: resource,
          onTap: () => _openResource(resource),
          onBookmark: () => _toggleBookmark(resource),
        );
      },
    );
  }
}

// ─── In-list ad slot (every 4 items) ─────────────────────────────────────────
// Uses AdaptiveBannerWidget. Clearly labelled "Advertisement" — policy compliant.
class _InListAdSlot extends StatefulWidget {
  final NexColors c;
  const _InListAdSlot({required this.c});

  @override
  State<_InListAdSlot> createState() => _InListAdSlotState();
}

class _InListAdSlotState extends State<_InListAdSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null) _load();
  }

  Future<void> _load() async {
    final ad = await AdService.createAdaptiveBanner(context);
    await ad.load();
    if (mounted) setState(() { _ad = ad; _loaded = true; });
  }

  @override
  void dispose() { _ad?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    if (!_loaded || _ad == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 60,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Center(
          child: Text('Advertisement',
              style: TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 0.5)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Advertisement',
                style: TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 0.5)),
          ),
          SizedBox(
            width: _ad!.size.width.toDouble(),
            height: _ad!.size.height.toDouble(),
            child: AdWidget(ad: _ad!),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

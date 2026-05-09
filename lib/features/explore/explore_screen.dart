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
  bool _loading    = true;  // true on first open until cache+fetch both settle
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
        // only clear loading flag if we have something to show
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
        try {
          await NotificationService.showNewContentNotification(
              'tech', after - before);
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not fetch content. Check your connection.');
      }
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
    AdService.showInterstitial(onDismissed: () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ResourceViewerScreen(resource: resource)),
        );
      }
    });
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
                        color: c.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8)),
                Text('Fresh content from top sources',
                    style: TextStyle(color: c.textMuted, fontSize: 13)),
              ],
            ),
          ),
          _refreshing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: NexColors.primary),
                )
              : GestureDetector(
                  onTap: _fetchFresh,
                  child: Icon(Icons.refresh, color: c.textMuted),
                ),
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
          Expanded(
            child: Text(_error!,
                style:
                    const TextStyle(color: NexColors.error, fontSize: 12)),
          ),
          GestureDetector(
            onTap: _fetchFresh,
            child: const Text('Retry',
                style: TextStyle(
                    color: NexColors.primary,
                    fontSize: 12,
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
            onTap: () => setState(() {
              _selectedCategory = cat.$1;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? NexColors.primary : c.card,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: selected ? NexColors.primary : c.border, width: 0.5),
              ),
              child: Text(
                '${cat.$2} ${cat.$3}',
                style: TextStyle(
                  color: selected ? Colors.white : c.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: selected
                      ? NexColors.accent.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? NexColors.accent
                        : c.textMuted.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  t.$2,
                  style: TextStyle(
                    color: selected ? NexColors.accent : c.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
      // AlwaysScrollableScrollPhysics = pull-to-refresh works even when empty
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
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18,
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
    final withAds = <dynamic>[];
    for (int i = 0; i < items.length; i++) {
      withAds.add(items[i]);
      if (!progress.isPremium && (i + 1) % 3 == 0) {
        withAds.add('ad');
      }
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      itemCount: withAds.length,
      itemBuilder: (_, i) {
        final item = withAds[i];
        if (item == 'ad') return _NativeAdPlaceholder(c: c);
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

// ─── Native ad placeholder ────────────────────────────────────────────────────
class _NativeAdPlaceholder extends StatelessWidget {
  final NexColors c;
  const _NativeAdPlaceholder({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NexColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: NexColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Sponsored',
                style: TextStyle(
                    color: NexColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          Text('Level Up Your Tech Career 🚀',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Premium removes all ads and unlocks all tracks.',
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: NexColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Go Premium — \$9.99/month',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

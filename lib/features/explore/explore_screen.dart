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
  String _selectedType = 'all';
  List<ResourceModel> _items = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  final _categories = [
    ('all', '🌐', 'All'),
    ('ai', '🤖', 'AI'),
    ('cybersecurity', '🔐', 'Cyber'),
    ('nocode', '⚡', 'No-Code'),
    ('data', '📊', 'Data'),
    ('cloud', '☁️', 'Cloud'),
  ];

  final _types = [
    ('all', 'All'),
    ('video', 'Videos'),
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
        ? HiveService.getResourcesByCategory('ai') +
            HiveService.getResourcesByCategory('cybersecurity') +
            HiveService.getResourcesByCategory('nocode') +
            HiveService.getResourcesByCategory('data') +
            HiveService.getResourcesByCategory('cloud')
        : HiveService.getResourcesByCategory(_selectedCategory);
    cached.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    if (mounted) setState(() => _items = cached);
  }

  Future<void> _fetchFresh() async {
    if (mounted) setState(() { _refreshing = true; _error = null; });

    try {
      final countBefore = _items.length;
      await RssService.fetchAll();
      _loadFromCache(); // reload from Hive after saving
      if (mounted) setState(() => _loading = false);

      final newCount = _items.length - countBefore;
      if (newCount > 0 && mounted) {
        try {
          await NotificationService.showNewContentNotification('tech', newCount);
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not fetch content. Check your connection.';
          _loading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCategoryFilter(),
            _buildTypeFilter(),
            if (_error != null) _buildError(),
            Expanded(
              child: _loading
                  ? const ShimmerList()
                  : RefreshIndicator(
                      onRefresh: _fetchFresh,
                      color: AppColors.primary,
                      backgroundColor: AppColors.card,
                      child: _buildList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explore',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8)),
                Text('Fresh content from top sources',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          if (_refreshing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
          else
            GestureDetector(
              onTap: _fetchFresh,
              child: const Icon(Icons.refresh, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: const TextStyle(
                    color: AppColors.error, fontSize: 12)),
          ),
          GestureDetector(
            onTap: _fetchFresh,
            child: const Text('Retry',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
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
                color: selected ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${cat.$2} ${cat.$3}',
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textMuted,
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

  Widget _buildTypeFilter() {
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accent.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? AppColors.accent
                        : AppColors.textMuted.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  t.$2,
                  style: TextStyle(
                    color:
                        selected ? AppColors.accent : AppColors.textMuted,
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

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('📡', style: TextStyle(fontSize: 48)),
                SizedBox(height: 16),
                Text('No content yet',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('Pull down to fetch latest content',
                    style: TextStyle(color: AppColors.textMuted)),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: withAds.length,
      itemBuilder: (_, i) {
        final item = withAds[i];
        if (item == 'ad') return const _NativeAdPlaceholder();
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

class _NativeAdPlaceholder extends StatelessWidget {
  const _NativeAdPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Sponsored',
                style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          const Text('Level Up Your Tech Career 🚀',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Premium removes all ads and unlocks all tracks.',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
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

import 'package:http/http.dart' as http;
import 'package:webfeed/webfeed.dart';
import '../constants/sources.dart';
import '../models/resource_model.dart';
import 'hive_service.dart';

class RssService {
  static Future<List<ResourceModel>> fetchCategory(String category) async {
    final sources = AppSources.byCategory(category);
    final List<ResourceModel> results = [];

    await Future.wait(sources.map((source) async {
      try {
        final items = await _fetchSource(source);
        results.addAll(items);
      } catch (_) {}
    }));

    results.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    await HiveService.saveResources(results);
    return results;
  }

  static Future<List<ResourceModel>> fetchAll() async {
    final categories = ['ai', 'cybersecurity', 'nocode', 'data', 'cloud'];
    final List<ResourceModel> all = [];
    for (final cat in categories) {
      final items = await fetchCategory(cat);
      all.addAll(items);
    }
    return all;
  }

  static Future<List<ResourceModel>> _fetchSource(ContentSource source) async {
    final response = await http.get(
      Uri.parse(source.feedUrl),
      headers: {'User-Agent': 'NexSkillsHub/1.0'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return [];

    final body = response.body;
    final List<ResourceModel> items = [];

    try {
      if (source.feedUrl.contains('youtube.com/feeds')) {
        final feed = AtomFeed.parse(body);
        for (final entry in (feed.items ?? [])) {
          if (entry.id == null || entry.title == null) continue;
          final url = entry.links?.isNotEmpty == true
              ? entry.links!.first.href ?? ''
              : '';
          if (url.isEmpty) continue;

          String? thumbnail;
          final mediaContent = entry.media?.group?.contents;
          if (mediaContent != null && mediaContent.isNotEmpty) {
            thumbnail = mediaContent.first.url;
          }
          thumbnail ??= _youtubeThumbnail(url);

          items.add(ResourceModel(
            id: entry.id!,
            title: entry.title ?? 'Untitled',
            url: url,
            category: source.category,
            type: 'video',
            sourceName: source.name,
            thumbnail: thumbnail,
            publishedAt: entry.published ?? DateTime.now(),
            description: entry.summary,
          ));
        }
      } else {
        final feed = RssFeed.parse(body);
        for (final item in (feed.items ?? [])) {
          if (item.link == null || item.title == null) continue;
          final id =
              item.guid ?? item.link ?? item.title ?? DateTime.now().toString();

          String? thumbnail;
          if (item.enclosure?.url != null) {
            thumbnail = item.enclosure!.url;
          }
          thumbnail ??= _extractImageFromContent(item.content?.value ?? '');

          items.add(ResourceModel(
            id: id,
            title: item.title!,
            url: item.link!,
            category: source.category,
            type: source.type == SourceType.podcast ? 'podcast' : 'article',
            sourceName: source.name,
            thumbnail: thumbnail,
            publishedAt: item.pubDate ?? DateTime.now(),
            description: item.description,
          ));
        }
      }
    } catch (_) {}

    return items;
  }

  static String _youtubeThumbnail(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    String id = '';
    if (uri.host.contains('youtu.be')) {
      id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    } else {
      id = uri.queryParameters['v'] ?? '';
    }
    if (id.isEmpty) return '';
    return 'https://img.youtube.com/vi/$id/mqdefault.jpg';
  }

  static String? _extractImageFromContent(String html) {
    final regex = RegExp(r'<img[^>]+src="([^"]+)"');
    final match = regex.firstMatch(html);
    return match?.group(1);
  }
}

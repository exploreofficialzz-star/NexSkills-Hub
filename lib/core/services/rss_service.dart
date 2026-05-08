import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
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
    final response = await http
        .get(
          Uri.parse(source.feedUrl),
          headers: {'User-Agent': 'NexSkillsHub/1.0'},
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) return [];

    final body = response.body;
    final List<ResourceModel> items = [];

    // dart_rss 3.x: AtomItem.published and RssItem.pubDate are both String?,
    // NOT DateTime. Parse them manually with _parseDate().
    if (source.type == SourceType.youtube) {
      final feed = AtomFeed.parse(body);
      for (final entry in feed.items) {
        final id = entry.id;
        final title = entry.title;
        if (id == null || title == null) continue;

        final url = entry.links.isNotEmpty
            ? (entry.links.first.href ?? '')
            : '';
        if (url.isEmpty) continue;

        final published = _parseDate(entry.published ?? entry.updated);
        final thumbnail = _youtubeThumbnail(url);

        items.add(ResourceModel(
          id: id,
          title: title,
          url: url,
          category: source.category,
          type: 'video',
          sourceName: source.name,
          thumbnail: thumbnail.isNotEmpty ? thumbnail : null,
          publishedAt: published,
          description: entry.summary,
        ));
      }
    } else {
      final feed = RssFeed.parse(body);
      for (final item in feed.items) {
        final link = item.link;
        final title = item.title;
        if (link == null || title == null) continue;

        final id = item.guid ?? link;
        final published = _parseDate(item.pubDate);

        String? thumbnail;
        if (item.enclosure?.url != null) {
          thumbnail = item.enclosure!.url;
        }
        thumbnail ??= _extractImageFromHtml(item.content?.value ?? '');
        thumbnail ??= _extractImageFromHtml(item.description ?? '');

        items.add(ResourceModel(
          id: id,
          title: title,
          url: link,
          category: source.category,
          type: source.type == SourceType.podcast ? 'podcast' : 'article',
          sourceName: source.name,
          thumbnail: thumbnail,
          publishedAt: published,
          description: item.description != null
              ? _stripHtml(item.description!)
              : null,
        ));
      }
    }

    return items;
  }

  // ─── Date parsing ─────────────────────────────────────────────
  // dart_rss 3.x exposes raw strings; we handle both ISO 8601 (Atom)
  // and RFC 822 (RSS) formats. Falls back to DateTime.now() so items
  // always have a valid, sortable date.
  static DateTime _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return DateTime.now();
    // ISO 8601 (Atom): "2025-05-01T12:00:00Z"
    final iso = DateTime.tryParse(raw.trim());
    if (iso != null) return iso.toLocal();
    // RFC 822 (RSS): "Mon, 05 May 2025 12:00:00 GMT"
    try {
      final cleaned = raw.trim()
          .replaceFirst(RegExp(r'^[A-Za-z]{3},\s*'), '') // strip weekday
          .replaceAll(RegExp(r'\bGMT\b'), '+0000')
          .replaceAll(RegExp(r'\bUTC\b'), '+0000')
          .replaceAll(RegExp(r'\bEST\b'), '-0500')
          .replaceAll(RegExp(r'\bEDT\b'), '-0400')
          .replaceAll(RegExp(r'\bPST\b'), '-0800')
          .replaceAll(RegExp(r'\bPDT\b'), '-0700');
      final parsed = DateTime.tryParse(cleaned);
      if (parsed != null) return parsed.toLocal();
    } catch (_) {}
    return DateTime.now();
  }

  // ─── Thumbnail helpers ────────────────────────────────────────
  static String _youtubeThumbnail(String url) {
    try {
      final uri = Uri.parse(url);
      String id = '';
      if (uri.host.contains('youtu.be')) {
        id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      } else {
        id = uri.queryParameters['v'] ?? '';
      }
      if (id.isEmpty) return '';
      return 'https://img.youtube.com/vi/$id/mqdefault.jpg';
    } catch (_) {
      return '';
    }
  }

  static String? _extractImageFromHtml(String html) {
    if (html.isEmpty) return null;
    final regex =
        RegExp(r'<img[^>]+src=["\x27]([^"\x27\s]+)["\x27]', caseSensitive: false);
    final match = regex.firstMatch(html);
    final src = match?.group(1);
    // Discard tiny tracking pixels and relative paths
    if (src == null || src.startsWith('data:') || !src.startsWith('http')) {
      return null;
    }
    return src;
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}

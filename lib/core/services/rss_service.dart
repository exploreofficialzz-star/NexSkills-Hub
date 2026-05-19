import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import '../constants/sources.dart';
import '../models/resource_model.dart';
import 'hive_service.dart';

class RssService {
  static Future<List<ResourceModel>> fetchCategory(String category) async {
    final sources = AppSources.byCategory(category);
    final results = await Future.wait(
      sources.map((source) async {
        try { return await _fetchSource(source); } catch (_) { return <ResourceModel>[]; }
      }),
      eagerError: false,
    );
    final flat = results.expand((r) => r).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    await HiveService.saveResources(flat);
    return flat;
  }

  static Future<List<ResourceModel>> fetchAll() async {
    const categories = ['ai', 'cybersecurity', 'nocode', 'data', 'cloud'];
    final results = await Future.wait(categories.map(fetchCategory), eagerError: false);
    return results.expand((r) => r).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  static Future<List<ResourceModel>> _fetchSource(ContentSource source) async {
    final response = await http
        .get(Uri.parse(source.feedUrl), headers: {'User-Agent': 'NexSkillsHub/1.0'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return [];
    return compute(_parseSource, _ParseArgs(source: source, body: response.body));
  }

  // ─── Isolate-safe parse ───────────────────────────────────────
  static List<ResourceModel> _parseSource(_ParseArgs args) {
    return args.source.type == SourceType.youtube
        ? _parseYouTubeFeed(args.source, args.body)
        : _parseRssFeed(args.source, args.body);
  }

  // ─── YouTube Atom parser (regex-based, dart_rss not used) ─────
  // YouTube's Atom format uses yt: and media: namespaces that
  // dart_rss doesn't handle. We parse directly with RegExp.
  static List<ResourceModel> _parseYouTubeFeed(
      ContentSource source, String body) {
    final items = <ResourceModel>[];

    // Each video is wrapped in <entry>...</entry>
    final entryRe = RegExp(r'<entry>(.*?)<\/entry>', dotAll: true);

    for (final m in entryRe.allMatches(body)) {
      final e = m.group(1) ?? '';

      // <yt:videoId>XXXXXXXXXXX</yt:videoId>
      final videoId = _tag(e, 'yt:videoId');
      if (videoId.isEmpty) continue;

      // <title>...</title>  (first occurrence inside the entry)
      final title = _decodeHtml(_tag(e, 'title'));
      if (title.isEmpty) continue;

      final url = 'https://www.youtube.com/watch?v=$videoId';

      // <media:thumbnail url="..." /> — prefer this over hqdefault
      final thumbMatch =
          RegExp(r'<media:thumbnail\s+url="([^"]+)"').firstMatch(e);
      final thumbnail =
          thumbMatch?.group(1) ?? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

      // <published>...</published>
      final published = _parseDate(_tag(e, 'published'));

      // <media:description>...</media:description>
      final description = _decodeHtml(_tag(e, 'media:description'));

      items.add(ResourceModel(
        id: 'yt:video:$videoId',
        title: title,
        url: url,
        category: source.category,
        type: 'video',
        sourceName: source.name,
        thumbnail: thumbnail,
        publishedAt: published,
        description: description.isNotEmpty ? description : null,
      ));
    }
    return items;
  }

  // ─── Standard RSS feed parser (articles/blogs) ────────────────
  static List<ResourceModel> _parseRssFeed(
      ContentSource source, String body) {
    final items = <ResourceModel>[];
    RssFeed feed;
    try { feed = RssFeed.parse(body); } catch (_) { return []; }

    for (final item in feed.items) {
      final link = item.link;
      final title = item.title;
      if (link == null || title == null || title.trim().isEmpty) continue;

      String? thumbnail = item.enclosure?.url;
      thumbnail ??= _extractImageFromHtml(item.content?.value ?? '');
      thumbnail ??= _extractImageFromHtml(item.description ?? '');

      items.add(ResourceModel(
        id: item.guid ?? link,
        title: title.trim(),
        url: link,
        category: source.category,
        type: source.type == SourceType.podcast ? 'podcast' : 'article',
        sourceName: source.name,
        thumbnail: thumbnail,
        publishedAt: _parseDate(item.pubDate),
        description: item.description != null ? _stripHtml(item.description!) : null,
      ));
    }
    return items;
  }

  // ─── Helpers ──────────────────────────────────────────────────

  /// Extract inner text of first matching XML tag.
  static String _tag(String xml, String tag) {
    final m = RegExp('<$tag>([\\s\\S]*?)<\\/$tag>').firstMatch(xml);
    return m?.group(1)?.trim() ?? '';
  }

  static String _decodeHtml(String t) => t
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");

  static DateTime _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return DateTime.now();
    final iso = DateTime.tryParse(raw.trim());
    if (iso != null) return iso.toLocal();
    try {
      final cleaned = raw.trim()
          .replaceFirst(RegExp(r'^[A-Za-z]{3},\s*'), '')
          .replaceAll(RegExp(r'\bGMT\b'), '+0000')
          .replaceAll(RegExp(r'\bUTC\b'), '+0000');
      final parsed = DateTime.tryParse(cleaned);
      if (parsed != null) return parsed.toLocal();
    } catch (_) {}
    return DateTime.now();
  }

  static String? _extractImageFromHtml(String html) {
    if (html.isEmpty) return null;
    final m = RegExp('<img[^>]+src="(http[^"]+)"', caseSensitive: false).firstMatch(html);
    final src = m?.group(1);
    return (src == null || src.startsWith('data:')) ? null : src;
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}

class _ParseArgs {
  final ContentSource source;
  final String body;
  const _ParseArgs({required this.source, required this.body});
}

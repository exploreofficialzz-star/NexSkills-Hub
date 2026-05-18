import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import '../constants/sources.dart';
import '../models/resource_model.dart';
import 'hive_service.dart';

class RssService {
  /// Fetch a single category's RSS feeds concurrently.
  static Future<List<ResourceModel>> fetchCategory(String category) async {
    final sources = AppSources.byCategory(category);

    // All sources in a category fetched concurrently (Section 4.2a)
    final results = await Future.wait(
      sources.map((source) async {
        try {
          return await _fetchSource(source);
        } catch (_) {
          return <ResourceModel>[];
        }
      }),
      eagerError: false,
    );

    final flat = results.expand((r) => r).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    await HiveService.saveResources(flat);
    return flat;
  }

  /// Fetch ALL categories concurrently — videos and articles interleaved
  /// in a single merged list, sorted by publication date (Section 4.2a/b).
  static Future<List<ResourceModel>> fetchAll() async {
    const categories = ['ai', 'cybersecurity', 'nocode', 'data', 'cloud'];

    // Use compute() to keep JSON parsing / RSS parsing off the UI thread
    final results = await Future.wait(
      categories.map(fetchCategory),
      eagerError: false,
    );

    final all = results.expand((r) => r).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

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

    // Offload parsing to a background isolate via compute() (Section 1.1)
    return compute(_parseSource, _ParseArgs(source: source, body: response.body));
  }

  // ─── Isolate-safe parse function ─────────────────────────────
  static List<ResourceModel> _parseSource(_ParseArgs args) {
    final source = args.source;
    final body   = args.body;
    final items  = <ResourceModel>[];

    if (source.type == SourceType.youtube) {
      final feed = AtomFeed.parse(body);
      for (final entry in feed.items) {
        final id    = entry.id;
        final title = entry.title;
        if (id == null || title == null) continue;

        final url = entry.links.isNotEmpty
            ? (entry.links.first.href ?? '')
            : '';
        if (url.isEmpty) continue;

        final published   = _parseDate(entry.published ?? entry.updated);
        final thumbnail   = _youtubeThumbnail(url);
        final videoId     = _extractYouTubeId(url);

        items.add(ResourceModel(
          id:          id,
          title:       title,
          url:         url,
          category:    source.category,
          type:        'video', // ← explicit contentType field (Section 4.2c)
          sourceName:  source.name,
          thumbnail:   thumbnail.isNotEmpty ? thumbnail : null,
          publishedAt: published,
          description: entry.summary,
        ));
      }
    } else {
      final feed = RssFeed.parse(body);
      for (final item in feed.items) {
        final link  = item.link;
        final title = item.title;
        if (link == null || title == null) continue;

        final id        = item.guid ?? link;
        final published = _parseDate(item.pubDate);

        String? thumbnail;
        if (item.enclosure?.url != null) thumbnail = item.enclosure!.url;
        thumbnail ??= _extractImageFromHtml(item.content?.value ?? '');
        thumbnail ??= _extractImageFromHtml(item.description ?? '');

        items.add(ResourceModel(
          id:          id,
          title:       title,
          url:         link,
          category:    source.category,
          type:        source.type == SourceType.podcast ? 'podcast' : 'article',
          sourceName:  source.name,
          thumbnail:   thumbnail,
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
  static DateTime _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return DateTime.now();
    final iso = DateTime.tryParse(raw.trim());
    if (iso != null) return iso.toLocal();
    try {
      final cleaned = raw
          .trim()
          .replaceFirst(RegExp(r'^[A-Za-z]{3},\s*'), '')
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
  static String _extractYouTubeId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      }
      return uri.queryParameters['v'] ?? '';
    } catch (_) {
      return '';
    }
  }

  static String _youtubeThumbnail(String url) {
    final id = _extractYouTubeId(url);
    if (id.isEmpty) return '';
    // hqdefault is 480×360 — good quality, always available (Section 4.2f)
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  static String? _extractImageFromHtml(String html) {
    if (html.isEmpty) return null;
    // Double-quoted src="https://..." — covers the vast majority of RSS HTML
    final regex = RegExp('<img[^>]+src="(http[^"]+)"', caseSensitive: false);
    final match = regex.firstMatch(html);
    final src = match?.group(1);
    if (src == null || src.startsWith('data:')) return null;
    return src;
  }

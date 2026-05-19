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

  static List<ResourceModel> _parseSource(_ParseArgs args) {
    final source = args.source;
    final body = args.body;
    final items = <ResourceModel>[];

    if (source.type == SourceType.youtube) {
      AtomFeed feed;
      try { feed = AtomFeed.parse(body); } catch (_) { return []; }

      for (final entry in feed.items) {
        final id = entry.id;
        final title = entry.title;
        if (id == null || title == null || title.trim().isEmpty) continue;

        // Try links first; fall back to entry.id ("yt:video:<videoId>")
        String url = entry.links.isNotEmpty ? (entry.links.first.href ?? '') : '';
        if (url.isEmpty) {
          final parts = id.split(':');
          if (parts.length >= 3) url = 'https://www.youtube.com/watch?v=${parts.last}';
        }
        if (url.isEmpty) continue;

        final thumbnail = _youtubeThumbnail(url);
        items.add(ResourceModel(
          id: id,
          title: title.trim(),
          url: url,
          category: source.category,
          type: 'video',
          sourceName: source.name,
          thumbnail: thumbnail.isNotEmpty ? thumbnail : null,
          publishedAt: _parseDate(entry.published ?? entry.updated),
          description: entry.summary,
        ));
      }
    } else {
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
    }
    return items;
  }

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

  static String _extractYouTubeId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      return uri.queryParameters['v'] ?? '';
    } catch (_) { return ''; }
  }

  static String _youtubeThumbnail(String url) {
    final id = _extractYouTubeId(url);
    return id.isEmpty ? '' : 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  static String? _extractImageFromHtml(String html) {
    if (html.isEmpty) return null;
    final regex = RegExp('<img[^>]+src="(http[^"]+)"', caseSensitive: false);
    final match = regex.firstMatch(html);
    final src = match?.group(1);
    return (src == null || src.startsWith('data:')) ? null : src;
  }

  static String _stripHtml(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}

class _ParseArgs {
  final ContentSource source;
  final String body;
  const _ParseArgs({required this.source, required this.body});
}

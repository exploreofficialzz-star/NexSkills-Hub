import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import '../constants/sources.dart';
import '../models/resource_model.dart';
import 'hive_service.dart';
import 'notification_service.dart';

class RssService {
  static Future<List<ResourceModel>> fetchCategory(String category) async {
    final sources = AppSources.byCategory(category);
    final results = await Future.wait(
      sources.map((source) async {
        try {
          final r = await _fetchSource(source);
          debugPrint('[RssService] ${source.name} ($category): ${r.length} items');
          return r;
        } catch (e) {
          debugPrint('[RssService] ${source.name} ($category) THREW: $e');
          return <ResourceModel>[];
        }
      }),
      eagerError: false,
    );
    final flat = results.expand((r) => r).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    final videoCount = flat.where((r) => r.type == 'video').length;
    debugPrint('[RssService] ══ $category SUMMARY: $videoCount videos + '
        '${flat.length - videoCount} articles (${flat.length} total) '
        'from ${sources.length} sources ══');

    // Identify genuinely new items BEFORE saving so we can detect first-time entries.
    final box = HiveService.resourceBox;
    final newItems = flat.where((r) => !box.containsKey(r.id)).toList();

    await HiveService.saveResources(flat);

    // Keep Hive box from growing unboundedly.
    // 150 items per category = ~750 total max, all recent.
    await HiveService.trimCategory(category, keep: 150);

    // Schedule staggered channel alerts for new YouTube videos.
    // These fire at 2 PM (not immediately) so we never spam at app open.
    if (newItems.isNotEmpty) {
      try {
        final newVideos = newItems
            .where((r) => r.type == 'video')
            .map((r) => NewVideoInfo(
                  channelName: r.sourceName,
                  videoTitle: r.title,
                  category: category,
                ))
            .toList();
        if (newVideos.isNotEmpty) {
          await NotificationService.scheduleChannelAlerts(newVideos: newVideos);
        }
      } catch (_) {}
    }

    return flat;
  }

  static Future<List<ResourceModel>> fetchAll() async {
    const categories = ['ai', 'cybersecurity', 'nocode', 'data', 'cloud'];
    final results = await Future.wait(
      categories.map(fetchCategory),
      eagerError: false,
    );
    return results.expand((r) => r).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  // Browser UA for YouTube — their Atom feeds block non-browser clients
  static const _youtubeBrowserUA =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
  static const _appUA = 'NexSkillsHub/1.0 RSS Reader';

  static Future<List<ResourceModel>> _fetchSource(ContentSource source) async {
    final isYT = source.type == SourceType.youtube;
    final headers = isYT
        ? {
            'User-Agent': _youtubeBrowserUA,
            'Accept': 'application/atom+xml, application/xml, text/xml, */*',
            'Accept-Language': 'en-US,en;q=0.9',
          }
        : {
            'User-Agent': _appUA,
            'Accept': 'application/rss+xml, application/atom+xml, */*',
          };

    final response = await http
        .get(Uri.parse(source.feedUrl), headers: headers)
        .timeout(const Duration(seconds: 25));

    // Accept 200 and common redirect targets (some feeds return 301→200)
    if (response.statusCode < 200 || response.statusCode >= 400) {
      debugPrint('[RssService] ${source.name}: HTTP ${response.statusCode} '
          'for ${source.feedUrl}');
      return [];
    }

    // Parse synchronously on the main isolate.
    // compute() was causing silent failures: any exception inside the isolate
    // was being swallowed by the outer try-catch, returning [] with no log.
    // Network I/O is the real bottleneck; parsing 15-20 entries takes < 2ms.
    if (source.type == SourceType.youtube) {
      return _parseYouTubeFeed(source, response.body);
    } else {
      return _parseRssFeed(source, response.body);
    }
  }

  // ─── YouTube — regex parser (no dart_rss) ────────────────────
  // dart_rss does NOT handle YouTube's yt: / media: namespaces.
  // We parse the Atom XML directly with RegExp targeting:
  //   <yt:videoId>, <title>, <published>, <media:thumbnail>, <media:description>
  static List<ResourceModel> _parseYouTubeFeed(ContentSource source, String body) {
    final items = <ResourceModel>[];

    // Each video is enclosed in <entry>...</entry>
    final entryRe = RegExp(r'<entry>([\s\S]*?)</entry>');
    final matches = entryRe.allMatches(body).toList();
    if (matches.isEmpty) {
      // Zero <entry> blocks usually means: wrong/dead channel ID, or
      // YouTube returned an error page instead of the Atom feed.
      debugPrint('[RssService] ${source.name}: 0 <entry> blocks in response '
          '(${body.length} bytes) — check channel_id in feedUrl');
    }

    for (final m in matches) {
      try {
        final e = m.group(1) ?? '';

        final videoId = _innerText(e, 'yt:videoId');
        if (videoId.isEmpty) continue;

        final rawTitle = _innerText(e, 'title');
        final title = _decodeHtml(rawTitle);
        if (title.isEmpty) continue;

        final url = 'https://www.youtube.com/watch?v=$videoId';

        // Prefer media:thumbnail from feed; fall back to hqdefault
        final thumbMatch = RegExp(r'<media:thumbnail\s[^>]*url="([^"]+)"').firstMatch(e);
        final thumbnail = thumbMatch?.group(1)
            ?? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

        final published = _parseDate(_innerText(e, 'published'));
        final rawDesc = _innerText(e, 'media:description');
        final description = _decodeHtml(rawDesc);

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
      } catch (e) {
        debugPrint('[RssService] ${source.name}: entry parse error: $e');
        continue; // Skip malformed entries
      }
    }
    return items;
  }

  // ─── RSS — standard articles / blogs ─────────────────────────
  static List<ResourceModel> _parseRssFeed(ContentSource source, String body) {
    final items = <ResourceModel>[];
    RssFeed feed;
    try {
      feed = RssFeed.parse(body);
    } catch (_) {
      return [];
    }

    // Raw <item>...</item> blocks — used ONLY to recover Media RSS
    // thumbnail tags (<media:thumbnail>, <media:content>) that dart_rss's
    // structured RssItem doesn't surface directly. Many enterprise blog
    // platforms (Azure Blog, AWS Blog, etc. — this is exactly what was
    // missing thumbnails) publish a featured image via these tags,
    // separate from any <img> inside the body HTML.
    // Paired to each parsed item by matching <link>/<guid> text inside the
    // raw block (NOT by position — item order/count can differ if any
    // entries fail to parse structurally).
    final rawBlocks = RegExp(r'<item>([\s\S]*?)</item>', caseSensitive: false)
        .allMatches(body)
        .map((m) => m.group(1) ?? '')
        .toList();

    String? mediaThumbFor(String? link, String? guid) {
      if (link == null && guid == null) return null;
      for (final block in rawBlocks) {
        if ((link != null && block.contains(link)) ||
            (guid != null && block.contains(guid))) {
          final m = RegExp(
            r'<media:(?:thumbnail|content)[^>]+url="([^"]+)"',
            caseSensitive: false,
          ).firstMatch(block);
          if (m != null) return m.group(1);
        }
      }
      return null;
    }

    for (final item in feed.items) {
      try {
        final link = item.link;
        final title = item.title;
        if (link == null || title == null || title.trim().isEmpty) continue;

        // Thumbnail priority:
        // 1. RSS enclosure (podcast / media)
        // 2. Media RSS <media:thumbnail>/<media:content> — enterprise blogs
        // 3. <img> inside content:encoded or description HTML
        // 4. null → _GradientPlaceholder shown in the UI
        String? thumbnail = item.enclosure?.url;
        thumbnail ??= mediaThumbFor(link, item.guid);
        thumbnail ??= _extractImg(item.content?.value ?? '');
        thumbnail ??= _extractImg(item.description ?? '');

        items.add(ResourceModel(
          id: item.guid ?? link,
          title: title.trim(),
          url: link,
          category: source.category,
          type: source.type == SourceType.podcast ? 'podcast' : 'article',
          sourceName: source.name,
          thumbnail: thumbnail,
          publishedAt: _parseDate(item.pubDate),
          description: item.description != null
              ? _stripHtml(item.description!)
              : null,
        ));
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  // ─── Helpers ──────────────────────────────────────────────────

  /// Extract the inner text of the FIRST matching XML tag (case-sensitive).
  static String _innerText(String xml, String tag) {
    final re = RegExp('<$tag>([\\s\\S]*?)</$tag>');
    return re.firstMatch(xml)?.group(1)?.trim() ?? '';
  }

  static String _decodeHtml(String t) => t
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ');

  static String? _extractImg(String html) {
    if (html.isEmpty) return null;
    // Accept both double- and single-quoted src attributes
    final m = RegExp(
      r'''<img[^>]+src=["'](https?://[^"'\s>]+)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    final src = m?.group(1);
    if (src == null || src.startsWith('data:')) return null;
    // Skip common 1×1 tracking pixels
    if (src.contains('1x1') ||
        src.contains('pixel') ||
        src.contains('tracking') ||
        src.contains('beacon')) return null;
    return src;
  }

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

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}

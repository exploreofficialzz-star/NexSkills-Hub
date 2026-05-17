enum SourceType { youtube, blog, podcast }

class ContentSource {
  final String name;
  final SourceType type;
  final String feedUrl;
  final String category;
  final String icon;

  const ContentSource({
    required this.name,
    required this.type,
    required this.feedUrl,
    required this.category,
    required this.icon,
  });
}

class AppSources {
  static const List<ContentSource> all = [

    // ─── AI — YouTube (embed-friendly channels only) ───────────
    ContentSource(
      name: 'IBM Technology',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCKWaEZ-_VweaEx1j62do_vQ',
      category: 'ai', icon: '🤖',
    ),
    ContentSource(
      name: '3Blue1Brown',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCYO_jab_esuFRV4b17AJtAw',
      category: 'ai', icon: '🤖',
    ),
    ContentSource(
      name: 'Fireship',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCsBjURrPoezykLs9EqgamOA',
      category: 'ai', icon: '🤖',
    ),
    ContentSource(
      name: 'Andrej Karpathy',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCXUPKJO5MBESSY8m-A-2YOQA',
      category: 'ai', icon: '🤖',
    ),

    // ─── AI — Blogs ────────────────────────────────────────────
    ContentSource(
      name: 'OpenAI Blog',
      type: SourceType.blog,
      feedUrl: 'https://openai.com/news/rss.xml',
      category: 'ai', icon: '📝',
    ),
    ContentSource(
      name: 'DeepLearning.AI',
      type: SourceType.blog,
      feedUrl: 'https://www.deeplearning.ai/the-batch/feed/',
      category: 'ai', icon: '📝',
    ),
    ContentSource(
      name: 'Towards Data Science',
      type: SourceType.blog,
      feedUrl: 'https://towardsdatascience.com/feed',
      category: 'ai', icon: '📝',
    ),

    // ─── CYBERSECURITY — YouTube ───────────────────────────────
    ContentSource(
      name: 'IBM Technology',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCKWaEZ-_VweaEx1j62do_vQ',
      category: 'cybersecurity', icon: '🔐',
    ),
    ContentSource(
      name: 'NetworkChuck',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC9x0AN7BWHpCDHSm9NiJFJQ',
      category: 'cybersecurity', icon: '🔐',
    ),

    // ─── CYBERSECURITY — Blogs ─────────────────────────────────
    ContentSource(
      name: 'Krebs on Security',
      type: SourceType.blog,
      feedUrl: 'https://krebsonsecurity.com/feed/',
      category: 'cybersecurity', icon: '📝',
    ),
    ContentSource(
      name: 'The Hacker News',
      type: SourceType.blog,
      feedUrl: 'https://feeds.feedburner.com/TheHackersNews',
      category: 'cybersecurity', icon: '📝',
    ),
    ContentSource(
      name: 'Dark Reading',
      type: SourceType.blog,
      feedUrl: 'https://www.darkreading.com/rss.xml',
      category: 'cybersecurity', icon: '📝',
    ),

    // ─── NO-CODE — YouTube ─────────────────────────────────────
    ContentSource(
      name: 'Fireship',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCsBjURrPoezykLs9EqgamOA',
      category: 'nocode', icon: '⚡',
    ),
    ContentSource(
      name: 'Traversy Media',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC29ju8bIPH5as8OGnQzwJyA',
      category: 'nocode', icon: '⚡',
    ),
    ContentSource(
      name: 'IBM Technology',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCKWaEZ-_VweaEx1j62do_vQ',
      category: 'nocode', icon: '⚡',
    ),

    // ─── NO-CODE — Blogs ───────────────────────────────────────
    ContentSource(
      name: 'Zapier Blog',
      type: SourceType.blog,
      feedUrl: 'https://zapier.com/blog/feeds/latest/',
      category: 'nocode', icon: '📝',
    ),
    ContentSource(
      name: 'Webflow Blog',
      type: SourceType.blog,
      feedUrl: 'https://webflow.com/blog/rss.xml',
      category: 'nocode', icon: '📝',
    ),

    // ─── DATA — YouTube ────────────────────────────────────────
    ContentSource(
      name: 'StatQuest',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCtYLUTtgS3k1Fg4y5tAhLbw',
      category: 'data', icon: '📊',
    ),
    ContentSource(
      name: 'Fireship',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCsBjURrPoezykLs9EqgamOA',
      category: 'data', icon: '📊',
    ),
    ContentSource(
      name: 'Traversy Media',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC29ju8bIPH5as8OGnQzwJyA',
      category: 'data', icon: '📊',
    ),

    // ─── DATA — Blogs ──────────────────────────────────────────
    ContentSource(
      name: 'Towards AI',
      type: SourceType.blog,
      feedUrl: 'https://towardsai.net/feed',
      category: 'data', icon: '📝',
    ),
    ContentSource(
      name: 'Analytics Vidhya',
      type: SourceType.blog,
      feedUrl: 'https://www.analyticsvidhya.com/feed/',
      category: 'data', icon: '📝',
    ),

    // ─── CLOUD — YouTube ───────────────────────────────────────
    ContentSource(
      name: 'IBM Technology',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCKWaEZ-_VweaEx1j62do_vQ',
      category: 'cloud', icon: '☁️',
    ),
    ContentSource(
      name: 'Fireship',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCsBjURrPoezykLs9EqgamOA',
      category: 'cloud', icon: '☁️',
    ),
    ContentSource(
      name: 'NetworkChuck',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC9x0AN7BWHpCDHSm9NiJFJQ',
      category: 'cloud', icon: '☁️',
    ),

    // ─── CLOUD — Blogs ─────────────────────────────────────────
    ContentSource(
      name: 'AWS Blog',
      type: SourceType.blog,
      feedUrl: 'https://aws.amazon.com/blogs/aws/feed/',
      category: 'cloud', icon: '📝',
    ),
    ContentSource(
      name: 'Google Cloud Blog',
      type: SourceType.blog,
      feedUrl: 'https://cloudblog.withgoogle.com/rss/',
      category: 'cloud', icon: '📝',
    ),
    ContentSource(
      name: 'Azure DevOps Blog',
      type: SourceType.blog,
      feedUrl: 'https://devblogs.microsoft.com/devops/feed/',
      category: 'cloud', icon: '📝',
    ),
  ];

  static List<ContentSource> byCategory(String category) =>
      all.where((s) => s.category == category).toList();
}

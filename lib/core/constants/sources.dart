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

    // ══════════════════════════════════════════════════════════
    // AI
    // Each channel appears in EXACTLY ONE category to prevent
    // Hive key collisions (id = 'yt:video:$videoId' is global).
    // ══════════════════════════════════════════════════════════

    ContentSource(
      name: 'Fireship',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCsBjURrPoezykLs9EqgamOA',
      category: 'ai', icon: '🤖',
    ),
    ContentSource(
      name: '3Blue1Brown',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCYO_jab_esuFRV4b17AJtAw',
      category: 'ai', icon: '🤖',
    ),
    ContentSource(
      name: 'Andrej Karpathy',
      type: SourceType.youtube,
      // Verified via web search — the old ID (UCH-kyQ9Q-6yS1XcNj8nNPPA) pointed
      // at a channel that doesn't exist / returns no feed, so this source
      // silently contributed zero videos to the AI category on every fetch.
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCDklgnaowWTNnL2y8V_nAEA',
      category: 'ai', icon: '🤖',
    ),
    ContentSource(
      name: 'IBM Technology',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCKWaEZ-_VweaEx1j62do_vQ',
      category: 'ai', icon: '🤖',
    ),
    ContentSource(
      name: 'Lex Fridman',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCSHZKyawb77ixDdsGog4iWA',
      category: 'ai', icon: '🤖',
    ),

    ContentSource(
      name: 'OpenAI Blog',
      type: SourceType.blog,
      feedUrl: 'https://openai.com/blog/rss.xml',
      category: 'ai', icon: '📝',
    ),
    ContentSource(
      name: 'Anthropic Blog',
      type: SourceType.blog,
      feedUrl: 'https://www.anthropic.com/news/rss.xml',
      category: 'ai', icon: '📝',
    ),
    ContentSource(
      name: 'Google AI Blog',
      type: SourceType.blog,
      feedUrl: 'https://blog.google/technology/ai/rss/',
      category: 'ai', icon: '📝',
    ),
    ContentSource(
      name: 'The Batch (DeepLearning.AI)',
      type: SourceType.blog,
      feedUrl: 'https://www.deeplearning.ai/the-batch/feed/',
      category: 'ai', icon: '📝',
    ),

    // ══════════════════════════════════════════════════════════
    // CYBERSECURITY
    // ══════════════════════════════════════════════════════════

    ContentSource(
      name: 'NetworkChuck',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC9x0AN7BWHpCDHSm9NiJFJQ',
      category: 'cybersecurity', icon: '🔐',
    ),
    ContentSource(
      name: 'John Hammond',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCVeW9qkBjo3zosnqUbG7CFw',
      category: 'cybersecurity', icon: '🔐',
    ),
    ContentSource(
      name: 'David Bombal',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCP7WmQ_U4GB3K51Od9QvM0w',
      category: 'cybersecurity', icon: '🔐',
    ),

    ContentSource(
      name: 'The Hacker News',
      type: SourceType.blog,
      feedUrl: 'https://feeds.feedburner.com/TheHackersNews',
      category: 'cybersecurity', icon: '📝',
    ),
    ContentSource(
      name: 'Krebs on Security',
      type: SourceType.blog,
      feedUrl: 'https://krebsonsecurity.com/feed/',
      category: 'cybersecurity', icon: '📝',
    ),
    ContentSource(
      name: 'Dark Reading',
      type: SourceType.blog,
      feedUrl: 'https://www.darkreading.com/rss.xml',
      category: 'cybersecurity', icon: '📝',
    ),
    ContentSource(
      name: 'SANS ISC',
      type: SourceType.blog,
      feedUrl: 'https://isc.sans.edu/rssfeed.xml',
      category: 'cybersecurity', icon: '📝',
    ),

    // ══════════════════════════════════════════════════════════
    // NO-CODE / WEB
    // ══════════════════════════════════════════════════════════

    ContentSource(
      name: 'Traversy Media',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC29ju8bIPH5as8OGnQzwJyA',
      category: 'nocode', icon: '⚡',
    ),
    ContentSource(
      name: 'Kevin Powell',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCJZv4d5rbIKd4QHMPkcABSA',
      category: 'nocode', icon: '⚡',
    ),

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
    ContentSource(
      name: 'CSS-Tricks',
      type: SourceType.blog,
      feedUrl: 'https://css-tricks.com/feed/',
      category: 'nocode', icon: '📝',
    ),

    // ══════════════════════════════════════════════════════════
    // DATA
    // ══════════════════════════════════════════════════════════

    ContentSource(
      name: 'StatQuest',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCtYLUTtgS3k1Fg4y5tAhLbw',
      category: 'data', icon: '📊',
    ),
    ContentSource(
      name: 'Tech With Tim',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC4JX40jDee_tINbkjycV4Sg',
      category: 'data', icon: '📊',
    ),

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
    ContentSource(
      name: 'Data Science Weekly',
      type: SourceType.blog,
      feedUrl: 'https://www.datascienceweekly.org/articles/rss.xml',
      category: 'data', icon: '📝',
    ),

    // ══════════════════════════════════════════════════════════
    // CLOUD / DEVOPS
    // ══════════════════════════════════════════════════════════

    ContentSource(
      name: 'TechWorld with Nana',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCdngmbVKX1Tgre699-XLlUA',
      category: 'cloud', icon: '☁️',
    ),
    ContentSource(
      name: 'GitHub',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC7c3Kb6jYCRj4JOHHZTxKsA',
      category: 'cloud', icon: '☁️',
    ),

    ContentSource(
      name: 'Google Cloud Blog',
      type: SourceType.blog,
      feedUrl: 'https://cloudblog.withgoogle.com/rss/',
      category: 'cloud', icon: '📝',
    ),
    ContentSource(
      name: 'AWS Blog',
      type: SourceType.blog,
      feedUrl: 'https://aws.amazon.com/blogs/aws/feed/',
      category: 'cloud', icon: '📝',
    ),
    ContentSource(
      name: 'Azure Blog',
      type: SourceType.blog,
      feedUrl: 'https://azure.microsoft.com/en-us/blog/feed/',
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

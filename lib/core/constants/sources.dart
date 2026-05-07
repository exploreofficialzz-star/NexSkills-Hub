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
    // ─── AI & PROMPT ENGINEERING ───────────────────────────────
    ContentSource(
      name: 'Andrej Karpathy',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCXUPKJO5MBESSY8m-A-2YOQA',
      category: 'ai',
      icon: '🤖',
    ),
    ContentSource(
      name: 'IBM Technology',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCKWaEZ-_VweaEx1j62do_vQ',
      category: 'ai',
      icon: '🤖',
    ),
    ContentSource(
      name: 'Fireship',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCsBjURrPoezykLs9EqgamOA',
      category: 'ai',
      icon: '🤖',
    ),
    ContentSource(
      name: '3Blue1Brown',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCYO_jab_esuFRV4b17AJtAw',
      category: 'ai',
      icon: '🤖',
    ),
    ContentSource(
      name: 'Towards Data Science',
      type: SourceType.blog,
      feedUrl: 'https://towardsdatascience.com/feed',
      category: 'ai',
      icon: '📝',
    ),
    ContentSource(
      name: 'The Batch - DeepLearning.AI',
      type: SourceType.blog,
      feedUrl: 'https://www.deeplearning.ai/the-batch/feed/',
      category: 'ai',
      icon: '📝',
    ),

    // ─── CYBERSECURITY ─────────────────────────────────────────
    ContentSource(
      name: 'NetworkChuck',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC9x0AN7BWHpCDHSm9NiJFJQ',
      category: 'cybersecurity',
      icon: '🔐',
    ),
    ContentSource(
      name: 'John Hammond',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCVeW9qkBjo3zosnqUbG7CFw',
      category: 'cybersecurity',
      icon: '🔐',
    ),
    ContentSource(
      name: 'The Cyber Mentor',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC0ArlFuFYMpEewyRBzdLHiw',
      category: 'cybersecurity',
      icon: '🔐',
    ),
    ContentSource(
      name: 'Krebs on Security',
      type: SourceType.blog,
      feedUrl: 'https://krebsonsecurity.com/feed/',
      category: 'cybersecurity',
      icon: '📝',
    ),
    ContentSource(
      name: 'The Hacker News',
      type: SourceType.blog,
      feedUrl: 'https://feeds.feedburner.com/TheHackersNews',
      category: 'cybersecurity',
      icon: '📝',
    ),

    // ─── NO-CODE / LOW-CODE ────────────────────────────────────
    ContentSource(
      name: 'Bubble Official',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCBDDRuoU9bFNGGaW5ZPsHPQ',
      category: 'nocode',
      icon: '⚡',
    ),
    ContentSource(
      name: 'Webflow',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCELSb-IYi_d5rOwRR1QBPWQ',
      category: 'nocode',
      icon: '⚡',
    ),
    ContentSource(
      name: 'Kevin Stratvert',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCfMGkOABmAgWLpjaqbWDR5w',
      category: 'nocode',
      icon: '⚡',
    ),
    ContentSource(
      name: 'No Code MBA Blog',
      type: SourceType.blog,
      feedUrl: 'https://www.nocode.mba/rss.xml',
      category: 'nocode',
      icon: '📝',
    ),

    // ─── DATA & ANALYTICS ──────────────────────────────────────
    ContentSource(
      name: 'Alex The Analyst',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UC7cs8q-gJRlGwj4A8OmCmXg',
      category: 'data',
      icon: '📊',
    ),
    ContentSource(
      name: 'StatQuest',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCtYLUTtgS3k1Fg4y5tAhLbw',
      category: 'data',
      icon: '📊',
    ),
    ContentSource(
      name: 'Luke Barousse',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCLLw7jmFsvfIVaUFsLs8mlQ',
      category: 'data',
      icon: '📊',
    ),
    ContentSource(
      name: 'Analytics Vidhya',
      type: SourceType.blog,
      feedUrl: 'https://www.analyticsvidhya.com/feed/',
      category: 'data',
      icon: '📝',
    ),

    // ─── CLOUD & DEVOPS ────────────────────────────────────────
    ContentSource(
      name: 'TechWorld with Nana',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCdngmbVKX1Tgre699-XLlUA',
      category: 'cloud',
      icon: '☁️',
    ),
    ContentSource(
      name: 'AWS Events',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCd6MoB9NC6uYN2grvUNT-Zg',
      category: 'cloud',
      icon: '☁️',
    ),
    ContentSource(
      name: 'Google Cloud Tech',
      type: SourceType.youtube,
      feedUrl: 'https://www.youtube.com/feeds/videos.xml?channel_id=UCJS9pqu9BzkAMNTmzNMNhvg',
      category: 'cloud',
      icon: '☁️',
    ),
    ContentSource(
      name: 'AWS Blog',
      type: SourceType.blog,
      feedUrl: 'https://aws.amazon.com/blogs/aws/feed/',
      category: 'cloud',
      icon: '📝',
    ),
    ContentSource(
      name: 'Google Cloud Blog',
      type: SourceType.blog,
      feedUrl: 'https://cloudblog.withgoogle.com/rss/',
      category: 'cloud',
      icon: '📝',
    ),
  ];

  static List<ContentSource> byCategory(String category) =>
      all.where((s) => s.category == category).toList();
}

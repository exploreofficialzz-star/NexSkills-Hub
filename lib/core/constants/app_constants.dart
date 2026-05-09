import 'package:flutter/material.dart';

// ─── Theme-aware color extension ─────────────────────────────────────────────
// Usage: context.colors.primary  (adapts to dark/light automatically)

class NexColors extends ThemeExtension<NexColors> {
  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color navBackground;
  final Color navBorder;

  // Brand colors — same in both themes
  static const primary      = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFF9D97FF);
  static const accent       = Color(0xFF00D4AA);
  static const accentOrange = Color(0xFFFF6B35);
  static const success      = Color(0xFF4CAF50);
  static const warning      = Color(0xFFFFB74D);
  static const error        = Color(0xFFEF5350);
  static const gold         = Color(0xFFFFD700);
  static const locked       = Color(0xFF2A3050);

  // Category colours
  static const categoryAI      = Color(0xFF6C63FF);
  static const categoryCyber   = Color(0xFF00D4AA);
  static const categoryNoCode  = Color(0xFFFF6B35);
  static const categoryData    = Color(0xFF4FC3F7);
  static const categoryCloud   = Color(0xFFAB47BC);

  const NexColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.navBackground,
    required this.navBorder,
  });

  static const dark = NexColors(
    background:    Color(0xFF0A0E1A),
    surface:       Color(0xFF141828),
    card:          Color(0xFF1E2438),
    border:        Color(0xFF252B42),
    textPrimary:   Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0B8D4),
    textMuted:     Color(0xFF6B7494),
    navBackground: Color(0xFF141828),
    navBorder:     Color(0xFF252B42),
  );

  static const light = NexColors(
    background:    Color(0xFFF4F5FA),
    surface:       Color(0xFFFFFFFF),
    card:          Color(0xFFFFFFFF),
    border:        Color(0xFFE4E7F0),
    textPrimary:   Color(0xFF0D1117),
    textSecondary: Color(0xFF4A5068),
    textMuted:     Color(0xFF9AA0B8),
    navBackground: Color(0xFFFFFFFF),
    navBorder:     Color(0xFFE4E7F0),
  );

  @override
  NexColors copyWith({
    Color? background, Color? surface, Color? card, Color? border,
    Color? textPrimary, Color? textSecondary, Color? textMuted,
    Color? navBackground, Color? navBorder,
  }) => NexColors(
    background:    background    ?? this.background,
    surface:       surface       ?? this.surface,
    card:          card          ?? this.card,
    border:        border        ?? this.border,
    textPrimary:   textPrimary   ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted:     textMuted     ?? this.textMuted,
    navBackground: navBackground ?? this.navBackground,
    navBorder:     navBorder     ?? this.navBorder,
  );

  @override
  NexColors lerp(NexColors? other, double t) {
    if (other == null) return this;
    return NexColors(
      background:    Color.lerp(background,    other.background,    t)!,
      surface:       Color.lerp(surface,       other.surface,       t)!,
      card:          Color.lerp(card,          other.card,          t)!,
      border:        Color.lerp(border,        other.border,        t)!,
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted:     Color.lerp(textMuted,     other.textMuted,     t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      navBorder:     Color.lerp(navBorder,     other.navBorder,     t)!,
    );
  }
}

// Convenience extension — use context.colors anywhere
extension NexColorsX on BuildContext {
  NexColors get colors =>
      Theme.of(this).extension<NexColors>() ?? NexColors.dark;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ─── Legacy static AppColors (for files not yet migrated) ────────────────────
// Points to dark palette constants so existing code compiles unchanged.
class AppColors {
  static const background    = Color(0xFF0A0E1A);
  static const surface       = Color(0xFF141828);
  static const card          = Color(0xFF1E2438);
  static const primary       = NexColors.primary;
  static const primaryLight  = NexColors.primaryLight;
  static const accent        = NexColors.accent;
  static const accentOrange  = NexColors.accentOrange;
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B8D4);
  static const textMuted     = Color(0xFF6B7494);
  static const success       = NexColors.success;
  static const warning       = NexColors.warning;
  static const error         = NexColors.error;
  static const locked        = NexColors.locked;
  static const gold          = NexColors.gold;
  static const categoryAI    = NexColors.categoryAI;
  static const categoryCyber = NexColors.categoryCyber;
  static const categoryNoCode= NexColors.categoryNoCode;
  static const categoryData  = NexColors.categoryData;
  static const categoryCloud = NexColors.categoryCloud;
}

// ─── Strings ─────────────────────────────────────────────────────────────────
class AppStrings {
  static const appName          = 'NexSkills Hub';
  static const companyName      = 'chAs Tech Group';
  static const tagline          = 'Your daily tech career journey';
  static const tabToday         = 'Today';
  static const tabPaths         = 'My Path';
  static const tabExplore       = 'Explore';
  static const tabProgress      = 'Progress';
  static const premiumMonthly   = '\$9.99/month';
  static const premiumYearly    = '\$59.99/year';
  static const premiumMonthlyId = 'nexskills_premium_monthly';
  static const premiumYearlyId  = 'nexskills_premium_yearly';
}

// ─── Ad constants ─────────────────────────────────────────────────────────────
class AdConstants {
  // ⚠️  Replace with real AdMob IDs before release
  static const androidBannerId       = 'ca-app-pub-3940256099942544/6300978111';
  static const androidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const androidRewardedId     = 'ca-app-pub-3940256099942544/5224354917';
  static const androidNativeId       = 'ca-app-pub-3940256099942544/2247696110';
  static const iosBannerId           = 'ca-app-pub-3940256099942544/2934735716';
  static const iosInterstitialId     = 'ca-app-pub-3940256099942544/4411468910';
  static const iosRewardedId         = 'ca-app-pub-3940256099942544/1712485313';
  static const iosNativeId           = 'ca-app-pub-3940256099942544/3986624511';

  // Google policy: interstitials must not appear more often than once per 60s
  // We use 90s to stay comfortably within policy with a safety margin.
  static const interstitialCooldownSeconds = 90;

  // Max banner ad instances alive at the same time
  static const maxLiveBanners = 2;
}

// ─── Categories ───────────────────────────────────────────────────────────────
class AppCategories {
  static const List<CategoryMeta> all = [
    CategoryMeta(id: 'ai',           title: 'AI & Prompt Engineering', icon: '🤖', color: NexColors.categoryAI,     description: 'Master AI tools, LLMs and prompt engineering'),
    CategoryMeta(id: 'cybersecurity',title: 'Cybersecurity',           icon: '🔐', color: NexColors.categoryCyber,  description: 'Ethical hacking, networks and security'),
    CategoryMeta(id: 'nocode',       title: 'No-Code / Low-Code',      icon: '⚡', color: NexColors.categoryNoCode, description: 'Build powerful apps without writing code'),
    CategoryMeta(id: 'data',         title: 'Data & Analytics',        icon: '📊', color: NexColors.categoryData,   description: 'SQL, Python, visualization and data thinking'),
    CategoryMeta(id: 'cloud',        title: 'Cloud & DevOps',          icon: '☁️', color: NexColors.categoryCloud,  description: 'AWS, GCP, Azure and DevOps practices'),
  ];

  static CategoryMeta? byId(String id) {
    try { return all.firstWhere((c) => c.id == id); } catch (_) { return null; }
  }
}

class CategoryMeta {
  final String id, title, icon, description;
  final Color color;
  const CategoryMeta({
    required this.id, required this.title, required this.icon,
    required this.color, required this.description,
  });
}

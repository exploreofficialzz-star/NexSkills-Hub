import 'package:flutter/material.dart';

// ─── Theme-aware color extension ─────────────────────────────────────────────
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
  final Color progressTrack;

  static const primary       = Color(0xFF6C63FF);
  static const primaryLight  = Color(0xFF9D97FF);
  static const accent        = Color(0xFF00D4AA);
  static const accentOrange  = Color(0xFFFF6B35);
  static const success       = Color(0xFF4CAF50);
  static const warning       = Color(0xFFFFB74D);
  static const error         = Color(0xFFEF5350);
  static const gold          = Color(0xFFFFD700);
  static const locked        = Color(0xFF1A1A1A);
  static const categoryAI    = Color(0xFF6C63FF);
  static const categoryCyber = Color(0xFF00D4AA);
  static const categoryNoCode= Color(0xFFFF6B35);
  static const categoryData  = Color(0xFF4FC3F7);
  static const categoryCloud = Color(0xFFAB47BC);

  const NexColors({
    required this.background, required this.surface, required this.card,
    required this.border, required this.textPrimary, required this.textSecondary,
    required this.textMuted, required this.navBackground, required this.navBorder,
    required this.progressTrack,
  });

  static const dark = NexColors(
    background:    Color(0xFF080808),
    surface:       Color(0xFF121212),
    card:          Color(0xFF1C1C1C),
    border:        Color(0xFF2A2A2A),
    textPrimary:   Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0B0B0),
    textMuted:     Color(0xFF666666),
    navBackground: Color(0xFF111111),
    navBorder:     Color(0xFF2A2A2A),
    progressTrack: Color(0xFF2A2A2A),
  );

  static const light = NexColors(
    background:    Color(0xFFF5F5F5),
    surface:       Color(0xFFFFFFFF),
    card:          Color(0xFFFFFFFF),
    border:        Color(0xFFE8E8E8),
    textPrimary:   Color(0xFF0D0D0D),
    textSecondary: Color(0xFF4A4A4A),
    textMuted:     Color(0xFF9A9A9A),
    navBackground: Color(0xFFFFFFFF),
    navBorder:     Color(0xFFE8E8E8),
    progressTrack: Color(0xFFEEEEEE),
  );

  @override
  NexColors copyWith({
    Color? background, Color? surface, Color? card, Color? border,
    Color? textPrimary, Color? textSecondary, Color? textMuted,
    Color? navBackground, Color? navBorder, Color? progressTrack,
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
    progressTrack: progressTrack ?? this.progressTrack,
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
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
    );
  }
}

extension NexColorsX on BuildContext {
  NexColors get colors =>
      Theme.of(this).extension<NexColors>() ?? NexColors.dark;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ─── Legacy shim ─────────────────────────────────────────────────────────────
class AppColors {
  static const background    = Color(0xFF080808);
  static const surface       = Color(0xFF121212);
  static const card          = Color(0xFF1C1C1C);
  static const primary       = NexColors.primary;
  static const primaryLight  = NexColors.primaryLight;
  static const accent        = NexColors.accent;
  static const accentOrange  = NexColors.accentOrange;
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B0B0);
  static const textMuted     = Color(0xFF666666);
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
  static const premiumMonthlyId = 'nexskills_premium_monthly';
  static const premiumYearlyId  = 'nexskills_premium_yearly';
}

// ─── Ad constants — PRODUCTION IDs ───────────────────────────────────────────
// Android IDs from AdMob dashboard (ca-app-pub-2492078126313994~7689058997)
// iOS IDs: replace with your iOS AdMob unit IDs when you create them
class AdConstants {
  // Android — PRODUCTION (your real IDs)
  static const androidAppId              = 'ca-app-pub-2492078126313994~7689058997';
  static const androidBannerId           = 'ca-app-pub-2492078126313994/2501069669';
  static const androidInterstitialId     = 'ca-app-pub-2492078126313994/6735828149';
  static const androidRewardedId         = 'ca-app-pub-2492078126313994/5558477847';
  static const androidRewardedInterstitialId = 'ca-app-pub-2492078126313994/3430402711';
  static const androidNativeId           = 'ca-app-pub-2492078126313994/9800975184';
  // App-open: create this in AdMob → Ad units → App open. Paste ID here.
  static const androidAppOpenId          = 'ca-app-pub-2492078126313994/XXXXXXXXXX';

  // iOS — replace with your real iOS AdMob unit IDs
  static const iosBannerId               = 'ca-app-pub-2492078126313994/XXXXXXXXXX';
  static const iosInterstitialId         = 'ca-app-pub-2492078126313994/XXXXXXXXXX';
  static const iosRewardedId             = 'ca-app-pub-2492078126313994/XXXXXXXXXX';
  static const iosRewardedInterstitialId = 'ca-app-pub-2492078126313994/XXXXXXXXXX';
  static const iosNativeId               = 'ca-app-pub-2492078126313994/XXXXXXXXXX';
  static const iosAppOpenId              = 'ca-app-pub-2492078126313994/XXXXXXXXXX';

  // Policy: min 60s between interstitials. We use 90s for safety margin.
  static const interstitialCooldownSeconds = 90;
}

// ─── Categories ───────────────────────────────────────────────────────────────
class AppCategories {
  static const List<CategoryMeta> all = [
    CategoryMeta(id: 'ai',            title: 'AI & Prompt Engineering', icon: '🤖', color: NexColors.categoryAI,     description: 'Master AI tools, LLMs and prompt engineering'),
    CategoryMeta(id: 'cybersecurity', title: 'Cybersecurity',           icon: '🔐', color: NexColors.categoryCyber,  description: 'Ethical hacking, networks and security'),
    CategoryMeta(id: 'nocode',        title: 'No-Code / Low-Code',      icon: '⚡', color: NexColors.categoryNoCode, description: 'Build powerful apps without writing code'),
    CategoryMeta(id: 'data',          title: 'Data & Analytics',        icon: '📊', color: NexColors.categoryData,   description: 'SQL, Python, visualization and data thinking'),
    CategoryMeta(id: 'cloud',         title: 'Cloud & DevOps',          icon: '☁️', color: NexColors.categoryCloud,  description: 'AWS, GCP, Azure and DevOps practices'),
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

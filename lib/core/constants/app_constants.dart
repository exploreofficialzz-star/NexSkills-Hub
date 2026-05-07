import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0A0E1A);
  static const surface = Color(0xFF141828);
  static const card = Color(0xFF1E2438);
  static const primary = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFF9D97FF);
  static const accent = Color(0xFF00D4AA);
  static const accentOrange = Color(0xFFFF6B35);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B8D4);
  static const textMuted = Color(0xFF6B7494);
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFB74D);
  static const error = Color(0xFFEF5350);
  static const locked = Color(0xFF2A3050);
  static const gold = Color(0xFFFFD700);

  static const categoryAI = Color(0xFF6C63FF);
  static const categoryCyber = Color(0xFF00D4AA);
  static const categoryNoCode = Color(0xFFFF6B35);
  static const categoryData = Color(0xFF4FC3F7);
  static const categoryCloud = Color(0xFFAB47BC);
}

class AppStrings {
  static const appName = 'NexSkills Hub';
  static const brandName = 'chAs';
  static const companyName = 'chAs Tech Group';
  static const tagline = 'Your daily tech career journey';

  static const tabToday = 'Today';
  static const tabPaths = 'My Path';
  static const tabExplore = 'Explore';
  static const tabProgress = 'Progress';

  static const premiumMonthly = '\$9.99/month';
  static const premiumYearly = '\$59.99/year';
  static const premiumMonthlyId = 'nexskills_premium_monthly';
  static const premiumYearlyId = 'nexskills_premium_yearly';
}

class AdConstants {
  // REPLACE with your real AdMob IDs before release
  // Android
  static const androidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const androidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const androidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const androidNativeId = 'ca-app-pub-3940256099942544/2247696110';

  // iOS
  static const iosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';
  static const iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';
  static const iosNativeId = 'ca-app-pub-3940256099942544/3986624511';

  // Frequency cap - min seconds between interstitials
  static const interstitialCooldownSeconds = 180;
}

class AppCategories {
  static const List<CategoryMeta> all = [
    CategoryMeta(
      id: 'ai',
      title: 'AI & Prompt Engineering',
      icon: '🤖',
      color: AppColors.categoryAI,
      description: 'Master AI tools, LLMs and prompt engineering',
    ),
    CategoryMeta(
      id: 'cybersecurity',
      title: 'Cybersecurity',
      icon: '🔐',
      color: AppColors.categoryCyber,
      description: 'Ethical hacking, networks and security fundamentals',
    ),
    CategoryMeta(
      id: 'nocode',
      title: 'No-Code / Low-Code',
      icon: '⚡',
      color: AppColors.categoryNoCode,
      description: 'Build powerful apps without writing code',
    ),
    CategoryMeta(
      id: 'data',
      title: 'Data & Analytics',
      icon: '📊',
      color: AppColors.categoryData,
      description: 'SQL, Python, visualization and data thinking',
    ),
    CategoryMeta(
      id: 'cloud',
      title: 'Cloud & DevOps',
      icon: '☁️',
      color: AppColors.categoryCloud,
      description: 'AWS, GCP, Azure and DevOps practices',
    ),
  ];
}

class CategoryMeta {
  final String id;
  final String title;
  final String icon;
  final Color color;
  final String description;

  const CategoryMeta({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
  });
}

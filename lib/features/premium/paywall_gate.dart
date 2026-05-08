import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/revenue_config.dart';
import '../premium/premium_screen.dart';

/// Tracks daily free content consumption and gates after the limit.
/// Wrap around any content-opening action:
///
/// ```dart
/// PaywallGate.checkAndProceed(
///   context: context,
///   type: 'article',
///   onAllowed: () => _openResource(resource),
/// );
/// ```
class PaywallGate {
  static const _box = 'paywallCounts';
  static const _articleKey = 'articles';
  static const _videoKey = 'videos';
  static const _dateKey = 'date';

  static Future<void> checkAndProceed({
    required BuildContext context,
    required String type, // 'article' | 'video'
    required VoidCallback onAllowed,
  }) async {
    final progress = HiveService.getProgress();
    if (progress.isPremium) {
      onAllowed();
      return;
    }

    final box = await Hive.openBox(_box);
    final today = _todayKey();
    final savedDate = box.get(_dateKey, defaultValue: '');

    // Reset counts on new day
    if (savedDate != today) {
      await box.put(_dateKey, today);
      await box.put(_articleKey, 0);
      await box.put(_videoKey, 0);
    }

    final isVideo = type == 'video';
    final countKey = isVideo ? _videoKey : _articleKey;
    final limit = isVideo
        ? RevenueConfig.freeVideosPerDay
        : RevenueConfig.freeArticlesPerDay;
    final count = box.get(countKey, defaultValue: 0) as int;

    if (count < limit) {
      await box.put(countKey, count + 1);
      onAllowed();
    } else {
      if (context.mounted) {
        _showPaywall(context, type: type, onDismissed: onAllowed);
      }
    }
  }

  static void _showPaywall(
    BuildContext context, {
    required String type,
    required VoidCallback onDismissed,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaywallSheet(
        contentType: type,
        onUpgrade: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PremiumScreen()),
          );
        },
        onDismiss: () {
          Navigator.pop(context);
          // Allow anyway after dismiss (soft gate — don't hard block)
          onDismissed();
        },
      ),
    );
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}

class _PaywallSheet extends StatelessWidget {
  final String contentType;
  final VoidCallback onUpgrade;
  final VoidCallback onDismiss;

  const _PaywallSheet({
    required this.contentType,
    required this.onUpgrade,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = contentType == 'video';
    final limit =
        isVideo ? RevenueConfig.freeVideosPerDay : RevenueConfig.freeArticlesPerDay;
    final typeName = isVideo ? 'videos' : 'articles';

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pill handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.3),
                  AppColors.accent.withOpacity(0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('👑', style: TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 20),

          // Heading
          Text(
            "You've read $limit free $typeName today",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Go Premium for unlimited access to all content,\nzero ads, and all 5 learning tracks.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Value props
          _ValueRow(emoji: '🚫', text: 'No ads, ever'),
          const SizedBox(height: 10),
          _ValueRow(emoji: '♾️', text: 'Unlimited articles & videos daily'),
          const SizedBox(height: 10),
          _ValueRow(emoji: '📚', text: 'All 5 learning tracks unlocked'),
          const SizedBox(height: 10),
          _ValueRow(
              emoji: '🎯', text: '${RevenueConfig.trialDays}-day free trial — cancel anytime'),
          const SizedBox(height: 28),

          // Primary CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Column(
                children: [
                  Text(
                    'Start 7-Day Free Trial',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'then \$9.99/month • cancel anytime',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary — let them through anyway (soft gate)
          GestureDetector(
            onTap: onDismiss,
            child: const Text(
              'Continue with limited access',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String emoji;
  final String text;

  const _ValueRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/ad_block_service.dart';
import '../features/premium/premium_screen.dart';

/// Shows a bottom-sheet gate when ad blocking is detected.
///
/// Usage — call this anywhere before showing an ad:
/// ```dart
/// final blocked = await AdBlockService.instance.isAdBlocked();
/// if (blocked && context.mounted) {
///   AdBlockGate.show(context, onAllowed: () => _showAd());
/// }
/// ```
class AdBlockGate {
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onAllowed,
    VoidCallback? onSubscribed,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false, // Force a decision
      enableDrag: false,
      builder: (_) => _AdBlockSheet(
        onAllowed: onAllowed,
        onSubscribed: onSubscribed,
      ),
    );
  }
}

class _AdBlockSheet extends StatefulWidget {
  final VoidCallback? onAllowed;
  final VoidCallback? onSubscribed;

  const _AdBlockSheet({this.onAllowed, this.onSubscribed});

  @override
  State<_AdBlockSheet> createState() => _AdBlockSheetState();
}

class _AdBlockSheetState extends State<_AdBlockSheet> {
  bool _checking = false;
  bool _stillBlocked = false;

  Future<void> _recheck() async {
    setState(() { _checking = true; _stillBlocked = false; });
    final blocked = await AdBlockService.instance.recheckNow();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!blocked) {
      // Ad blocker disabled — close sheet and proceed
      Navigator.pop(context);
      widget.onAllowed?.call();
    } else {
      setState(() => _stillBlocked = true);
    }
  }

  void _goToPremium() {
    Navigator.pop(context);
    RemoveAdsModal.show(context);
    widget.onSubscribed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: NexColors.error.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: NexColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🚫', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 20),

          // Heading
          Text(
            'Ad Blocker Detected',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'NexSkills Hub is free because of ads.\nAd blockers prevent us from keeping\nthe app running for everyone.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),

          if (_stillBlocked) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: NexColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: NexColors.error.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text(
                    'Ad blocker still active',
                    style: TextStyle(
                        color: NexColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Option 1: Disable ad blocker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Text('Free option',
                        style: TextStyle(
                            color: NexColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Disable your ad blocker for NexSkills Hub',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  'Whitelist us, then tap the button below.',
                  style: TextStyle(color: c.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _checking ? null : _recheck,
                    icon: _checking
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh, color: Colors.white, size: 18),
                    label: Text(
                      _checking ? 'Checking...' : 'I\'ve Disabled It — Continue',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NexColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: c.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR',
                    style: TextStyle(
                        color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Expanded(child: Divider(color: c.border)),
            ],
          ),

          const SizedBox(height: 12),

          // Option 2: Subscribe
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  NexColors.primary.withOpacity(0.12),
                  NexColors.accent.withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: NexColors.primary.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Text('Ad-free option',
                        style: TextStyle(
                            color: NexColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Subscribe for completely ad-free learning',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  'Starting from \$3.99/week — cancel anytime.',
                  style: TextStyle(color: c.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _goToPremium,
                    icon: const Icon(Icons.star, color: Colors.white, size: 18),
                    label: const Text(
                      'See Plans',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Text(
            'Ads fund free access for everyone.\nThank you for understanding. 🙏',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

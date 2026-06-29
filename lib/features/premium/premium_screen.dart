import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/hive_service.dart';

/// Remove Ads — shown as a popup bottom sheet from any screen.
///
/// Usage:
///   RemoveAdsModal.show(context);
///
/// Products (register in Play Console as consumable in-app products):
///   nexskills_remove_ads_day    → $0.99  → 1 day
///   nexskills_remove_ads_week   → $2.99  → 7 days
///   nexskills_remove_ads_month  → $7.99  → 30 days
///
/// After purchase the existing isPremium + premiumExpiry fields are set so
/// all existing ad-suppression checks (isPremium) keep working without any
/// model migration.
class RemoveAdsModal {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const _RemoveAdsSheet(),
    );
  }
}

// ─── Product IDs ──────────────────────────────────────────────────────────────
const _kDayId   = 'nexskills_remove_ads_day';
const _kWeekId  = 'nexskills_remove_ads_week';
const _kMonthId = 'nexskills_remove_ads_month';

// ─── Plan definitions ─────────────────────────────────────────────────────────
class _Plan {
  final String id;
  final String label;
  final String price;
  final String sub;
  final Duration duration;
  final bool highlight;

  const _Plan({
    required this.id,
    required this.label,
    required this.price,
    required this.sub,
    required this.duration,
    this.highlight = false,
  });
}

const _plans = [
  _Plan(
    id: _kDayId,
    label: '1 Day',
    price: '\$0.99',
    sub: 'Try it out',
    duration: Duration(days: 1),
  ),
  _Plan(
    id: _kWeekId,
    label: '1 Week',
    price: '\$2.99',
    sub: 'Best starter',
    duration: Duration(days: 7),
    highlight: true,
  ),
  _Plan(
    id: _kMonthId,
    label: '1 Month',
    price: '\$7.99',
    sub: 'Best value',
    duration: Duration(days: 30),
  ),
];

// ─── Sheet ────────────────────────────────────────────────────────────────────
class _RemoveAdsSheet extends StatefulWidget {
  const _RemoveAdsSheet();

  @override
  State<_RemoveAdsSheet> createState() => _RemoveAdsSheetState();
}

class _RemoveAdsSheetState extends State<_RemoveAdsSheet> {
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  List<ProductDetails> _products = [];
  bool _loading = true;
  bool _purchasing = false;
  String _selectedId = _kWeekId; // Week pre-selected

  @override
  void initState() {
    super.initState();
    _sub = _iap.purchaseStream.listen(_onPurchases);
    _loadProducts();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final available = await _iap.isAvailable();
    if (!available) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final res = await _iap.queryProductDetails({_kDayId, _kWeekId, _kMonthId});
    if (mounted) setState(() { _products = res.productDetails; _loading = false; });
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);

      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        final plan = _plans.firstWhere(
          (pl) => pl.id == p.productID,
          orElse: () => _plans[1],
        );
        final expiry = DateTime.now().add(plan.duration);
        await HiveService.setPremium(true, expiry: expiry);
        if (mounted) {
          setState(() => _purchasing = false);
          _showSuccess(plan);
        }
      } else if (p.status == PurchaseStatus.error) {
        if (mounted) setState(() => _purchasing = false);
      }
    }
  }

  Future<void> _buy(String productId) async {
    if (_products.isEmpty) return;
    final match = _products.where((p) => p.id == productId);
    if (match.isEmpty) return;
    setState(() => _purchasing = true);
    await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: match.first));
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    await _iap.restorePurchases();
  }

  void _showSuccess(_Plan plan) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text('🚫', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              'Ads removed for ${plan.label}!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enjoy NexSkills Hub without interruptions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Let\'s Go! 🚀'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 12, 24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: c.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ── Close button + title ─────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              const Text(
                '🚫  Remove Ads',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: c.textMuted.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 18, color: c.textMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Enjoy NexSkills Hub without interruptions',
            style: TextStyle(color: c.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // ── Plan tiles ───────────────────────────────────────────
          Row(
            children: _plans.map((plan) {
              final selected = _selectedId == plan.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedId = plan.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? NexColors.primary.withOpacity(0.12)
                          : c.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? NexColors.primary : c.textMuted.withOpacity(0.2),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (plan.highlight) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: NexColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'POPULAR',
                              style: TextStyle(
                                color: Colors.white, fontSize: 8,
                                fontWeight: FontWeight.w800, letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ] else
                          const SizedBox(height: 16),
                        Text(
                          plan.price,
                          style: TextStyle(
                            color: selected ? NexColors.primary : c.textPrimary,
                            fontSize: 20, fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plan.label,
                          style: TextStyle(
                            color: c.textSecondary, fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plan.sub,
                          style: TextStyle(color: c.textMuted, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── CTA ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_loading || _purchasing)
                  ? null
                  : () => _buy(_selectedId),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: NexColors.primary,
                disabledBackgroundColor: c.textMuted.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _purchasing
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : _loading
                      ? Text('Loading…',
                          style: TextStyle(color: c.textMuted, fontSize: 16))
                      : const Text(
                          'Remove Ads Now',
                          style: TextStyle(
                              color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.w800),
                        ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Restore ──────────────────────────────────────────────
          TextButton(
            onPressed: _purchasing ? null : _restore,
            child: Text('Restore purchase',
                style: TextStyle(color: c.textMuted, fontSize: 12)),
          ),

          // ── Legal ────────────────────────────────────────────────
          Text(
            'One-time purchase · No subscription · Expires after selected period.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMuted, fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }
}

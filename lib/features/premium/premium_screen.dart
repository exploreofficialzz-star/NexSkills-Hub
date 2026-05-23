import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/revenue_config.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with SingleTickerProviderStateMixin {
  final InAppPurchase _iap = InAppPurchase.instance;
  List<ProductDetails> _products = [];
  bool _loading = true;
  bool _purchasing = false;

  // Annual pre-selected — always drives higher LTV
  String? _selectedProductId;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _selectedProductId = AppStrings.premiumYearlyId;
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadProducts();
    _listenPurchases();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final available = await _iap.isAvailable();
    if (!available) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final ids = {AppStrings.premiumMonthlyId, AppStrings.premiumYearlyId};
    final response = await _iap.queryProductDetails(ids);
    if (mounted) {
      setState(() {
        _products = response.productDetails;
        _loading = false;
      });
    }
  }

  void _listenPurchases() {
    _iap.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          await _iap.completePurchase(p);
          final expiry = p.productID == AppStrings.premiumYearlyId
              ? DateTime.now().add(const Duration(days: 365))
              : DateTime.now().add(const Duration(days: 30));
          await HiveService.setPremium(true, expiry: expiry);
          if (mounted) {
            setState(() => _purchasing = false);
            _showSuccess();
          }
        } else if (p.status == PurchaseStatus.error) {
          if (mounted) setState(() => _purchasing = false);
        }
      }
    });
  }

  Future<void> _purchase(String productId) async {
    if (_products.isEmpty) return;
    final match = _products.where((p) => p.id == productId);
    if (match.isEmpty) return;
    setState(() => _purchasing = true);
    final param = PurchaseParam(productDetails: match.first);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Welcome to Premium!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'All ads gone. All tracks unlocked.\nYour journey just levelled up.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("Let's Go! 🚀"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildHero(),
                        const SizedBox(height: 28),
                        _buildFeatureComparison(),
                        const SizedBox(height: 28),
                        _buildPlans(),
                        const SizedBox(height: 24),
                        _buildCTA(),
                        const SizedBox(height: 12),
                        _buildRestoreButton(),
                                const SizedBox(height: 20),
                        _buildLegal(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_purchasing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('Processing...',
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.18),
            AppColors.accent.withOpacity(0.06),
            AppColors.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.35, 0.7],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textMuted),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          const SizedBox.shrink(), // badge removed
        ],
      ),
    );
  }



  Widget _buildHero() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withOpacity(0.25),
                AppColors.primary.withOpacity(0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border:
                Border.all(color: AppColors.gold.withOpacity(0.4), width: 1.5),
          ),
          child: const Center(
            child: Text('👑', style: TextStyle(fontSize: 46)),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'NexSkills Premium',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The fastest way to break into tech.\nNo fluff. No overpriced courses.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureComparison() {
    final rows = [
      ('Daily content', true, true),
      ('Ads shown', true, false),
      ('Articles per day', false, true), // false = limited, true = unlimited
      ('Learning tracks', false, true),
      ('Offline access', false, true),
      ('Full analytics', false, true),
      ('Early access to new paths', false, true),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card, // surfaceVariant
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surface),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                _tableHeader('Free', AppColors.textMuted),
                const SizedBox(width: 4),
                _tableHeader('Premium', AppColors.gold),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surface),
          ...rows.asMap().entries.map((e) {
            final i = e.key;
            final row = e.value;
            final isLast = i == rows.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.$1,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _tableCell(row.$2, isFree: true),
                      const SizedBox(width: 4),
                      _tableCell(row.$3, isFree: false),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(
                      height: 1, color: AppColors.surface, indent: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _tableHeader(String label, Color color) {
    return SizedBox(
      width: 72,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _tableCell(bool enabled, {required bool isFree}) {
    // For "Ads shown" row, free=true means ads shown (bad) and premium=false means no ads (good)
    return SizedBox(
      width: 72,
      child: Center(
        child: Icon(
          enabled ? Icons.check_circle_outline : Icons.cancel_outlined,
          color: enabled
              ? (isFree ? AppColors.textMuted : AppColors.success)
              : (isFree ? AppColors.error : AppColors.success),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildPlans() {
    return Column(
      children: [
        // Annual — highlighted first
        _PlanTile(
          productId: AppStrings.premiumYearlyId,
          label: 'Annual',
          price: RevenueConfig.yearlyPriceDisplay,
          perMonth: '${RevenueConfig.yearlyPerMonthDisplay}/mo',
          badge: 'BEST VALUE — 50% OFF',
          badgeColor: AppColors.success,
          selected: _selectedProductId == AppStrings.premiumYearlyId,
          onTap: () =>
              setState(() => _selectedProductId = AppStrings.premiumYearlyId),
        ),
        const SizedBox(height: 10),
        // Monthly
        _PlanTile(
          productId: AppStrings.premiumMonthlyId,
          label: 'Monthly',
          price: RevenueConfig.monthlyPriceDisplay,
          perMonth: 'billed monthly',
          badge: null,
          badgeColor: null,
          selected: _selectedProductId == AppStrings.premiumMonthlyId,
          onTap: () =>
              setState(() => _selectedProductId = AppStrings.premiumMonthlyId),
        ),
      ],
    );
  }

  Widget _buildCTA() {
    final isYearly = _selectedProductId == AppStrings.premiumYearlyId;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading || _selectedProductId == null
                ? null
                : () => _purchase(_selectedProductId!),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Column(
                    children: [
                      Text(
                        'Start ${RevenueConfig.trialDays}-Day Free Trial',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        isYearly
                            ? 'then ${RevenueConfig.yearlyPriceDisplay} • cancel anytime'
                            : 'then ${RevenueConfig.monthlyPriceDisplay} • cancel anytime',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: AppColors.textMuted, size: 14),
            SizedBox(width: 4),
            Text(
              'Secure payment · Cancel anytime',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRestoreButton() {
    return TextButton(
      onPressed: () async {
        setState(() => _purchasing = true);
        await _iap.restorePurchases();
      },
      child: const Text(
        'Restore Purchases',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    );
  }


  Widget _buildLegal() {
    return const Text(
      'Subscription auto-renews unless cancelled 24h before period ends.\n'
      'Payment charged to your Google Play / App Store account.\n'
      'Free trial converts to paid unless cancelled before trial ends.',
      textAlign: TextAlign.center,
      style: TextStyle(
          color: AppColors.textMuted, fontSize: 10, height: 1.6),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String productId;
  final String label;
  final String price;
  final String perMonth;
  final String? badge;
  final Color? badgeColor;
  final bool selected;
  final VoidCallback onTap;

  const _PlanTile({
    required this.productId,
    required this.label,
    required this.price,
    required this.perMonth,
    required this.badge,
    required this.badgeColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Radio
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textMuted,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                  : null,
            ),
            const SizedBox(width: 14),
            // Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      )),
                  Text(perMonth,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      )),
                ],
              ),
            ),
            // Price + badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price,
                    style: TextStyle(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    )),
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor!.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badge!,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

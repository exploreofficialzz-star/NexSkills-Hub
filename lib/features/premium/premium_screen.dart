import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/hive_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  List<ProductDetails> _products = [];
  bool _loading = true;
  bool _purchasing = false;
  String? _selectedProductId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _listenPurchases();
  }

  Future<void> _loadProducts() async {
    final available = await _iap.isAvailable();
    if (!available) {
      setState(() => _loading = false);
      return;
    }
    final ids = {
      AppStrings.premiumMonthlyId,
      AppStrings.premiumYearlyId,
    };
    final response = await _iap.queryProductDetails(ids);
    if (mounted) {
      setState(() {
        _products = response.productDetails;
        _selectedProductId = AppStrings.premiumYearlyId;
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
    final product = _products.firstWhere((p) => p.id == productId,
        orElse: () => _products.first);
    setState(() => _purchasing = true);
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👑', style: TextStyle(fontSize: 50)),
            const SizedBox(height: 12),
            const Text('Welcome to Premium!',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('All ads removed. All tracks unlocked.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("Let's Go!"),
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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildHero(),
                        const SizedBox(height: 32),
                        _buildFeatures(),
                        const SizedBox(height: 32),
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
                  child: CircularProgressIndicator(
                      color: AppColors.primary)),
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
            AppColors.primary.withOpacity(0.2),
            AppColors.background,
            AppColors.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.4, 1],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textMuted),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('👑', style: TextStyle(fontSize: 42)),
          ),
        ),
        const SizedBox(height: 20),
        const Text('NexSkills Premium',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8)),
        const SizedBox(height: 8),
        const Text(
          'The most affordable way to master tech skills.\nNo fluff. No overpriced courses.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.5),
        ),
      ],
    );
  }

  Widget _buildFeatures() {
    final features = [
      ('🚫', 'Zero Ads', 'Completely ad-free learning experience'),
      ('📚', 'All 5 Tracks', 'Unlock every category simultaneously'),
      ('📱', 'Offline Access', 'Cache lessons for offline learning'),
      ('📊', 'Full Analytics', 'Detailed progress and time tracking'),
      ('⚡', 'Early Access', 'New paths before public release'),
      ('👑', 'Premium Badge', 'Stand out on your profile'),
    ];

    return Column(
      children: features.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child: Text(f.$1,
                      style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.$2,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text(f.$3,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildPlans() {
    final plans = [
      (AppStrings.premiumMonthlyId, 'Monthly', '\$9.99/month', 'Billed monthly', false),
      (AppStrings.premiumYearlyId, 'Annual', '\$59.99/year', 'Save 50% vs monthly', true),
    ];

    return Column(
      children: plans.map((plan) {
        final selected = _selectedProductId == plan.$1;
        return GestureDetector(
          onTap: () => setState(() => _selectedProductId = plan.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withOpacity(0.12)
                  : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.primary
                        : Colors.transparent,
                    border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted),
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.$2,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Text(plan.$4,
                          style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(plan.$3,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    if (plan.$5)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('BEST VALUE',
                            style: TextStyle(
                                color: AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCTA() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _selectedProductId == null
            ? null
            : () => _purchase(_selectedProductId!),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.primary,
        ),
        child: Text(
          _selectedProductId == AppStrings.premiumYearlyId
              ? 'Start Premium — \$59.99/year'
              : 'Start Premium — \$9.99/month',
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    return TextButton(
      onPressed: () async {
        setState(() => _purchasing = true);
        await _iap.restorePurchases();
      },
      child: const Text('Restore Purchases',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
    );
  }

  Widget _buildLegal() {
    return const Text(
      'Cancel anytime. Subscription renews automatically.\nPayment charged to your Google Play / App Store account.',
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.5),
    );
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'hive_service.dart';

/// Google Play subscription product IDs.
/// These must match EXACTLY what you create in Google Play Console →
/// Monetise → Subscriptions.
class IAPProductIds {
  static const monthly = 'nexskills_monthly'; // $9.99/month
  static const annual  = 'nexskills_annual';  // $59.99/year (7-day free trial)
  static const all = <String>{monthly, annual};
}

/// IAPService — handles all Google Play subscription logic.
///
/// Flow:
///   1. Call [initialize] once (from HomeScreen postFrameCallback).
///   2. Observe [products] for UI prices pulled live from Play Store.
///   3. Call [buy] with a product ID to start the Play billing flow.
///   4. Call [restore] to restore purchases on a new device.
///   5. [onPurchaseSuccess] fires → HiveService.setPremium(true) already called.
class IAPService {
  IAPService._();
  static final IAPService instance = IAPService._();

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  List<ProductDetails> _products = [];
  bool _available = false;
  bool _loading   = true;
  bool _restoring = false;

  List<ProductDetails> get products => _products;
  bool get available  => _available;
  bool get loading    => _loading;

  // ── UI callbacks ──────────────────────────────────────────────
  VoidCallback?          onProductsLoaded;
  VoidCallback?          onPurchaseSuccess;
  VoidCallback?          onRestoreComplete;
  VoidCallback?          onPurchasePending;
  void Function(String)? onPurchaseError;
  VoidCallback?          onStateChanged; // generic rebuild trigger

  // ─────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    _available = await _iap.isAvailable();
    if (!_available) {
      _loading = false;
      onStateChanged?.call();
      return;
    }

    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) {
        onPurchaseError?.call(e.toString());
      },
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(IAPProductIds.all);
      _products = response.productDetails
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice)); // monthly first
      if (kDebugMode && response.notFoundIDs.isNotEmpty) {
        debugPrint('[IAP] Products not found: ${response.notFoundIDs}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP] loadProducts error: $e');
    } finally {
      _loading = false;
      onProductsLoaded?.call();
      onStateChanged?.call();
    }
  }

  /// Start the Play billing flow for [productId].
  Future<void> buy(String productId) async {
    if (!_available) {
      onPurchaseError?.call('Play Store not available on this device.');
      return;
    }
    final ProductDetails? product = _products.cast<ProductDetails?>()
        .firstWhere((p) => p?.id == productId, orElse: () => null);
    if (product == null) {
      onPurchaseError?.call('Product not available. Try again later.');
      return;
    }
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Restore purchases (e.g. after reinstall or new device).
  Future<void> restore() async {
    if (!_available) return;
    _restoring = true;
    onStateChanged?.call();
    await _iap.restorePurchases();
  }

  // ─────────────────────────────────────────────────────────────
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
          await _deliver(p);
          break;
        case PurchaseStatus.restored:
          await _deliver(p, restored: true);
          break;
        case PurchaseStatus.error:
          onPurchaseError?.call(p.error?.message ?? 'Purchase failed.');
          break;
        case PurchaseStatus.canceled:
          break;
        case PurchaseStatus.pending:
          onPurchasePending?.call();
          break;
      }
      // Always complete to avoid re-delivery
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }

    if (_restoring) {
      _restoring = false;
      onRestoreComplete?.call();
      onStateChanged?.call();
    }
  }

  Future<void> _deliver(PurchaseDetails p, {bool restored = false}) async {
    if (!IAPProductIds.all.contains(p.productID)) return;

    // Grant premium — persisted in Hive
    await HiveService.setPremium(true);

    if (restored) {
      onRestoreComplete?.call();
    } else {
      onPurchaseSuccess?.call();
    }
    onStateChanged?.call();
  }

  // ─────────────────────────────────────────────────────────────
  ProductDetails? productFor(String id) =>
      _products.cast<ProductDetails?>()
          .firstWhere((p) => p?.id == id, orElse: () => null);

  String priceFor(String id, String fallback) =>
      productFor(id)?.price ?? fallback;

  void dispose() {
    _purchaseSub?.cancel();
  }
}

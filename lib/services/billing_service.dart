import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BillingService extends ChangeNotifier {
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;

  BillingService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Product IDs
  static const String proMonthly = 'pro_monthly';
  static const String proYearly = 'pro_yearly';

  final Set<String> _productIds = {proMonthly, proYearly};

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _isPro = false;
  bool get isPro => _isPro;

  bool _available = false;
  bool get available => _available;

  // Purchase state tracking for UI feedback
  PurchaseStatus? _lastPurchaseStatus;
  PurchaseStatus? get lastPurchaseStatus => _lastPurchaseStatus;
  String? _lastError;
  String? get lastError => _lastError;

  Future<void> init() async {
    final bool available = await _iap.isAvailable();
    _available = available;

    if (!available) {
      debugPrint('[Billing] Store not available');
      return;
    }

    // Note: enablePendingPurchases() is deprecated and no longer needed
    // as pending purchases are now enabled by default

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onDone: () => _subscription.cancel(),
      onError: (error) => debugPrint('[Billing] Error: $error'),
    );

    await _loadProducts();
    await _verifyPurchases();

    // Check local cache — keyed by UID if available
    final box = await Hive.openBox('app_settings_box');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final proKey = uid != null ? 'isPro_$uid' : 'isPro';
    _isPro = box.get(proKey, defaultValue: false);
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    final ProductDetailsResponse response = await _iap.queryProductDetails(
      _productIds,
    );

    if (response.error != null) {
      debugPrint('[Billing] Load error: ${response.error}');
      return;
    }

    _products = response.productDetails;
    notifyListeners();
  }

  Future<void> purchase(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    // For subscriptions, we might need to handle upgrades/downgrades
    // but simple purchase is fine for now.
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      _lastPurchaseStatus = purchaseDetails.status;

      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Notify listeners so UI can show pending state
        _lastError = null;
        notifyListeners();
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        _lastError = 'Purchase cancelled';
        notifyListeners();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _lastError = purchaseDetails.error?.message ?? 'Purchase failed';
          debugPrint('[Billing] Purchase Error: ${purchaseDetails.error}');
          notifyListeners();
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _lastError = null;
          await _deliverProduct(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    if (_productIds.contains(purchaseDetails.productID)) {
      _isPro = true;
      final box = await Hive.openBox('app_settings_box');
      // Persist per UID if available
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final proKey = uid != null ? 'isPro_$uid' : 'isPro';
      await box.put(proKey, true);
      notifyListeners();
    }
  }

  Future<void> _verifyPurchases() async {
    // This is called on init to check if user already has active subscriptions
    // In strict implementations, we would restorePurchases silently or query past purchases.
    // simpler to just call restore on init? No, that might prompt password.
    // We rely on purchaseStream updates or explicit restore button.
  }

  /// Convenience method to purchase the first pro product (monthly)
  Future<void> purchasePro() async {
    final proProduct = _products.firstWhere(
      (p) => p.id == proMonthly,
      orElse: () => _products.isNotEmpty
          ? _products.first
          : throw StateError('No products available'),
    );
    await purchase(proProduct);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

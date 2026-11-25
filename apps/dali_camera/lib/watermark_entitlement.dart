import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class WatermarkEntitlement extends ChangeNotifier {
  bool get unlocked;
  bool get loading;
  bool get purchasing;
  bool get storeAvailable;
  String? get price;
  String? get message;

  Future<void> initialize();
  Future<void> purchase();
  Future<void> restore();
}

class StoreWatermarkEntitlement extends WatermarkEntitlement {
  StoreWatermarkEntitlement({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  static const productId = 'dali_camera_watermark_lifetime';
  static const _entitlementKey = 'watermarkLifetimeUnlocked';

  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _product;
  bool _initialized = false;
  bool _unlocked = false;
  bool _loading = true;
  bool _purchasing = false;
  bool _storeAvailable = false;
  bool _restoring = false;
  String? _message;

  @override
  bool get unlocked => _unlocked;

  @override
  bool get loading => _loading;

  @override
  bool get purchasing => _purchasing;

  @override
  bool get storeAvailable => _storeAvailable;

  @override
  String? get price => _product?.price;

  @override
  String? get message => _message;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final preferences = await SharedPreferences.getInstance();
    _unlocked = preferences.getBool(_entitlementKey) ?? false;
    _subscription = _store.purchaseStream.listen(
      (purchases) => unawaited(_handlePurchases(purchases)),
      onError: (Object error) {
        _purchasing = false;
        _restoring = false;
        _message = 'The store could not update the purchase: $error';
        notifyListeners();
      },
    );
    try {
      _storeAvailable = await _store.isAvailable();
      if (_storeAvailable) {
        final response = await _store.queryProductDetails({productId});
        _product = response.productDetails.firstOrNull;
        if (response.error != null) {
          _message = response.error!.message;
        } else if (_product == null) {
          _message = 'The lifetime unlock is not configured in this store yet.';
        }
      } else {
        _message = 'The App Store or Play Store is unavailable.';
      }
    } catch (error) {
      _storeAvailable = false;
      _message = 'The store is unavailable: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  Future<void> purchase() async {
    if (_unlocked || _purchasing) return;
    final product = _product;
    if (!_storeAvailable || product == null) {
      _message = 'The lifetime unlock is not available for purchase yet.';
      notifyListeners();
      return;
    }
    _purchasing = true;
    _message = null;
    notifyListeners();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _purchasing = false;
        _message = 'The store did not start the purchase.';
        notifyListeners();
      }
    } catch (error) {
      _purchasing = false;
      _message = 'The purchase could not start: $error';
      notifyListeners();
    }
  }

  @override
  Future<void> restore() async {
    if (_purchasing) return;
    if (!_storeAvailable) {
      _message = 'The App Store or Play Store is unavailable.';
      notifyListeners();
      return;
    }
    _purchasing = true;
    _restoring = true;
    _message = 'Checking previous purchases…';
    notifyListeners();
    try {
      await _store.restorePurchases();
    } catch (error) {
      _purchasing = false;
      _restoring = false;
      _message = 'Purchases could not be restored: $error';
      notifyListeners();
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    if (purchases.isEmpty && _restoring) {
      _purchasing = false;
      _restoring = false;
      _message = 'No lifetime watermark purchase was found.';
      notifyListeners();
      return;
    }
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchasing = true;
          _message = 'Waiting for the store to finish the purchase…';
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final preferences = await SharedPreferences.getInstance();
          await preferences.setBool(_entitlementKey, true);
          _unlocked = true;
          _purchasing = false;
          _restoring = false;
          _message = purchase.status == PurchaseStatus.restored
              ? 'Lifetime watermark access restored.'
              : 'Lifetime watermark access unlocked.';
          break;
        case PurchaseStatus.error:
          _purchasing = false;
          _restoring = false;
          _message = purchase.error?.message ?? 'The purchase failed.';
          break;
        case PurchaseStatus.canceled:
          _purchasing = false;
          _restoring = false;
          _message = 'Purchase canceled.';
          break;
      }
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

class FixedWatermarkEntitlement extends WatermarkEntitlement {
  FixedWatermarkEntitlement({this.unlocked = true});

  @override
  bool unlocked;

  @override
  bool get loading => false;

  @override
  bool get purchasing => false;

  @override
  bool get storeAvailable => true;

  @override
  String? get price => r'$9.99';

  @override
  String? get message => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> purchase() async {}

  @override
  Future<void> restore() async {}
}

// Google Play Billing wrapper for the app's in-app purchases:
//   - One non-consumable, `removeAds` — permanently hides the banner ad.
//   - Three consumables, `tipSmall` / `tipMedium` / `tipLarge` — pure
//     support-the-developer tips with no in-app functionality attached.
// Direct port of iOS IAPStore.swift onto in_app_purchase.
//
// Product IDs use Play Console's snake_case convention (not iOS's
// reverse-DNS) — these must be registered in Play Console -> Monetize
// -> Products with EXACTLY these IDs before purchases will resolve.
// See README.md "Google Play Billing setup" for the full checklist.
//
// Ownership of the non-consumable is reconciled from Play's purchase
// stream + restorePurchases() on launch. Consumables are tracked
// locally (SharedPreferences) by count only — Play, like StoreKit,
// doesn't remember consumables server-side.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IAPStore extends ChangeNotifier {
  static const removeAdsID = 'remove_ads';
  static const tipSmallID = 'tip_small';
  static const tipMediumID = 'tip_medium';
  static const tipLargeID = 'tip_large';

  static const allIDs = <String>{removeAdsID, tipSmallID, tipMediumID, tipLargeID};

  static const _tipCountKey = 'iap.tipCount.v1';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  SharedPreferences? _prefs;

  List<ProductDetails> products = [];
  bool hasRemovedAds = false;
  bool isLoading = false;
  String? lastError;

  int get tipCount => _prefs?.getInt(_tipCountKey) ?? 0;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate, onError: (_) {});
    await refresh();
    // Reconciles the non-consumable against Play's records — the
    // Android equivalent of iOS's Transaction.currentEntitlements scan.
    await _iap.restorePurchases();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();
    try {
      final available = await _iap.isAvailable();
      if (!available) {
        lastError = 'Google Play Billing is not available on this device.';
        return;
      }
      final response = await _iap.queryProductDetails(allIDs);
      products = response.productDetails
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      lastError = null;
    } catch (e) {
      lastError = "Couldn't load purchases: $e";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> purchase(ProductDetails product) async {
    try {
      final param = PurchaseParam(productDetails: product);
      if (product.id == removeAdsID) {
        return await _iap.buyNonConsumable(purchaseParam: param);
      }
      return await _iap.buyConsumable(purchaseParam: param);
    } catch (e) {
      lastError = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      lastError = 'Restore failed: $e';
      notifyListeners();
    }
  }

  ProductDetails? get removeAdsProduct =>
      products.where((p) => p.id == removeAdsID).firstOrNull;

  List<ProductDetails> get tipProducts => [tipSmallID, tipMediumID, tipLargeID]
      .map((id) => products.where((p) => p.id == id).firstOrNull)
      .whereType<ProductDetails>()
      .toList();

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          lastError = purchase.error?.message;
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.productID == removeAdsID) {
            hasRemovedAds = true;
            notifyListeners();
          } else if (allIDs.contains(purchase.productID)) {
            // Consumable tip — bump the local tally, then tell Play the
            // consumable has been "used up" so it can be bought again.
            // consumePurchase lives on the Android-specific platform
            // addition, not the cross-platform InAppPurchase facade.
            _incrementTipCount();
            final addition = InAppPurchasePlatformAddition.instance;
            if (addition is InAppPurchaseAndroidPlatformAddition) {
              addition.consumePurchase(purchase);
            }
          }
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.canceled:
          break;
      }
    }
  }

  Future<void> _incrementTipCount() async {
    final next = tipCount + 1;
    await _prefs?.setInt(_tipCountKey, next);
    notifyListeners();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

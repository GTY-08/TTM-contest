import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../../core/constants/premium_constants.dart';

/// Google Play Billing — 프리미엄 월 구독.
class PlayBillingService {
  PlayBillingService();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  ProductDetails? _product;
  bool _available = false;

  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isStoreAvailable => _available;
  ProductDetails? get product => _product;

  String? get storePriceLabel => _product?.price;

  Future<void> initialize({
    required Future<void> Function(PurchaseDetails purchase) onVerifiedPurchase,
    void Function(Object error)? onError,
  }) async {
    if (!isAndroid) return;

    _available = await _iap.isAvailable();
    if (!_available) return;

    _sub = _iap.purchaseStream.listen(
      (purchases) => _onPurchases(purchases, onVerifiedPurchase, onError),
      onError: onError,
    );

    final response = await _iap.queryProductDetails({
      TtmPremiumConstants.playProductId,
    });
    if (response.error != null) {
      onError?.call(response.error!);
      return;
    }
    if (response.productDetails.isEmpty) return;
    _product = response.productDetails.first;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<bool> buyPremium() async {
    final product = _product;
    if (product == null || !_available) return false;

    final PurchaseParam param;
    if (product is GooglePlayProductDetails) {
      param = GooglePlayPurchaseParam(productDetails: product);
    } else {
      param = PurchaseParam(productDetails: product);
    }
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchases(
    List<PurchaseDetails> purchases,
    Future<void> Function(PurchaseDetails purchase) onVerified,
    void Function(Object error)? onError,
  ) async {
    for (final purchase in purchases) {
      if (purchase.productID != TtmPremiumConstants.playProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          onError?.call(purchase.error ?? Exception('결제 오류'));
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            await onVerified(purchase);
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
          } catch (e) {
            onError?.call(e);
          }
          break;
        case PurchaseStatus.canceled:
          break;
      }
    }
  }

  /// Android Play 구독 purchase token.
  static String? purchaseToken(PurchaseDetails purchase) {
    final data = purchase.verificationData;
    if (data.serverVerificationData.isNotEmpty) {
      return data.serverVerificationData;
    }
    return data.localVerificationData.isNotEmpty
        ? data.localVerificationData
        : null;
  }
}

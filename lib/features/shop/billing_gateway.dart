// Billing gateway Phase 3E : SDK Play derrière une interface injectable.
// Android uniquement (web/iOS/desktop => indisponible, sans toucher
// InAppPurchase.instance quand c'est évitable). Tests = fake gateway.
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'billing_models.dart';

/// Interface facturation (produit + achats). Impl prod = Google Play,
/// tests = fake en mémoire. Aucun Supabase ici.
abstract interface class BillingGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProducts(Set<String> ids);

  Future<bool> buyNonConsumable(
    ProductDetails product,
    String obfuscatedAccountId,
  );

  Future<void> restorePurchases(String obfuscatedAccountId);

  Future<void> completePurchase(PurchaseDetails purchase);

  Future<void> dispose();
}

/// Implémentation Google Play (one-time NON-CONSUMABLE uniquement).
class GooglePlayBillingGateway implements BillingGateway {
  final InAppPurchase _iap;

  GooglePlayBillingGateway({InAppPurchase? iap})
    : _iap = iap ?? InAppPurchase.instance;

  bool get _supported => isBillingSupportedNow;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream {
    if (!_supported) return const Stream.empty();
    return _iap.purchaseStream;
  }

  @override
  Future<bool> isAvailable() async {
    if (!_supported) return false;
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ProductDetailsResponse> queryProducts(Set<String> ids) async {
    if (!_supported || ids.isEmpty) {
      return ProductDetailsResponse(
        productDetails: [],
        notFoundIDs: ids.toList(),
      );
    }
    return _iap.queryProductDetails(ids);
  }

  @override
  Future<bool> buyNonConsumable(
    ProductDetails product,
    String obfuscatedAccountId,
  ) async {
    if (!_supported) return false;
    // One-time : jamais d'offerToken, jamais buyConsumable.
    final param = GooglePlayPurchaseParam(
      productDetails: product,
      applicationUserName: obfuscatedAccountId,
    );
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<void> restorePurchases(String obfuscatedAccountId) {
    if (!_supported) return Future.value();
    return _iap.restorePurchases(applicationUserName: obfuscatedAccountId);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) {
    return _iap.completePurchase(purchase);
  }

  @override
  Future<void> dispose() async {}
}

/// État disponibilité Play pour l'UI (sans effet de bord).
class BillingAvailability {
  final bool supported;
  final bool storeAvailable;
  const BillingAvailability({
    required this.supported,
    required this.storeAvailable,
  });

  bool get canQuery => supported && storeAvailable;
}

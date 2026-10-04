// Fakes billing Phase 3E (tests uniquement, jamais de Play/Supabase réel).
import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:brainwager/features/shop/billing_backend.dart';
import 'package:brainwager/features/shop/billing_gateway.dart';
import 'package:brainwager/features/shop/billing_models.dart';

PurchaseDetails fakePurchase({
  required String productId,
  required String token,
  required PurchaseStatus status,
  bool pendingComplete = false,
}) {
  final p = PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local-$token',
      serverVerificationData: token,
      source: 'app-store',
    ),
    transactionDate: '0',
    status: status,
  );
  p.pendingCompletePurchase = pendingComplete;
  return p;
}

ProductDetails fakeProduct(String id, {String price = '1,99 €'}) {
  return ProductDetails(
    id: id,
    title: 'Title $id',
    description: 'Desc $id',
    price: price,
    rawPrice: 1.99,
    currencyCode: 'EUR',
  );
}

class FakeBillingGateway implements BillingGateway {
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  int purchaseStreamAccessed = 0;
  int buyCalls = 0;
  String? lastBuyAccount;
  String? lastBuySku;
  ProductDetails? lastBuyProduct;
  int restoreCalls = 0;
  String? lastRestoreAccount;
  int completeCalls = 0;
  PurchaseDetails? lastCompleted;
  bool available = true;
  Map<String, ProductDetails> products = {};
  Set<String> notFound = {};

  @override
  Stream<List<PurchaseDetails>> get purchaseStream {
    purchaseStreamAccessed++;
    return _controller.stream;
  }

  void emit(PurchaseDetails p) => _controller.add([p]);
  void emitAll(List<PurchaseDetails> ps) => _controller.add(ps);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProducts(Set<String> ids) async {
    final found = <ProductDetails>[];
    final missing = <String>[];
    for (final id in ids) {
      final p = products[id];
      if (p != null) {
        found.add(p);
      } else if (notFound.contains(id)) {
        missing.add(id);
      } else {
        missing.add(id);
      }
    }
    return ProductDetailsResponse(productDetails: found, notFoundIDs: missing);
  }

  @override
  Future<bool> buyNonConsumable(
    ProductDetails product,
    String obfuscatedAccountId,
  ) async {
    buyCalls++;
    lastBuyProduct = product;
    lastBuySku = product.id;
    lastBuyAccount = obfuscatedAccountId;
    return true;
  }

  @override
  Future<void> restorePurchases(String obfuscatedAccountId) async {
    restoreCalls++;
    lastRestoreAccount = obfuscatedAccountId;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completeCalls++;
    lastCompleted = purchase;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class FakeBillingBackend implements BillingBackend {
  final List<String> modes = [];
  final List<Map<String, String>> calls = [];
  BillingBackendResult verifyResult = const BillingBackendResult(
    ok: true,
    active: true,
    acknowledged: true,
  );
  BillingBackendResult restoreResult = const BillingBackendResult(
    ok: true,
    active: true,
    acknowledged: true,
  );
  BillingBackendResult syncResult = const BillingBackendResult(
    ok: true,
    active: false,
    mode: 'sync',
  );
  Duration verifyDelay = Duration.zero;
  int verifyCalls = 0;
  int restoreCalls = 0;
  int syncCalls = 0;

  /// Quand non null, syncPurchases attend le gate (init bloquée en test).
  Completer<void>? syncGate;

  void blockSync() => syncGate = Completer<void>();

  void unblockSync() {
    syncGate?.complete();
    syncGate = null;
  }

  @override
  Future<BillingBackendResult> verifyPurchase({
    required String sku,
    required String purchaseToken,
  }) async {
    verifyCalls++;
    modes.add('verify');
    calls.add({'mode': 'verify', 'sku': sku, 'token': purchaseToken});
    if (verifyDelay > Duration.zero) await Future.delayed(verifyDelay);
    final r = verifyResult;
    return BillingBackendResult(
      ok: r.ok,
      active: r.active,
      sku: r.sku ?? sku,
      acknowledged: r.acknowledged,
      transferred: r.transferred,
      mode: r.mode ?? 'verify',
      errorCode: r.errorCode,
    );
  }

  @override
  Future<BillingBackendResult> restorePurchase({
    required String sku,
    required String purchaseToken,
  }) async {
    restoreCalls++;
    modes.add('restore');
    calls.add({'mode': 'restore', 'sku': sku, 'token': purchaseToken});
    if (verifyDelay > Duration.zero) await Future.delayed(verifyDelay);
    final r = restoreResult;
    return BillingBackendResult(
      ok: r.ok,
      active: r.active,
      sku: r.sku ?? sku,
      acknowledged: r.acknowledged,
      transferred: r.transferred,
      mode: r.mode ?? 'restore',
      errorCode: r.errorCode,
    );
  }

  @override
  Future<BillingBackendResult> syncPurchases() async {
    syncCalls++;
    modes.add('sync');
    final gate = syncGate;
    if (gate != null) await gate.future;
    return syncResult;
  }
}

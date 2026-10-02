// Tests controller billing Phase 3E (fakes, sans Play/Supabase).
// H/I/J/K/L/M/N/O/P/Q/R/S/T/U/V/W/Y/Z/AA.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:brainwager/features/shop/billing_controller.dart';
import 'package:brainwager/features/shop/billing_models.dart';

import 'fake_billing.dart';

const _userId = '00000000-0000-0000-0000-000000000000';
const _expectedHash =
    '12b9377cbe7e5c94e8a70d9d23929523d14afa954793130f8a3959c7b849aca8';

ProviderContainer _container({
  required FakeBillingGateway gateway,
  required FakeBillingBackend backend,
  Set<String> entitlements = const {},
  required void Function() onLoaderCall,
  String? userId = _userId,
}) {
  return ProviderContainer(
    overrides: [
      billingGatewayProvider.overrideWithValue(gateway),
      billingBackendProvider.overrideWithValue(backend),
      billingEntitlementsLoaderProvider.overrideWithValue(() async {
        onLoaderCall();
        return entitlements;
      }),
      billingCurrentUserIdProvider.overrideWithValue(() => userId),
    ],
  );
}

Future<void> _init(
  ProviderContainer c, {
  Set<String> ids = const {'pack_cinema', 'remove_ads'},
}) async {
  await c
      .read(billingControllerProvider.notifier)
      .ensureInitialized(productIds: ids);
  // Laisse le sync/readiness + produits se terminer.
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('H) controller souscrit une fois au purchase stream', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend();
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    expect(gateway.purchaseStreamAccessed, 1);
  });

  test('I) 2e init ne duplique pas l’abonnement', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend();
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    await c
        .read(billingControllerProvider.notifier)
        .ensureInitialized(productIds: {'pack_cinema'});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(gateway.purchaseStreamAccessed, 1);
  });

  test('J) purchased envoie mode=verify', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend();
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    backend.modes.clear();
    gateway.emit(
      fakePurchase(
        productId: 'pack_cinema',
        token: 'tok-j',
        status: PurchaseStatus.purchased,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(backend.modes, contains('verify'));
  });

  test('K) restored envoie mode=restore', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend();
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    backend.modes.clear();
    gateway.emit(
      fakePurchase(
        productId: 'pack_cinema',
        token: 'tok-k',
        status: PurchaseStatus.restored,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(backend.modes, contains('restore'));
  });

  test('L) pending ne débloque jamais', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend()
      ..verifyResult = BillingBackendResult.failure('purchase-pending');
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    final before = loaderCalls;
    gateway.emit(
      fakePurchase(
        productId: 'pack_cinema',
        token: 'tok-l',
        status: PurchaseStatus.pending,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final s = c.read(billingControllerProvider);
    expect(s.lastSuccessSku, isNull);
    expect(loaderCalls, before); // aucun refresh entitlements
    expect(gateway.completeCalls, 0);
  });

  test('M) canceled n’appelle jamais le backend verify', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend();
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    backend.modes.clear();
    backend.verifyCalls = 0;
    backend.restoreCalls = 0;
    gateway.emit(
      fakePurchase(
        productId: 'pack_cinema',
        token: 'tok-m',
        status: PurchaseStatus.canceled,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(backend.verifyCalls, 0);
    expect(backend.restoreCalls, 0);
    expect(c.read(billingControllerProvider).lastCanceled, isTrue);
  });

  test('N) error ne débloque jamais', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend();
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    final p = fakePurchase(
      productId: 'pack_cinema',
      token: 'tok-n',
      status: PurchaseStatus.error,
    );
    gateway.emit(p);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(billingControllerProvider).lastSuccessSku, isNull);
    expect(gateway.completeCalls, 0);
  });

  test('O) token vide rejeté côté client', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend();
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    backend.verifyCalls = 0;
    backend.restoreCalls = 0;
    gateway.emit(
      fakePurchase(
        productId: 'pack_cinema',
        token: '',
        status: PurchaseStatus.purchased,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(backend.verifyCalls, 0);
    expect(backend.restoreCalls, 0);
    expect(
      c.read(billingControllerProvider).lastErrorCode,
      'billing-invalid-purchase-data',
    );
  });

  test('P) backend active=false ne débloque jamais', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend()
      ..verifyResult = const BillingBackendResult(
        ok: true,
        active: false,
        sku: 'pack_cinema',
      );
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    final before = loaderCalls;
    gateway.emit(
      fakePurchase(
        productId: 'pack_cinema',
        token: 'tok-p',
        status: PurchaseStatus.purchased,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(billingControllerProvider).lastSuccessSku, isNull);
    expect(loaderCalls, before);
  });

  test('Q) ok/active déclenche refresh entitlements + succès', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend()
      ..verifyResult = const BillingBackendResult(
        ok: true,
        active: true,
        sku: 'pack_cinema',
        acknowledged: true,
        mode: 'verify',
      );
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      entitlements: {'pack_cinema'},
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    final before = loaderCalls;
    gateway.emit(
      fakePurchase(
        productId: 'pack_cinema',
        token: 'tok-q',
        status: PurchaseStatus.purchased,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(billingControllerProvider).lastSuccessSku, 'pack_cinema');
    expect(loaderCalls, greaterThan(before));
  });

  test('R) token en vol dupliqué ne vérifie qu’une fois', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend()
      ..verifyDelay = const Duration(milliseconds: 100);
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    backend.verifyCalls = 0;
    final p1 = fakePurchase(
      productId: 'pack_cinema',
      token: 'tok-r',
      status: PurchaseStatus.purchased,
    );
    final p2 = fakePurchase(
      productId: 'pack_cinema',
      token: 'tok-r',
      status: PurchaseStatus.purchased,
    );
    // Deux events stream distincts et concurrents (pas une seule liste).
    gateway.emit(p1);
    gateway.emit(p2);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(backend.verifyCalls, 1);
  });

  test('S) acknowledged=true ne rappelle pas completePurchase', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend()
      ..verifyResult = const BillingBackendResult(
        ok: true,
        active: true,
        sku: 'pack_cinema',
        acknowledged: true,
        mode: 'verify',
      );
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    gateway.emit(
      fakePurchase(
        productId: 'pack_cinema',
        token: 'tok-s',
        status: PurchaseStatus.purchased,
        pendingComplete: true,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(gateway.completeCalls, 0);
  });

  test('T) ack=false + actif + pendingComplete => completePurchase', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend()
      ..verifyResult = const BillingBackendResult(
        ok: true,
        active: true,
        sku: 'pack_cinema',
        acknowledged: false,
        mode: 'verify',
      );
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    gateway.emit(
      fakePurchase(
        productId: 'pack_cinema',
        token: 'tok-t',
        status: PurchaseStatus.purchased,
        pendingComplete: true,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(gateway.completeCalls, 1);
  });

  test('U) jamais de completePurchase avant succès serveur', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend()
      ..verifyResult = BillingBackendResult.failure('purchase-pending');
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    gateway.emit(
      fakePurchase(
        productId: 'pack_cinema',
        token: 'tok-u',
        status: PurchaseStatus.pending,
        pendingComplete: true,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(gateway.completeCalls, 0);
  });

  test('V) restore utilise le hash SHA-256 du compte', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend();
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    await c.read(billingControllerProvider.notifier).restore();
    expect(gateway.restoreCalls, 1);
    expect(gateway.lastRestoreAccount, _expectedHash);
  });

  test('W) buy utilise applicationUserName = hash SHA-256', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend();
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    await c.read(billingControllerProvider.notifier).buySku('pack_cinema');
    expect(gateway.buyCalls, 1);
    expect(gateway.lastBuyAccount, _expectedHash);
    expect(gateway.lastBuySku, 'pack_cinema');
  });

  test('Y) produit introuvable => Buy désactivé', () async {
    final gateway = FakeBillingGateway()..products = {};
    final backend = FakeBillingBackend();
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    // Produit absent de productsById et notFound.
    expect(c.read(billingControllerProvider).canBuy('pack_cinema'), isFalse);
  });

  test('Z) sync en échec => Buy désactivé', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend()
      ..syncResult = BillingBackendResult.failure('billing-not-configured');
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    final s = c.read(billingControllerProvider);
    expect(s.backendReady, isFalse);
    expect(s.canBuy('pack_cinema'), isFalse);
  });

  test('AA) sync OK => Buy activé pour produit configuré', () async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend()
      ..syncResult = const BillingBackendResult(
        ok: true,
        active: false,
        mode: 'sync',
      );
    int loaderCalls = 0;
    final c = _container(
      gateway: gateway,
      backend: backend,
      onLoaderCall: () => loaderCalls++,
    );
    addTearDown(c.dispose);
    await _init(c, ids: {'pack_cinema'});
    final s = c.read(billingControllerProvider);
    expect(s.backendReady, isTrue);
    expect(s.canBuy('pack_cinema'), isTrue);
  });
}

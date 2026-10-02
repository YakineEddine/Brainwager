// Tests readiness/entitlements Phase 3E v3 : échec fatal, set vide
// autoritaire, invalidation catalogue, gate UI Restore. A–L.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:brainwager/features/packs/pack.dart';
import 'package:brainwager/features/packs/pack_providers.dart';
import 'package:brainwager/features/shop/billing_controller.dart';
import 'package:brainwager/features/shop/billing_models.dart';
import 'package:brainwager/features/shop/shop_screen.dart';
import 'package:brainwager/l10n/app_localizations.dart';

import 'fake_billing.dart';

const _userId = '00000000-0000-0000-0000-000000000000';

const _premium = PackSummary(
  id: 'prem1',
  titleFr: 'Cinéma',
  titleEn: 'Cinema',
  titleAr: 'سينما',
  descFr: '',
  descEn: '',
  descAr: '',
  isOfficial: true,
  isPremium: true,
  priceSku: 'pack_cinema',
  shareCode: 'CINE01',
  ownerId: null,
  isHidden: false,
);

ProviderContainer _container({
  required FakeBillingGateway gateway,
  required FakeBillingBackend backend,
  required Future<Set<String>> Function() loader,
  String? userId = _userId,
  Future<PackCatalog> Function(Ref ref)? catalog,
}) {
  return ProviderContainer(
    overrides: [
      billingGatewayProvider.overrideWithValue(gateway),
      billingBackendProvider.overrideWithValue(backend),
      billingEntitlementsLoaderProvider.overrideWithValue(loader),
      billingCurrentUserIdProvider.overrideWithValue(() => userId),
      if (catalog != null) packCatalogProvider.overrideWith(catalog),
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
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  group('readiness controller (plateforme Android forcée)', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('A) backendReady vrai après sync réussi', () async {
      final gateway = FakeBillingGateway()
        ..products = {'pack_cinema': fakeProduct('pack_cinema')};
      final backend = FakeBillingBackend();
      final c = _container(
        gateway: gateway,
        backend: backend,
        loader: () async => {},
      );
      addTearDown(c.dispose);
      await _init(c);
      expect(c.read(billingControllerProvider).backendReady, isTrue);
    });

    test('B) verify google-play-permission-denied referme readiness', () async {
      final gateway = FakeBillingGateway()
        ..products = {'pack_cinema': fakeProduct('pack_cinema')};
      final backend = FakeBillingBackend()
        ..verifyResult = BillingBackendResult.failure(
          'google-play-permission-denied',
        );
      final c = _container(
        gateway: gateway,
        backend: backend,
        loader: () async => {},
      );
      addTearDown(c.dispose);
      await _init(c);
      expect(c.read(billingControllerProvider).backendReady, isTrue);
      gateway.emit(
        fakePurchase(
          productId: 'pack_cinema',
          token: 'tok-b',
          status: PurchaseStatus.purchased,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final s = c.read(billingControllerProvider);
      expect(s.backendReady, isFalse);
      expect(s.backendErrorCode, 'google-play-permission-denied');
    });

    test('C) verify billing-database-error referme readiness', () async {
      final gateway = FakeBillingGateway()
        ..products = {'pack_cinema': fakeProduct('pack_cinema')};
      final backend = FakeBillingBackend()
        ..verifyResult = BillingBackendResult.failure('billing-database-error');
      final c = _container(
        gateway: gateway,
        backend: backend,
        loader: () async => {},
      );
      addTearDown(c.dispose);
      await _init(c);
      gateway.emit(
        fakePurchase(
          productId: 'pack_cinema',
          token: 'tok-c',
          status: PurchaseStatus.purchased,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(billingControllerProvider).backendReady, isFalse);
    });

    test('D) purchase-account-mismatch ne coupe PAS la readiness', () async {
      final gateway = FakeBillingGateway()
        ..products = {'pack_cinema': fakeProduct('pack_cinema')};
      final backend = FakeBillingBackend()
        ..verifyResult = BillingBackendResult.failure(
          'purchase-account-mismatch',
        );
      final c = _container(
        gateway: gateway,
        backend: backend,
        loader: () async => {},
      );
      addTearDown(c.dispose);
      await _init(c);
      gateway.emit(
        fakePurchase(
          productId: 'pack_cinema',
          token: 'tok-d',
          status: PurchaseStatus.purchased,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final s = c.read(billingControllerProvider);
      expect(s.backendReady, isTrue);
      expect(s.lastErrorCode, 'purchase-account-mismatch');
    });

    test('E) après échec fatal canBuy() == false', () async {
      final gateway = FakeBillingGateway()
        ..products = {'pack_cinema': fakeProduct('pack_cinema')};
      final backend = FakeBillingBackend()
        ..verifyResult = BillingBackendResult.failure(
          'google-play-permission-denied',
        );
      final c = _container(
        gateway: gateway,
        backend: backend,
        loader: () async => {},
      );
      addTearDown(c.dispose);
      await _init(c);
      expect(c.read(billingControllerProvider).canBuy('pack_cinema'), isTrue);
      gateway.emit(
        fakePurchase(
          productId: 'pack_cinema',
          token: 'tok-e',
          status: PurchaseStatus.purchased,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(billingControllerProvider).canBuy('pack_cinema'), isFalse);
    });

    test('F) refresh réussi rouvre backendReady', () async {
      final gateway = FakeBillingGateway()
        ..products = {'pack_cinema': fakeProduct('pack_cinema')};
      final backend = FakeBillingBackend()
        ..verifyResult = BillingBackendResult.failure(
          'google-play-permission-denied',
        );
      final c = _container(
        gateway: gateway,
        backend: backend,
        loader: () async => {},
      );
      addTearDown(c.dispose);
      await _init(c);
      gateway.emit(
        fakePurchase(
          productId: 'pack_cinema',
          token: 'tok-f',
          status: PurchaseStatus.purchased,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(billingControllerProvider).backendReady, isFalse);
      await c.read(billingControllerProvider.notifier).refresh();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(billingControllerProvider).backendReady, isTrue);
    });

    test(
      'G) reload vide => entitlementsLoaded vrai, set vide autoritaire',
      () async {
        final gateway = FakeBillingGateway()
          ..products = {'pack_cinema': fakeProduct('pack_cinema')};
        final backend = FakeBillingBackend();
        final c = _container(
          gateway: gateway,
          backend: backend,
          loader: () async => <String>{},
        );
        addTearDown(c.dispose);
        await _init(c);
        final s = c.read(billingControllerProvider);
        expect(s.entitlementsLoaded, isTrue);
        expect(s.activeEntitlements, isEmpty);
      },
    );

    test('I) sync réussi invalide le catalogue', () async {
      final gateway = FakeBillingGateway()
        ..products = {'pack_cinema': fakeProduct('pack_cinema')};
      final backend = FakeBillingBackend();
      int builds = 0;
      final c = _container(
        gateway: gateway,
        backend: backend,
        loader: () async => <String>{},
        catalog: (ref) async {
          builds++;
          return const PackCatalog(packs: [], activeEntitlements: {});
        },
      );
      addTearDown(c.dispose);
      c.listen(packCatalogProvider, (_, _) {});
      await _init(c);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Build initial + rebuild après invalidation du sync réussi.
      expect(builds, greaterThanOrEqualTo(2));
    });

    test('J) échec loader ne remplace PAS un set chargé par vide', () async {
      var fail = false;
      final gateway = FakeBillingGateway()
        ..products = {'pack_cinema': fakeProduct('pack_cinema')};
      final backend = FakeBillingBackend();
      final c = _container(
        gateway: gateway,
        backend: backend,
        loader: () async {
          if (fail) throw Exception('billing-network-error');
          return {'pack_cinema'};
        },
      );
      addTearDown(c.dispose);
      await _init(c);
      expect(c.read(billingControllerProvider).activeEntitlements, {
        'pack_cinema',
      });
      fail = true;
      await c.read(billingControllerProvider.notifier).refresh();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final s = c.read(billingControllerProvider);
      expect(s.activeEntitlements, {'pack_cinema'});
      expect(s.entitlementsLoaded, isTrue);
    });
  }); // group readiness controller

  testWidgets('H) set vide autoritaire : pas de Owned stale', (tester) async {
    final gateway = FakeBillingGateway()
      ..products = {
        'pack_cinema': fakeProduct('pack_cinema', price: '2,99 €'),
        'remove_ads': fakeProduct('remove_ads', price: '0,99 €'),
      };
    final backend = FakeBillingBackend();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Catalogue stale : pack_cinema encore vu owned.
          packCatalogProvider.overrideWith(
            (ref) => Future.value(
              const PackCatalog(
                packs: [_premium],
                activeEntitlements: {'pack_cinema'},
              ),
            ),
          ),
          billingGatewayProvider.overrideWithValue(gateway),
          billingBackendProvider.overrideWithValue(backend),
          // Serveur autoritaire : vide (refund).
          billingEntitlementsLoaderProvider.overrideWithValue(
            () async => <String>{},
          ),
          billingCurrentUserIdProvider.overrideWithValue(() => _userId),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('fr'), Locale('ar')],
          home: ShopScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Owned'), findsNothing);
  });

  testWidgets('K) backendReady=false : Restore désactivé', (tester) async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend()
      ..syncResult = BillingBackendResult.failure('billing-not-configured');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packCatalogProvider.overrideWith(
            (ref) => Future.value(
              const PackCatalog(packs: [_premium], activeEntitlements: {}),
            ),
          ),
          billingGatewayProvider.overrideWithValue(gateway),
          billingBackendProvider.overrideWithValue(backend),
          billingEntitlementsLoaderProvider.overrideWithValue(
            () async => <String>{},
          ),
          billingCurrentUserIdProvider.overrideWithValue(() => _userId),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('fr'), Locale('ar')],
          home: ShopScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final restore = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Restore purchases'),
    );
    expect(restore.onPressed, isNull);
    // Refresh reste disponible pour retenter la readiness.
    final refresh = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Refresh purchases'),
    );
    expect(refresh.onPressed, isNotNull);
  });

  testWidgets('L) backendReady=true : Restore activé', (tester) async {
    final gateway = FakeBillingGateway()
      ..products = {
        'pack_cinema': fakeProduct('pack_cinema', price: '2,99 €'),
        'remove_ads': fakeProduct('remove_ads', price: '0,99 €'),
      };
    final backend = FakeBillingBackend();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packCatalogProvider.overrideWith(
            (ref) => Future.value(
              const PackCatalog(packs: [_premium], activeEntitlements: {}),
            ),
          ),
          billingGatewayProvider.overrideWithValue(gateway),
          billingBackendProvider.overrideWithValue(backend),
          billingEntitlementsLoaderProvider.overrideWithValue(
            () async => <String>{},
          ),
          billingCurrentUserIdProvider.overrideWithValue(() => _userId),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('fr'), Locale('ar')],
          home: ShopScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final restore = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Restore purchases'),
    );
    expect(restore.onPressed, isNotNull);
  });
}

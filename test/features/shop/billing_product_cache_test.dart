// Tests cache produits Phase 3E : l'union des IDs demandés ne rétrécit
// jamais, éviction notFound explicite, une seule souscription. A–E.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/shop/billing_controller.dart';

import 'fake_billing.dart';

const _userId = '00000000-0000-0000-0000-000000000000';

ProviderContainer _container({
  required FakeBillingGateway gateway,
  required FakeBillingBackend backend,
}) {
  return ProviderContainer(
    overrides: [
      billingGatewayProvider.overrideWithValue(gateway),
      billingBackendProvider.overrideWithValue(backend),
      billingEntitlementsLoaderProvider.overrideWithValue(
        () async => <String>{},
      ),
      billingCurrentUserIdProvider.overrideWithValue(() => _userId),
    ],
  );
}

Future<void> _init(ProviderContainer c, Set<String> ids) async {
  await c
      .read(billingControllerProvider.notifier)
      .ensureInitialized(productIds: ids);
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  group('cache produits (plateforme Android forcée)', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('A) requête étroite après large : le cache garde tout', () async {
      final gateway = FakeBillingGateway()
        ..products = {
          'pack_a': fakeProduct('pack_a'),
          'pack_b': fakeProduct('pack_b'),
          'remove_ads': fakeProduct('remove_ads'),
        };
      final backend = FakeBillingBackend();
      final c = _container(gateway: gateway, backend: backend);
      addTearDown(c.dispose);
      await _init(c, {'pack_a', 'pack_b', 'remove_ads'});
      await _init(c, {'pack_a'});
      final products = c.read(billingControllerProvider).productsById;
      expect(products.keys, containsAll(['pack_a', 'pack_b', 'remove_ads']));
    });

    test('B) requête large après étroite : tout est chargé', () async {
      final gateway = FakeBillingGateway()
        ..products = {
          'pack_a': fakeProduct('pack_a'),
          'pack_b': fakeProduct('pack_b'),
          'remove_ads': fakeProduct('remove_ads'),
        };
      final backend = FakeBillingBackend();
      final c = _container(gateway: gateway, backend: backend);
      addTearDown(c.dispose);
      await _init(c, {'pack_a'});
      await _init(c, {'pack_a', 'pack_b', 'remove_ads'});
      final products = c.read(billingControllerProvider).productsById;
      expect(products.keys, containsAll(['pack_a', 'pack_b', 'remove_ads']));
    });

    test('C) inits concurrents : l’union finale l’emporte', () async {
      final gateway = FakeBillingGateway()
        ..products = {
          'pack_a': fakeProduct('pack_a'),
          'pack_b': fakeProduct('pack_b'),
          'remove_ads': fakeProduct('remove_ads'),
        };
      final backend = FakeBillingBackend();
      final c = _container(gateway: gateway, backend: backend);
      addTearDown(c.dispose);
      final notifier = c.read(billingControllerProvider.notifier);
      final f1 = notifier.ensureInitialized(
        productIds: {'pack_a', 'remove_ads'},
      );
      final f2 = notifier.ensureInitialized(
        productIds: {'pack_b', 'remove_ads'},
      );
      await Future.wait([f1, f2]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final products = c.read(billingControllerProvider).productsById;
      expect(products.keys, containsAll(['pack_a', 'pack_b', 'remove_ads']));
    });

    test('D) notFound explicite évince le produit du cache', () async {
      final gateway = FakeBillingGateway()
        ..products = {
          'pack_a': fakeProduct('pack_a'),
          'pack_b': fakeProduct('pack_b'),
        };
      final backend = FakeBillingBackend();
      final c = _container(gateway: gateway, backend: backend);
      addTearDown(c.dispose);
      await _init(c, {'pack_a', 'pack_b'});
      expect(
        c.read(billingControllerProvider).productsById.keys,
        contains('pack_b'),
      );
      // pack_b disparaît du Play Store : la requête le déclare notFound.
      gateway.products.remove('pack_b');
      await _init(c, {'pack_b'});
      final s = c.read(billingControllerProvider);
      expect(s.productsById.keys, contains('pack_a'));
      expect(s.productsById.keys, isNot(contains('pack_b')));
      expect(s.notFoundIds, contains('pack_b'));
    });

    test('E) une seule souscription malgré les requêtes multiples', () async {
      final gateway = FakeBillingGateway()
        ..products = {'pack_a': fakeProduct('pack_a')};
      final backend = FakeBillingBackend();
      final c = _container(gateway: gateway, backend: backend);
      addTearDown(c.dispose);
      await _init(c, {'pack_a'});
      await _init(c, {'pack_a', 'pack_b'});
      await _init(c, {'pack_a'});
      expect(gateway.purchaseStreamAccessed, 1);
    });
  });
}

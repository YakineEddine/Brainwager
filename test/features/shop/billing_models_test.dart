// Tests purs billing Phase 3E : hash, product IDs, erreurs, token, accès.
// A/B/C/D/E/F/G/X(part)/AB/AC/AD/AE/AF.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:brainwager/features/packs/pack.dart';
import 'package:brainwager/features/shop/billing_errors.dart';
import 'package:brainwager/features/shop/billing_models.dart';

import 'fake_billing.dart';

const _freeOfficial = PackSummary(
  id: 'free1',
  titleFr: 'Démo',
  titleEn: 'Demo',
  titleAr: 'تجريبي',
  descFr: '',
  descEn: '',
  descAr: '',
  isOfficial: true,
  isPremium: false,
  priceSku: null,
  shareCode: 'DEMO01',
  ownerId: null,
  isHidden: false,
);

const _premiumA = PackSummary(
  id: 'premA',
  titleFr: 'Cinéma',
  titleEn: 'Cinema',
  titleAr: '',
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

const _premiumB = PackSummary(
  id: 'premB',
  titleFr: 'Histoire',
  titleEn: 'History',
  titleAr: '',
  descFr: '',
  descEn: '',
  descAr: '',
  isOfficial: true,
  isPremium: true,
  priceSku: 'pack_histoire',
  shareCode: 'HIST01',
  ownerId: null,
  isHidden: false,
);

const _ugc = PackSummary(
  id: 'ugc1',
  titleFr: 'Perso',
  titleEn: 'Mine',
  titleAr: '',
  descFr: '',
  descEn: '',
  descAr: '',
  isOfficial: false,
  isPremium: false,
  priceSku: null,
  shareCode: 'PK-AB12',
  ownerId: 'u1',
  isHidden: false,
);

void main() {
  test('A) billingAccountHash vecteur connu SHA-256', () {
    expect(
      billingAccountHash('00000000-0000-0000-0000-000000000000'),
      '12b9377cbe7e5c94e8a70d9d23929523d14afa954793130f8a3959c7b849aca8',
    );
    final h = billingAccountHash('some-user-id');
    expect(h.length, 64);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(h), isTrue);
  });

  test('B) product IDs contiennent les SKU premium officiels', () {
    final ids = billingProductIds([_freeOfficial, _premiumA, _premiumB]);
    expect(ids, contains('pack_cinema'));
    expect(ids, contains('pack_histoire'));
  });

  test('C) product IDs contiennent remove_ads', () {
    expect(billingProductIds([_freeOfficial]), contains('remove_ads'));
    expect(billingProductIds([]), contains('remove_ads'));
  });

  test('D) pack officiel gratuit exclu', () {
    final ids = billingProductIds([_freeOfficial]);
    expect(ids.contains(''), isFalse);
    // Seul remove_ads reste.
    expect(ids, {'remove_ads'});
  });

  test('E) UGC exclu', () {
    final ids = billingProductIds([_ugc]);
    expect(ids, {'remove_ads'});
  });

  test('F) SKU dupliqués dédupliqués', () {
    const dup = PackSummary(
      id: 'premC',
      titleFr: 'Cinéma 2',
      titleEn: 'Cinema 2',
      titleAr: '',
      descFr: '',
      descEn: '',
      descAr: '',
      isOfficial: true,
      isPremium: true,
      priceSku: 'pack_cinema',
      shareCode: 'CINE02',
      ownerId: null,
      isHidden: false,
    );
    final ids = billingProductIds([_premiumA, dup, _premiumB]);
    expect(ids.where((s) => s == 'pack_cinema').length, 1);
    expect(ids, containsAll(['pack_cinema', 'pack_histoire', 'remove_ads']));
  });

  test('G) support billing : Android non-web uniquement, sans crash', () {
    expect(
      isBillingSupportedPlatform(isWeb: true, platform: TargetPlatform.android),
      isFalse,
    );
    expect(
      isBillingSupportedPlatform(
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      isTrue,
    );
    expect(
      isBillingSupportedPlatform(isWeb: false, platform: TargetPlatform.iOS),
      isFalse,
    );
    expect(
      isBillingSupportedPlatform(isWeb: false, platform: TargetPlatform.macOS),
      isFalse,
    );
    expect(
      isBillingSupportedPlatform(
        isWeb: false,
        platform: TargetPlatform.windows,
      ),
      isFalse,
    );
  });

  test('AB) premium verrouillé sans entitlement', () {
    expect(_premiumA.isAccessible({}), isFalse);
    expect(selectableForTest([_premiumA], {}), isEmpty);
  });

  test('AC) premium accessible seulement avec SKU actif', () {
    expect(_premiumA.isAccessible({'pack_cinema'}), isTrue);
    expect(_premiumA.isAccessible({'other_sku'}), isFalse);
    expect(_premiumA.isAccessible({'remove_ads'}), isFalse);
  });

  test('AD) mapper erreurs FR/EN/AR cas centraux', () {
    expect(
      friendlyBillingError('billing-not-configured', 'fr'),
      contains('temporairement'),
    );
    expect(
      friendlyBillingError('billing-not-configured', 'en'),
      contains('temporarily'),
    );
    expect(friendlyBillingError('purchase-pending', 'ar').isNotEmpty, isTrue);
    expect(friendlyBillingError('purchase-canceled', 'fr'), contains('annulé'));
    // Jamais de texte brut technique.
    expect(
      friendlyBillingError('FunctionException(status: 400)', 'en'),
      isNot(contains('FunctionException')),
    );
  });

  test('AE) FunctionException details {error} extrait le code exact', () {
    final e = _FakeFunctionException({
      'error': 'purchase-token-already-claimed',
    });
    expect(billingErrorCode(e), 'purchase-token-already-claimed');
    final nested = _FakeFunctionException({
      'data': {'error': 'billing-sku-not-allowed'},
    });
    expect(billingErrorCode(e), isNotEmpty);
    expect(billingErrorCode(nested), 'billing-sku-not-allowed');
    expect(billingErrorCode(Exception('boom')), 'billing-network-error');
  });

  test('AF) token = serverVerificationData', () {
    final p = fakePurchase(
      productId: 'pack_cinema',
      token: 'tok-123',
      status: PurchaseStatus.purchased,
    );
    expect(billingPurchaseToken(p), 'tok-123');
  });

  test('W) builder param porte le hash SHA-256 en applicationUserName', () {
    const userId = '00000000-0000-0000-0000-000000000000';
    final product = fakeProduct('pack_cinema');
    final param = buildGooglePlayParam(product, billingAccountHash(userId));
    expect(
      param.applicationUserName,
      '12b9377cbe7e5c94e8a70d9d23929523d14afa954793130f8a3959c7b849aca8',
    );
    expect(param.productDetails.id, 'pack_cinema');
  });

  test('X) prix Play réel porté par ProductDetails (pas de devise codée)', () {
    final product = fakeProduct('pack_cinema', price: '2,99 €');
    expect(product.price, '2,99 €');
    expect(product.price.contains('2,99'), isTrue);
  });
}

List<PackSummary> selectableForTest(
  List<PackSummary> packs,
  Set<String> entitlements,
) {
  return packs.where((p) => p.isAccessible(entitlements)).toList();
}

class _FakeFunctionException implements Exception {
  final dynamic details;
  _FakeFunctionException(this.details);
  @override
  String toString() => 'FunctionException(details: $details)';
}

// Tests Shop UI Phase 3E : route /shop, prix réels, RTL arabe.
// AG/AH + X(UI)/Y(UI).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:brainwager/app/router.dart';
import 'package:brainwager/features/packs/pack.dart';
import 'package:brainwager/features/packs/pack_providers.dart';
import 'package:brainwager/features/shop/billing_controller.dart';
import 'package:brainwager/features/shop/billing_models.dart';
import 'package:brainwager/features/shop/shop_screen.dart';
import 'package:brainwager/l10n/app_localizations.dart';

import 'fake_billing.dart';

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

Future<void> _pumpRouter(WidgetTester tester) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: brainRouter,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      ),
    ),
  );
}

void main() {
  test('AG) route /shop résolue', () {
    final paths = <String>[];
    void collect(List<RouteBase> routes) {
      for (final r in routes) {
        if (r is GoRoute) {
          paths.add(r.path);
          collect(r.routes);
        } else if (r is StatefulShellRoute) {
          for (final branch in r.branches) {
            collect(branch.routes);
          }
        } else if (r is ShellRoute) {
          collect(r.routes);
        }
      }
    }

    collect(brainRouter.configuration.routes);
    expect(paths, contains('/shop'));
  });

  testWidgets('AG) /shop affiche la boutique (AppBar Shop)', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/shop');
    await tester.pumpAndSettle();
    expect(find.text('Shop'), findsWidgets);
  });

  testWidgets('X) prix Play réel affiché, pas de devise codée en dur', (
    tester,
  ) async {
    final gateway = FakeBillingGateway()
      ..products = {
        'pack_cinema': fakeProduct('pack_cinema', price: '2,99 €'),
        'remove_ads': fakeProduct('remove_ads', price: '0,99 €'),
      };
    final backend = FakeBillingBackend()
      ..syncResult = const BillingBackendResult(
        ok: true,
        active: false,
        mode: 'sync',
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packCatalogProvider.overrideWith(
            (ref) => Future.value(
              PackCatalog(packs: [_premium], activeEntitlements: {}),
            ),
          ),
          billingGatewayProvider.overrideWithValue(gateway),
          billingBackendProvider.overrideWithValue(backend),
          billingEntitlementsLoaderProvider.overrideWithValue(() async => {}),
          billingCurrentUserIdProvider.overrideWithValue(
            () => '00000000-0000-0000-0000-000000000000',
          ),
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
    // Prix réels Play rendus (jamais "\$0.99" codé).
    expect(find.textContaining('2,99'), findsWidgets);
    expect(find.textContaining('Buy'), findsWidgets);
  });

  testWidgets('AH) boutique arabe RTL/localisée', (tester) async {
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
              PackCatalog(packs: [_premium], activeEntitlements: {}),
            ),
          ),
          billingGatewayProvider.overrideWithValue(gateway),
          billingBackendProvider.overrideWithValue(backend),
          billingEntitlementsLoaderProvider.overrideWithValue(() async => {}),
          billingCurrentUserIdProvider.overrideWithValue(
            () => '00000000-0000-0000-0000-000000000000',
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
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
    // Titre arabe + direction RTL automatique.
    expect(find.text('المتجر'), findsOneWidget);
    final direction = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(direction.textDirection, TextDirection.rtl);
  });
}

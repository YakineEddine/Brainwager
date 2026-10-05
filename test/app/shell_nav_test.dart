// Tests coquille light-shell : 4 destinations, sélection par route,
// absence hors shell, RTL, responsive, gating billing intact.
// Aucune logique métier modifiée ici, que de la navigation.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/app/router.dart';
import 'package:brainwager/app/theme.dart';
import 'package:brainwager/features/packs/pack.dart';
import 'package:brainwager/features/packs/pack_providers.dart';
import 'package:brainwager/features/profile/profile_screen.dart';
import 'package:brainwager/features/shop/billing_controller.dart';
import 'package:brainwager/features/shop/billing_models.dart';
import 'package:brainwager/features/shop/shop_screen.dart';
import 'package:brainwager/l10n/app_localizations.dart';

import '../features/shop/fake_billing.dart';

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

Future<void> _pumpRouter(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        locale: locale,
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

int _selectedIndex(WidgetTester tester) {
  return tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;
}

void main() {
  testWidgets('A) shell : 4 destinations', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/home');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  testWidgets('B) /home sélectionne Home', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/home');
    await tester.pumpAndSettle();
    expect(_selectedIndex(tester), 0);
  });

  testWidgets('C) /packs sélectionne Packs', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/packs');
    await tester.pumpAndSettle();
    expect(_selectedIndex(tester), 1);
  });

  testWidgets('D) /shop sélectionne Shop', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/shop');
    await tester.pumpAndSettle();
    expect(_selectedIndex(tester), 2);
  });

  testWidgets('E) /profile sélectionne Profile', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/profile');
    await tester.pumpAndSettle();
    expect(_selectedIndex(tester), 3);
  });

  testWidgets('F) /game/:id sans navbar', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/game/some-id');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('G) /create et /join sans navbar', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/create');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    brainRouter.go('/join');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('H) deep link pack intact, sans navbar', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/packs/shared/PK-AB12');
    await tester.pumpAndSettle();
    expect(find.text('Shared pack'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('I) navbar arabe RTL', (tester) async {
    await _pumpRouter(tester, locale: const Locale('ar'));
    brainRouter.go('/home');
    await tester.pumpAndSettle();
    expect(find.text('الرئيسية'), findsOneWidget);
    // المتجر : carte Home + onglet navbar (même libellé, deux endroits).
    expect(find.text('المتجر'), findsWidgets);
    final direction = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(direction.textDirection, TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('J) 320/360px + 1.3x : shell sans overflow', (tester) async {
    for (final width in [320.0, 360.0]) {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1.0;
      for (final scale in [1.0, 1.3]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final path in ['/home', '/packs', '/shop', '/profile']) {
          await _pumpRouter(tester);
          brainRouter.go(path);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  test('K) thème clair', () {
    expect(buildBrainTheme().brightness, Brightness.light);
  });

  testWidgets('L/M) Shop stable avant init, init unique', (tester) async {
    final gateway = FakeBillingGateway()
      ..products = {'pack_cinema': fakeProduct('pack_cinema')};
    final backend = FakeBillingBackend()..blockSync();
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
    await tester.pump();
    await tester.pump();
    // Page visible immédiatement : AppBar + actions, pas de spinner global.
    expect(find.text('Shop'), findsWidgets);
    expect(find.text('Restore purchases'), findsOneWidget);
    // Un seul abonnement malgré les rebuilds.
    expect(gateway.purchaseStreamAccessed, 1);
    expect(tester.takeException(), isNull);
    backend.unblockSync();
  });

  testWidgets('N/O) Buy + Restore désactivés si backend pas prêt', (
    tester,
  ) async {
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
    final buys = tester.widgetList<ElevatedButton>(find.byType(ElevatedButton));
    expect(buys, isNotEmpty);
    for (final buy in buys) {
      expect(buy.onPressed, isNull);
    }
    final restore = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Restore purchases'),
    );
    expect(restore.onPressed, isNull);
  });

  testWidgets('A-D) croissance SKU pendant init : un seul suivi union', (
    tester,
  ) async {
    const packA = PackSummary(
      id: 'a',
      titleFr: 'A',
      titleEn: 'A',
      titleAr: 'أ',
      descFr: '',
      descEn: '',
      descAr: '',
      isOfficial: true,
      isPremium: true,
      priceSku: 'pack_a',
      shareCode: 'A001',
      ownerId: null,
      isHidden: false,
    );
    const packB = PackSummary(
      id: 'b',
      titleFr: 'B',
      titleEn: 'B',
      titleAr: 'ب',
      descFr: '',
      descEn: '',
      descAr: '',
      isOfficial: true,
      isPremium: true,
      priceSku: 'pack_b',
      shareCode: 'B001',
      ownerId: null,
      isHidden: false,
    );
    final gateway = FakeBillingGateway()
      ..products = {
        'pack_a': fakeProduct('pack_a'),
        'pack_b': fakeProduct('pack_b'),
        'remove_ads': fakeProduct('remove_ads'),
      };
    final backend = FakeBillingBackend()..blockSync();
    final packsState = StateProvider<List<PackSummary>>((ref) => [packA]);
    final container = ProviderContainer(
      overrides: [
        packsState,
        packCatalogProvider.overrideWith((ref) {
          final packs = ref.watch(packsState);
          return Future.value(
            PackCatalog(packs: packs, activeEntitlements: {}),
          );
        }),
        billingGatewayProvider.overrideWithValue(gateway),
        billingBackendProvider.overrideWithValue(backend),
        billingEntitlementsLoaderProvider.overrideWithValue(
          () async => <String>{},
        ),
        billingCurrentUserIdProvider.overrideWithValue(
          () => '00000000-0000-0000-0000-000000000000',
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(backend.unblockSync);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
    await tester.pump();
    await tester.pump();
    // A. init démarrée avec SKU A (+ remove_ads système).
    expect(gateway.queriedIds.any((ids) => ids.contains('pack_a')), isTrue);
    // B. croissance vers A+B pendant le vol (sync bloqué).
    container.read(packsState.notifier).state = [packA, packB];
    await tester.pump();
    await tester.pump();
    // C. après fin du premier vol : un suivi avec l'union complète.
    backend.unblockSync();
    await tester.pumpAndSettle();
    expect(gateway.queriedIds.length, 2);
    expect(
      gateway.queriedIds.last,
      containsAll(['pack_a', 'pack_b', 'remove_ads']),
    );
    // D. rebuild ordinaire : aucun troisième appel.
    container.invalidate(packCatalogProvider);
    await tester.pumpAndSettle();
    expect(gateway.queriedIds.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('avatar FR/AR : sémantique localisée', (tester) async {
    Future<String?> iconLabel(Locale locale) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget<Icon>(find.byIcon(Icons.person)).semanticLabel;
    }

    expect(await iconLabel(const Locale('fr')), 'Avatar');
    expect(await iconLabel(const Locale('ar')), 'الصورة الرمزية');
    expect(await iconLabel(const Locale('en')), 'Avatar');
  });
}

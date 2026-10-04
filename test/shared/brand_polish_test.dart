// Tests polish marque Phase brand-polish : hiérarchie, invariants visuels
// et comportementaux. Aucune logique métier modifiée ici, que du visuel.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:brainwager/app/router.dart';
import 'package:brainwager/features/packs/pack.dart';
import 'package:brainwager/features/packs/pack_import_screen.dart';
import 'package:brainwager/features/packs/pack_providers.dart';
import 'package:brainwager/features/packs/pack_screens.dart';
import 'package:brainwager/features/packs/report_pack_dialog.dart';
import 'package:brainwager/app/theme.dart' show BrainColors;
import 'package:brainwager/l10n/app_localizations.dart';
import 'package:brainwager/shared/widgets/brain_card.dart';
import 'package:brainwager/shared/widgets/brand.dart';
import 'package:brainwager/shared/widgets/entrance.dart';

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
  test('B/G) routes packs et partagé inchangées', () {
    final paths = <String>[];
    void collect(List<RouteBase> routes) {
      for (final r in routes) {
        if (r is GoRoute) {
          paths.add(r.path);
          collect(r.routes);
        }
      }
    }

    collect(brainRouter.configuration.routes);
    expect(paths, contains('/packs'));
    expect(paths, contains('/packs/:id'));
    expect(paths, contains('/packs/import'));
    expect(paths, contains('/packs/shared/:code'));
    expect(paths, contains('/shop'));
  });

  testWidgets('A) Home : Create/Join naviguent vers leurs routes', (
    tester,
  ) async {
    await _pumpRouter(tester);
    brainRouter.go('/home');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create game'));
    await tester.pumpAndSettle();
    expect(find.text('Nickname'), findsWidgets);
    brainRouter.go('/home');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join game'));
    await tester.pumpAndSettle();
    expect(find.text('Code (4-6)'), findsOneWidget);
  });

  testWidgets('D) premium verrouillé : badge Locked, gating intact', (
    tester,
  ) async {
    expect(_premium.isAccessible({}), isFalse);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packCatalogProvider.overrideWith(
            (ref) => Future.value(
              const PackCatalog(packs: [_premium], activeEntitlements: {}),
            ),
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
          home: PacksScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
  });

  testWidgets('E) premium possédé : Premium sans Locked', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packCatalogProvider.overrideWith(
            (ref) => Future.value(
              const PackCatalog(
                packs: [_premium],
                activeEntitlements: {'pack_cinema'},
              ),
            ),
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
          home: PacksScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Locked'), findsNothing);
  });

  testWidgets('F) éditeur UGC intact : création + questions', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/packs/edit');
    await tester.pumpAndSettle();
    expect(find.text('Create a pack'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsWidgets);
  });

  testWidgets('H) import arabe : RTL localisé', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('fr'), Locale('ar')],
          home: PackImportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('استيراد حزمة'), findsOneWidget);
    final direction = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(direction.textDirection, TextDirection.rtl);
  });

  test('I) validation signalement inchangée', () {
    expect(validateReportReason('ab'), 'invalid-report-reason');
    expect(validateReportReason('bonne raison de signalement'), isNull);
  });

  testWidgets('J) marque : repli wordmark sans asset', (tester) async {
    for (final variant in BrainBrandVariant.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BrainBrand(variant: variant)),
        ),
      );
      await tester.pump();
      // Aucun asset déposé : le repli texte/icone s'affiche, sans crash.
      expect(find.text('B'), findsWidgets);
    }
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BrainBrand(variant: BrainBrandVariant.full)),
      ),
    );
    expect(find.text('BRAINWAGER'), findsOneWidget);
  });

  Future<void> pumpHomeNarrow(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
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
    brainRouter.go('/home');
    await tester.pumpAndSettle();
  }

  testWidgets('R1) Home 320px EN : pas de overflow', (tester) async {
    await pumpHomeNarrow(tester);
    expect(find.text('Create game'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('R2) Home 320px FR : Boutique visible, pas de overflow', (
    tester,
  ) async {
    await pumpHomeNarrow(tester, locale: const Locale('fr'));
    expect(find.text('Boutique'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('R3) Home 320px AR RTL : secondaires visibles', (tester) async {
    await pumpHomeNarrow(tester, locale: const Locale('ar'));
    expect(find.text('الحزم'), findsOneWidget);
    expect(find.text('المتجر'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('R4) Home 320px + texte 1.3x : pas de overflow', (tester) async {
    await pumpHomeNarrow(tester, textScale: 1.3);
    expect(find.text('Create game'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T1) entrée delay=0 anime immédiatement', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BrainEntrance(delayMs: 0, child: Text('Hi'))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final opacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(opacity, greaterThan(0));
  });

  testWidgets('T2/T3) entrée retardée : cachée avant, visible après', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BrainEntrance(delayMs: 300, child: Text('Hi'))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 299));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    await tester.pump(const Duration(milliseconds: 281));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });

  testWidgets('T4) disableAnimations : rendu immédiat', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(body: BrainEntrance(delayMs: 300, child: Text('Hi'))),
        ),
      ),
    );
    expect(find.text('Hi'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('C1) BrainCard : ripple interne, tap, featured', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrainCard(
            featured: true,
            onTap: () => tapped++,
            child: const Text('X'),
          ),
        ),
      ),
    );
    expect(find.byType(Card), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Card), matching: find.byType(InkWell)),
      findsOneWidget,
    );
    final shape =
        tester.widget<Card>(find.byType(Card)).shape as RoundedRectangleBorder;
    expect(shape.side.color, BrainColors.gold.withValues(alpha: 0.65));
    await tester.tap(find.text('X'));
    await tester.pump();
    expect(tapped, 1);
  });
}

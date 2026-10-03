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
import 'package:brainwager/l10n/app_localizations.dart';
import 'package:brainwager/shared/widgets/brand.dart';

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
}

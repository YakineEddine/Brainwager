// Tests polish marque Phase brand-polish : hiérarchie, invariants visuels
// et comportementaux. Aucune logique métier modifiée ici, que du visuel.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Bundle qui échoue toujours : prouve le repli wordmark (errorBuilder).
class _FailingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw FlutterError('asset manquant (test)');
  }
}

void main() {
  test('B/G) routes packs et partagé inchangées', () {
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

  testWidgets('J) marque : repli wordmark si asset en échec', (tester) async {
    // Bundle qui échoue : errorBuilder doit afficher le repli, sans crash.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultAssetBundle(
            bundle: _FailingBundle(),
            child: const BrainBrand(variant: BrainBrandVariant.full),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('BRAINWAGER'), findsOneWidget);
  });

  test('A/B/C) BrainBrand résout les chemins finaux', () {
    expect(
      brainBrandAsset(BrainBrandVariant.full),
      'assets/branding/brainwager_logo.png',
    );
    expect(
      brainBrandAsset(BrainBrandVariant.compact),
      'assets/branding/brainwager_logo_compact.png',
    );
    expect(
      brainBrandAsset(BrainBrandVariant.markOnly),
      'assets/branding/brainwager_mark.png',
    );
  });

  testWidgets('E) Home : logo final, sans slogan dupliqué', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/home');
    await tester.pumpAndSettle();
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images
          .map((i) => (i.image as AssetImage).assetName)
          .contains('assets/branding/brainwager_logo.png'),
      isTrue,
    );
    expect(find.text('BRAINWAGER'), findsNothing);
    // Le logo porte déjà sa signature : aucun slogan texte séparé dessous.
    expect(find.text('Bet on what you know'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('D) config launcher : source legacy + mark adaptatif', () {
    // Contenu versionné : la source opaque reste le legacy, le sigle
    // transparent est le foreground adaptatif (jamais l'inverse).
    final yaml = File('flutter_launcher_icons.yaml').readAsStringSync();
    expect(
      yaml,
      contains('image_path: "assets/branding/brainwager_app_icon_source.png"'),
    );
    expect(
      yaml,
      contains(
        'adaptive_icon_foreground: "assets/branding/brainwager_mark.png"',
      ),
    );
    expect(yaml, contains('adaptive_icon_background: "#1E1B2E"'));
  });

  test('J/K/L) assets requis déclarés et chargeables', () async {
    const files = [
      'assets/branding/brainwager_logo.png',
      'assets/branding/brainwager_logo_compact.png',
      'assets/branding/brainwager_mark.png',
      'assets/branding/brainwager_app_icon_source.png',
      'assets/branding/brainwager_splash_mark.png',
    ];
    for (final f in files) {
      final data = await rootBundle.load(f);
      expect(data.lengthInBytes, greaterThan(0), reason: f);
    }
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
    // Boutique : carte Home + onglet navbar (même libellé, deux endroits).
    expect(find.text('Boutique'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('R3) Home 320px AR RTL : secondaires visibles', (tester) async {
    await pumpHomeNarrow(tester, locale: const Locale('ar'));
    // Cartes Home + onglets navbar partagent les libellés.
    expect(find.text('الحزم'), findsWidgets);
    expect(find.text('المتجر'), findsWidgets);
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

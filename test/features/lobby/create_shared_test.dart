import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/lobby/lobby_screens.dart';
import 'package:brainwager/features/packs/pack.dart';
import 'package:brainwager/features/packs/pack_providers.dart';
import 'package:brainwager/l10n/app_localizations.dart';

const _catalogPack = PackSummary(
  id: 'cat1',
  titleFr: 'Catalogue',
  titleEn: 'Catalog',
  titleAr: 'فهرس',
  descFr: '',
  descEn: '',
  descAr: '',
  isOfficial: true,
  isPremium: false,
  priceSku: null,
  shareCode: 'CAT01',
  ownerId: null,
  isHidden: false,
);

Future<void> _pumpCreate(
  WidgetTester tester, {
  String? sharedCode,
  void Function()? onCatalogLoad,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        packCatalogProvider.overrideWith((ref) async {
          onCatalogLoad?.call();
          return const PackCatalog(
              packs: [_catalogPack], activeEntitlements: {});
        }),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
        home: Scaffold(body: CreateScreen(sharedCode: sharedCode)),
      ),
    ),
  );
}

void main() {
  testWidgets('D) shared actif => pas de dropdown catalogue', (tester) async {
    await _pumpCreate(tester, sharedCode: 'PK-AB12');
    await tester.pump();
    // Branche partagée (chargement RPC headless) : aucun sélecteur normal.
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('E) mode normal => sélecteur catalogue visible', (tester) async {
    await _pumpCreate(tester);
    await tester.pump();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('isolation : shared ne charge jamais le catalogue',
      (tester) async {
    var catalogLoads = 0;
    await _pumpCreate(tester,
        sharedCode: 'PK-AB12', onCatalogLoad: () => catalogLoads++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(catalogLoads, 0);
  });

  testWidgets('isolation : mode normal charge le catalogue', (tester) async {
    var catalogLoads = 0;
    await _pumpCreate(tester, onCatalogLoad: () => catalogLoads++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(catalogLoads, 1);
  });
}

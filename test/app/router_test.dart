import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:brainwager/app/router.dart';
import 'package:brainwager/l10n/app_localizations.dart';

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
        supportedLocales: const [Locale('en'), Locale('fr')],
      ),
    ),
  );
}

void main() {
  test('L) routes /packs et /packs/:id existent', () {
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
    expect(paths, contains('/game/:id'));
  });

  testWidgets('U) /packs/edit résout l’éditeur, PAS le détail', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/packs/edit');
    await tester.pumpAndSettle();
    // Écran création : titre + 11 questions pliables, pas de détail.
    expect(find.text('Create a pack'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsWidgets);
  });

  testWidgets('V) /packs/edit/:id résout l’éditeur', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/packs/edit/some-id');
    await tester.pumpAndSettle();
    // Titre éditeur (pas 'Packs' du détail) ; chargement backend en échec
    // headless -> état d'erreur, sans crash.
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('W) routes Phase 3A toujours présentes', (tester) async {
    await _pumpRouter(tester);
    brainRouter.go('/packs');
    await tester.pumpAndSettle();
    expect(find.text('Packs'), findsOneWidget);
  });
}

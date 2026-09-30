import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_session/game_screen.dart';
import 'package:brainwager/features/packs/ugc_editor_screen.dart';
import 'package:brainwager/l10n/app_localizations.dart';

Future<TextDirection> _appDirection(
    WidgetTester tester, String lang) async {
  var dir = TextDirection.ltr;
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('ar'),
      ],
      home: Builder(builder: (context) {
        dir = Directionality.of(context);
        return const SizedBox();
      }),
    ),
  );
  await tester.pump();
  return dir;
}

Future<void> _pumpEditor(WidgetTester tester, String lang) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: Locale(lang),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr'),
          Locale('en'),
          Locale('ar'),
        ],
        home: const Scaffold(body: UgcEditorScreen()),
      ),
    ),
  );
}

void main() {
  test('A) AppLocalizations supporte Locale(ar)', () {
    expect(
      AppLocalizations.supportedLocales.any((l) => l.languageCode == 'ar'),
      isTrue,
    );
  });

  testWidgets('B) application arabe RTL', (tester) async {
    expect(await _appDirection(tester, 'ar'), TextDirection.rtl);
  });

  testWidgets('C) FR/EN restent LTR', (tester) async {
    expect(await _appDirection(tester, 'fr'), TextDirection.ltr);
    expect(await _appDirection(tester, 'en'), TextDirection.ltr);
  });

  test('K) contentDirection ar -> rtl', () {
    expect(contentDirection('ar'), TextDirection.rtl);
  });

  test('L) contentDirection fr/en -> ltr', () {
    expect(contentDirection('fr'), TextDirection.ltr);
    expect(contentDirection('en'), TextDirection.ltr);
    expect(contentDirection('de'), TextDirection.ltr);
  });

  testWidgets('AE) champs AR en RTL même en UI française', (tester) async {
    await _pumpEditor(tester, 'fr');
    final rtlFields = find.byWidgetPredicate(
      (w) => w is TextField && w.textDirection == TextDirection.rtl,
    );
    // Titre AR + description AR (visibles sans déplier les cartes).
    expect(rtlFields, findsNWidgets(2));
  });

  testWidgets('AF) champs FR en LTR même en UI arabe', (tester) async {
    await _pumpEditor(tester, 'ar');
    final ltrFields = find.byWidgetPredicate(
      (w) => w is TextField && w.textDirection == TextDirection.ltr,
    );
    // Titres/descriptions FR+EN visibles sans déplier.
    expect(ltrFields, findsNWidgets(4));
    final rtlFields = find.byWidgetPredicate(
      (w) => w is TextField && w.textDirection == TextDirection.rtl,
    );
    expect(rtlFields, findsNWidgets(2));
  });
}

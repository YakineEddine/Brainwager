import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/lobby/lobby_screens.dart';
import 'package:brainwager/l10n/app_localizations.dart';

Future<void> _pumpJoin(WidgetTester tester, {String? code}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
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
        home: Scaffold(body: JoinScreen(initialCode: code)),
      ),
    ),
  );
}

void main() {
  testWidgets('P) code initial pré-rempli une seule fois', (tester) async {
    await _pumpJoin(tester, code: 'ABCDE');
    final field = find.byType(TextField).first;
    expect(
      tester.widget<TextField>(field).controller!.text,
      'ABCDE',
    );
    // La frappe utilisateur n'est jamais écrasée par un rebuild.
    await tester.enterText(field, 'XYZ12');
    await tester.pump();
    expect(
      tester.widget<TextField>(field).controller!.text,
      'XYZ12',
    );
  });

  testWidgets('sans code : champ vide', (tester) async {
    await _pumpJoin(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
  });
}

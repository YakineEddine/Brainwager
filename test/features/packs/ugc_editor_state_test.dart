import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/packs/ugc_editor_screen.dart';
import 'package:brainwager/l10n/app_localizations.dart';

Future<void> _pumpCreateEditor(WidgetTester tester) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('fr')],
        home: const Scaffold(body: UgcEditorScreen()),
      ),
    ),
  );
}

void main() {
  group('identité post-création', () {
    test('A) création réussie -> route /packs/edit/<id>', () {
      expect(editRouteFor('abc'), '/packs/edit/abc');
      expect(
        resolveEditTarget(packId: null, createdId: 'abc'),
        'abc',
      );
    });

    test('B) second save après création = UPDATE, pas re-CREATE', () {
      expect(
        shouldUpdate(packId: null, createdId: null),
        isFalse,
      );
      expect(
        shouldUpdate(packId: null, createdId: 'abc'),
        isTrue,
      );
      expect(
        shouldUpdate(packId: 'e', createdId: null),
        isTrue,
      );
    });
  });

  group('EditorSavedFlag', () {
    test('C/D) toute édition fait tomber l’indicateur', () {
      final f = EditorSavedFlag();
      expect(f.saved, isFalse);
      f.markSaved();
      expect(f.saved, isTrue);
      // Titre, description, question, réponse, alias, catégorie,
      // difficulté, match mode, ajout/retrait/déplacement : tous
      // appellent markDirty() via _markDirty().
      f.markDirty();
      expect(f.saved, isFalse);
      f.markDirty();
      expect(f.saved, isFalse);
    });
  });

  group('mutationEnabled', () {
    test('E) gel pendant la sauvegarde', () {
      expect(mutationEnabled(saving: true), isFalse);
      expect(mutationEnabled(saving: false), isTrue);
    });
  });

  group('note numérique immédiate', () {
    testWidgets('F) taper 1984 affiche la note aussitôt', (tester) async {
      await _pumpCreateEditor(tester);
      await tester.tap(find.text('Q1'));
      await tester.pumpAndSettle();
      // Titre×4 puis carte Q1 : prompt×2, réponse FR à l'index 6.
      await tester.enterText(find.byType(TextField).at(6), '1984');
      await tester.pump();
      expect(
        find.text('Numeric answers are evaluated exactly.'),
        findsOneWidget,
      );
    });

    testWidgets('G) retour au texte : la note se recalcule aussitôt',
        (tester) async {
      await _pumpCreateEditor(tester);
      await tester.tap(find.text('Q1'));
      await tester.pumpAndSettle();
      final field = find.byType(TextField).at(6);
      await tester.enterText(field, '1984');
      await tester.pump();
      expect(
        find.text('Numeric answers are evaluated exactly.'),
        findsOneWidget,
      );
      await tester.enterText(field, 'Paris');
      await tester.pump();
      expect(
        find.text('Numeric answers are evaluated exactly.'),
        findsNothing,
      );
    });
  });
}

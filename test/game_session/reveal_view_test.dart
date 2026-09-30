import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_session/game_screen.dart';

void main() {
  test('J) direction réponse révélée : ar RTL, fr/en LTR', () {
    expect(contentDirection('ar'), TextDirection.rtl);
    expect(contentDirection('fr'), TextDirection.ltr);
    expect(contentDirection('en'), TextDirection.ltr);
  });

  testWidgets('K) UI française + réponse arabe => réponse en RTL',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RevealedAnswerView(
            label: 'Bonne réponse :',
            answer: 'النيل',
            languageCode: 'ar',
          ),
        ),
      ),
    );
    final answer =
        tester.widget<Text>(find.text('النيل'));
    expect(answer.textDirection, TextDirection.rtl);
    expect(find.text('Bonne réponse :'), findsOneWidget);
  });

  testWidgets('réponse FR reste LTR', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RevealedAnswerView(
            label: 'Bonne réponse :',
            answer: 'Nil',
            languageCode: 'fr',
          ),
        ),
      ),
    );
    final answer = tester.widget<Text>(find.text('Nil'));
    expect(answer.textDirection, TextDirection.ltr);
  });
}

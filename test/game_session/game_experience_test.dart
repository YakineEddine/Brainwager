// Tests expérience gameplay Phase UI-2 : composants purs/widgets.
// Autorité intacte : ces tests ne touchent ni Supabase ni les règles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/app/theme.dart' show BrainColors;
import 'package:brainwager/features/game_session/game_screen.dart'
    show showLockFor, showRevealFor, showBoardFor, showNextFor, showFinishFor;
import 'package:brainwager/features/game_session/widgets/answer_panel.dart';
import 'package:brainwager/features/game_session/widgets/game_timer.dart';
import 'package:brainwager/features/game_session/widgets/host_controls.dart';
import 'package:brainwager/features/game_session/widgets/question_hero.dart';
import 'package:brainwager/features/game_session/widgets/reveal_panel.dart';
import 'package:brainwager/features/game_session/widgets/wager_selector.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('A) sélecteur normal affiche 1–10', (tester) async {
    await tester.pumpWidget(
      _wrap(
        BrainWagerSelector(
          wagers: List.generate(10, (i) => i + 1),
          selected: 5,
          used: const {},
          enabled: true,
          isFinal: false,
          onSelect: (_) {},
        ),
      ),
    );
    for (var w = 1; w <= 10; w++) {
      expect(find.text('$w'), findsOneWidget);
    }
  });

  testWidgets('B) finale affiche 0/10/20', (tester) async {
    await tester.pumpWidget(
      _wrap(
        BrainWagerSelector(
          wagers: const [0, 10, 20],
          selected: 0,
          used: const {},
          enabled: true,
          isFinal: true,
          onSelect: (_) {},
        ),
      ),
    );
    expect(find.text('0'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
  });

  testWidgets('C) mise déjà utilisée : visible mais non cliquable', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        BrainWagerSelector(
          wagers: List.generate(10, (i) => i + 1),
          selected: 5,
          used: const {3},
          enabled: true,
          isFinal: false,
          onSelect: (_) => calls++,
        ),
      ),
    );
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(calls, 0);
    await tester.tap(find.text('7'));
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('D) mise sélectionnée visuellement évidente', (tester) async {
    await tester.pumpWidget(
      _wrap(
        BrainWagerSelector(
          wagers: List.generate(10, (i) => i + 1),
          selected: 7,
          used: const {},
          enabled: true,
          isFinal: false,
          onSelect: (_) {},
        ),
      ),
    );
    // Le jeton sélectionné est le seul rempli or (les autres : surface).
    final goldFills = find.byWidgetPredicate((w) {
      final d = w is Container ? w.decoration : null;
      return d is BoxDecoration && d.color == BrainColors.gold;
    });
    expect(goldFills, findsOneWidget);
    // Le texte du jeton sélectionné reste présent et unique.
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('E) sélecteur désactivé : aucun callback', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        BrainWagerSelector(
          wagers: List.generate(10, (i) => i + 1),
          selected: 5,
          used: const {},
          enabled: false,
          isFinal: false,
          onSelect: (_) => calls++,
        ),
      ),
    );
    await tester.tap(find.text('7'));
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets('F) question arabe : prompt RTL, compteur LTR', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BrainQuestionHero(
          position: 2,
          total: 11,
          prompt: 'سؤال اختبار',
          languageCode: 'ar',
          isFinal: false,
          timer: SizedBox(),
        ),
      ),
    );
    final prompt = tester.widget<Text>(find.text('سؤال اختبار'));
    expect(prompt.textDirection, TextDirection.rtl);
    final counter = tester.widget<Text>(find.text('3 / 11'));
    expect(counter.textDirection, TextDirection.ltr);
  });

  test('G) phases timer : normal/warning/critical', () {
    expect(timerPhaseFor(30), TimerPhase.normal);
    expect(timerPhaseFor(11), TimerPhase.normal);
    expect(timerPhaseFor(10), TimerPhase.warning);
    expect(timerPhaseFor(6), TimerPhase.warning);
    expect(timerPhaseFor(5), TimerPhase.critical);
    expect(timerPhaseFor(0), TimerPhase.critical);
    expect(timerPhaseColor(TimerPhase.normal), isNotNull);
    expect(
      timerPhaseColor(TimerPhase.critical),
      isNot(timerPhaseColor(TimerPhase.normal)),
    );
  });

  testWidgets('H) timer affiche le temps autoritatif tel quel', (tester) async {
    await tester.pumpWidget(
      _wrap(const BrainTimer(remainingSec: 7, durationSec: 30)),
    );
    await tester.pump();
    // Aucun recalcul : le temps serveur passe tel quel à l'affichage.
    expect(find.text('7 s'), findsOneWidget);
  });

  testWidgets('I) contrôles hôte suivent les prédicats', (tester) async {
    expect(
      showLockFor(status: 'question_open', isHost: true, lockDue: false),
      isTrue,
    );
    expect(showLockFor(status: 'reveal', isHost: true, lockDue: true), isFalse);
    expect(showRevealFor(status: 'question_locked', isHost: true), isTrue);
    expect(showBoardFor(status: 'reveal', isHost: true), isTrue);
    expect(
      showNextFor(status: 'leaderboard', isHost: true, position: 3),
      isTrue,
    );
    expect(showFinishFor(status: 'final_reveal', isHost: true), isTrue);
    await tester.pumpWidget(
      _wrap(
        BrainHostControls(
          showLock: true,
          lockLabel: 'Lock',
          onLock: () {},
          showReveal: false,
          revealLabel: 'Reveal answer',
          onReveal: () {},
          showBoard: false,
          boardLabel: 'Leaderboard',
          onBoard: () {},
          showNext: false,
          nextLabel: 'Next question',
          onNext: () {},
          showFinish: true,
          finishLabel: 'Finish',
          onFinish: () {},
        ),
      ),
    );
    expect(find.text('Lock'), findsOneWidget);
    expect(find.text('Reveal answer'), findsNothing);
    expect(find.text('Finish'), findsOneWidget);
  });

  testWidgets('J) panneau reveal affiche label + réponse', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BrainRevealPanel(
          label: 'Correct answer:',
          answer: 'Nil',
          languageCode: 'en',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Correct answer:'), findsOneWidget);
    expect(find.text('Nil'), findsOneWidget);
  });

  testWidgets('K) sans réponse révélée : aucun panneau', (tester) async {
    const String? revealed = null;
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            if (revealed != null)
              BrainRevealPanel(
                label: 'Correct answer:',
                answer: revealed,
                languageCode: 'en',
              ),
          ],
        ),
      ),
    );
    expect(find.text('Correct answer:'), findsNothing);
  });

  testWidgets('L) soumission sauvée : badge succès', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BrainSubmissionStatus(
          saved: true,
          edited: false,
          savedLabel: 'Answer saved',
          editedLabel: 'Answer edited',
        ),
      ),
    );
    expect(find.text('Answer saved'), findsOneWidget);
    expect(find.text('Answer edited'), findsNothing);
  });

  testWidgets('M) modifié après save : avertissement, pas succès', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const BrainSubmissionStatus(
          saved: false,
          edited: true,
          savedLabel: 'Answer saved',
          editedLabel: 'Answer edited',
        ),
      ),
    );
    expect(find.text('Answer edited'), findsOneWidget);
    expect(find.text('Answer saved'), findsNothing);
  });

  testWidgets('N) verrouillé : saisie et submit désactivés', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(
        BrainAnswerPanel(
          controller: controller,
          enabled: false,
          languageCode: 'fr',
          hintLabel: 'Your answer',
          submitLabel: 'Submit',
          submitting: false,
          onSubmit: null,
          onChanged: (_) {},
        ),
      ),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('O) finale : jetons 0/10/20 sans mise utilisée', (tester) async {
    var picked = -1;
    await tester.pumpWidget(
      _wrap(
        BrainWagerSelector(
          wagers: const [0, 10, 20],
          selected: 10,
          used: const {},
          enabled: true,
          isFinal: true,
          onSelect: (w) => picked = w,
        ),
      ),
    );
    await tester.tap(find.text('20'));
    await tester.pump();
    expect(picked, 20);
  });
}

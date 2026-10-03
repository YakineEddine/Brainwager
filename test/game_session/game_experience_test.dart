// Tests expérience gameplay Phase UI-2 : composants purs/widgets.
// Autorité intacte : ces tests ne touchent ni Supabase ni les règles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/app/theme.dart' show BrainColors;
import 'package:brainwager/features/game_session/game_screen.dart'
    show
        showLockFor,
        showRevealFor,
        showBoardFor,
        showNextFor,
        showFinishFor,
        shouldInstallRevealedAnswer,
        mayLoadStandings,
        mayLoadOwnResult;
import 'package:brainwager/features/game_session/standings.dart';
import 'package:brainwager/features/game_session/widgets/answer_panel.dart';
import 'package:brainwager/features/game_session/widgets/game_timer.dart';
import 'package:brainwager/features/game_session/widgets/host_controls.dart';
import 'package:brainwager/features/game_session/widgets/leaderboard.dart';
import 'package:brainwager/features/game_session/widgets/player_result_panel.dart';
import 'package:brainwager/features/game_session/widgets/podium.dart';
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
          semanticLabelFor: (w) => 'Wager $w',
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
          semanticLabelFor: (w) => 'Wager $w',
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
          semanticLabelFor: (w) => 'Wager $w',
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
          semanticLabelFor: (w) => 'Wager $w',
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
          semanticLabelFor: (w) => 'Wager $w',
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
          semanticLabelFor: (w) => 'Wager $w',
          onSelect: (w) => picked = w,
        ),
      ),
    );
    await tester.tap(find.text('20'));
    await tester.pump();
    expect(picked, 20);
  });

  testWidgets('A2) non-hôte après timeout : late Lock rendu', (tester) async {
    // Règle existante : showLockFor autorise le non-hôte quand lockDue.
    expect(
      showLockFor(status: 'question_open', isHost: false, lockDue: true),
      isTrue,
    );
    await tester.pumpWidget(
      _wrap(
        BrainHostControls(
          showLock: showLockFor(
            status: 'question_open',
            isHost: false,
            lockDue: true,
          ),
          lockLabel: 'Lock (after timer)',
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
          showFinish: false,
          finishLabel: 'Finish',
          onFinish: () {},
        ),
      ),
    );
    expect(find.text('Lock (after timer)'), findsOneWidget);
    // Aucune autre action hôte ne fuit vers le non-hôte.
    expect(find.text('Reveal answer'), findsNothing);
    expect(find.text('Finish'), findsNothing);
  });

  testWidgets('B2) non-hôte avant deadline : aucun panneau', (tester) async {
    expect(
      showLockFor(status: 'question_open', isHost: false, lockDue: false),
      isFalse,
    );
    await tester.pumpWidget(
      _wrap(
        BrainHostControls(
          showLock: false,
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
          showFinish: false,
          finishLabel: 'Finish',
          onFinish: () {},
        ),
      ),
    );
    expect(find.byType(BrainHostControls), findsOneWidget);
    expect(find.text('Lock'), findsNothing);
  });

  testWidgets('C2) ordre visuel : réponse -> mises -> submit', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(
        BrainAnswerPanel(
          controller: controller,
          enabled: true,
          languageCode: 'en',
          hintLabel: 'Your answer',
          submitLabel: 'Submit',
          submitting: false,
          onSubmit: () {},
          onChanged: (_) {},
          wagerContent: BrainWagerSelector(
            wagers: const [1, 2, 3],
            selected: 1,
            used: const {},
            enabled: true,
            isFinal: false,
            semanticLabelFor: (w) => 'Wager $w',
            onSelect: (_) {},
          ),
        ),
      ),
    );
    final fieldTop = tester.getRect(find.byType(TextField)).top;
    final wagerTop = tester.getRect(find.text('2')).top;
    final submitTop = tester.getRect(find.text('Submit')).top;
    expect(fieldTop, lessThan(wagerTop));
    expect(wagerTop, lessThan(submitTop));
  });

  test('D2) reveal installé une seule fois par réponse', () {
    expect(shouldInstallRevealedAnswer(current: null, answer: 'Nil'), isTrue);
    expect(shouldInstallRevealedAnswer(current: 'Nil', answer: 'Nil'), isFalse);
    expect(shouldInstallRevealedAnswer(current: 'Old', answer: 'Nil'), isTrue);
  });

  testWidgets('E2) timer actif critique : pulsation présente', (tester) async {
    await tester.pumpWidget(
      _wrap(const BrainTimer(remainingSec: 4, durationSec: 30)),
    );
    await tester.pump();
    // La pulsation critique enveloppe l'anneau d'une transition d'échelle.
    expect(find.byKey(const Key('brain-timer-pulse')), findsOneWidget);
  });

  testWidgets('F2) timer inactif : figé, aucune pulsation', (tester) async {
    await tester.pumpWidget(
      _wrap(const BrainTimer(remainingSec: 0, durationSec: 30, active: false)),
    );
    await tester.pump();
    expect(find.text('0 s'), findsOneWidget);
    expect(find.byKey(const Key('brain-timer-pulse')), findsNothing);
  });

  testWidgets('G2/H2/I2) sémantique mise localisée EN/FR/AR', (tester) async {
    Future<void> check(String label) async {
      await tester.pumpWidget(
        _wrap(
          BrainWagerSelector(
            wagers: const [5],
            selected: 5,
            used: const {},
            enabled: true,
            isFinal: false,
            semanticLabelFor: (_) => label,
            onSelect: (_) {},
          ),
        ),
      );
      final token = tester.widget<BrainWagerToken>(
        find.byType(BrainWagerToken),
      );
      expect(token.semanticLabel, label);
    }

    await check('Wager 5');
    await check('Mise 5');
    await check('الرهان 5');
  });

  List<GameStanding> demoRows() => const [
    GameStanding(
      playerId: 'p1',
      nickname: 'Zoe',
      score: 100,
      bestStreak: 1,
      biggestWagerWon: 5,
    ),
    GameStanding(
      playerId: 'p2',
      nickname: 'Ali',
      score: 100,
      bestStreak: 9,
      biggestWagerWon: 20,
    ),
    GameStanding(
      playerId: 'p3',
      nickname: 'Mia',
      score: 80,
      bestStreak: 0,
      biggestWagerWon: 0,
    ),
  ];

  test('J2) rangs partagés : 100,100,80 -> 1,1,3', () {
    final sorted = sortStandings(demoRows());
    expect(displayRanks(sorted), [1, 1, 3]);
  });

  test('K2) tri par score autoritaire, pseudo display-only', () {
    final sorted = sortStandings(demoRows());
    expect(sorted.map((s) => s.score), [100, 100, 80]);
    // Égalité : ordre alphabétique d'affichage, PAS best_streak.
    expect(sorted.map((s) => s.playerId), ['p2', 'p1', 'p3']);
  });

  testWidgets('L2) joueur courant surligné', (tester) async {
    final sorted = sortStandings(demoRows());
    await tester.pumpWidget(
      _wrap(
        BrainLeaderboard(
          standings: sorted,
          ranks: displayRanks(sorted),
          currentPlayerId: 'p2',
        ),
      ),
    );
    await tester.pump();
    final highlighted = find.byWidgetPredicate((w) {
      if (w is Container && w.decoration is BoxDecoration) {
        final d = w.decoration! as BoxDecoration;
        final border = d.border;
        return border is Border &&
            border.top.width == 2 &&
            border.top.color == BrainColors.electricViolet;
      }
      return false;
    });
    expect(highlighted, findsOneWidget);
  });

  testWidgets('M2) leaderboard : rang, pseudo, score', (tester) async {
    final sorted = sortStandings(demoRows());
    await tester.pumpWidget(
      _wrap(
        BrainLeaderboard(
          standings: sorted,
          ranks: displayRanks(sorted),
          currentPlayerId: null,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('#1'), findsWidgets);
    expect(find.text('#3'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('100'), findsWidgets);
    expect(find.text('80'), findsOneWidget);
  });

  testWidgets('N2) podium : top visibles, rangs partagés honnêtes', (
    tester,
  ) async {
    final sorted = sortStandings(demoRows());
    await tester.pumpWidget(
      _wrap(
        BrainPodium(
          standings: sorted,
          ranks: displayRanks(sorted),
          currentPlayerId: 'p3',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Zoe'), findsOneWidget);
    expect(find.text('Mia'), findsOneWidget);
    // Deux premiers ex æquo : deux cartes rang 1, pas de faux vainqueur.
    expect(find.text('#1'), findsNWidgets(2));
  });

  testWidgets('O2) résultat correct + delta positif', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BrainPlayerResultPanel(
          isCorrect: true,
          scoredPoints: 7,
          correctLabel: 'Correct',
          incorrectLabel: 'Incorrect',
        ),
      ),
    );
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('+7'), findsOneWidget);
  });

  testWidgets('P2) résultat incorrect + zéro/négatif', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BrainPlayerResultPanel(
          isCorrect: false,
          scoredPoints: 0,
          correctLabel: 'Correct',
          incorrectLabel: 'Incorrect',
        ),
      ),
    );
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        const BrainPlayerResultPanel(
          isCorrect: false,
          scoredPoints: -20,
          correctLabel: 'Correct',
          incorrectLabel: 'Incorrect',
        ),
      ),
    );
    expect(find.text('-20'), findsOneWidget);
  });

  test('Q2/R2) portes de chargement + aucune correctness locale', () {
    expect(mayLoadOwnResult('question_open'), isFalse);
    expect(mayLoadOwnResult('final_wager'), isFalse);
    expect(mayLoadOwnResult('question_locked'), isFalse);
    expect(mayLoadOwnResult('reveal'), isTrue);
    expect(mayLoadOwnResult('leaderboard'), isTrue);
    expect(mayLoadOwnResult('final_reveal'), isTrue);
    expect(mayLoadOwnResult('finished'), isTrue);
    expect(mayLoadStandings('question_open'), isFalse);
    expect(mayLoadStandings('leaderboard'), isTrue);
    expect(mayLoadStandings('finished'), isTrue);
    // Le modèle de classement ne connaît ni is_correct ni scored_points :
    // aucun tri local de correctness n'est possible.
    final row = GameStanding.fromRow({
      'id': 'p9',
      'nickname': 'Zed',
      'score': 12,
      'best_streak': 3,
      'biggest_wager_won': 10,
      'is_correct': true,
      'scored_points': 99,
    });
    expect(row.score, 12);
    expect(sortStandings([row]).single.playerId, 'p9');
  });

  List<GameStanding> fiveRows() => const [
    GameStanding(
      playerId: 'a',
      nickname: 'Alice',
      score: 100,
      bestStreak: 1,
      biggestWagerWon: 5,
    ),
    GameStanding(
      playerId: 'z',
      nickname: 'Zoe',
      score: 100,
      bestStreak: 9,
      biggestWagerWon: 20,
    ),
    GameStanding(
      playerId: 'm',
      nickname: 'Mia',
      score: 80,
      bestStreak: 0,
      biggestWagerWon: 0,
    ),
    GameStanding(
      playerId: 'b',
      nickname: 'Bob',
      score: 60,
      bestStreak: 2,
      biggestWagerWon: 10,
    ),
    GameStanding(
      playerId: 'c',
      nickname: 'Cid',
      score: 40,
      bestStreak: 0,
      biggestWagerWon: 0,
    ),
  ];

  testWidgets('A3) finished 5 joueurs : chaque pseudo rendu UNE fois', (
    tester,
  ) async {
    final sorted = sortStandings(fiveRows());
    await tester.pumpWidget(
      _wrap(
        BrainPodium(
          standings: sorted,
          ranks: displayRanks(sorted),
          currentPlayerId: null,
        ),
      ),
    );
    await tester.pump();
    for (final name in ['Alice', 'Zoe', 'Mia', 'Bob', 'Cid']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  test('B3) premier unique : helper vrai', () {
    expect(hasUniqueWinner([1, 2, 3]), isTrue);
    expect(hasUniqueWinner([1]), isTrue);
    expect(hasUniqueWinner([]), isFalse);
  });

  test('C3) deux premiers ex æquo : helper faux', () {
    expect(hasUniqueWinner([1, 1, 3]), isFalse);
  });

  testWidgets('D3) quatre #1 : rangs égaux, pas de hero unique', (
    tester,
  ) async {
    const tied = [
      GameStanding(
        playerId: 'a',
        nickname: 'A',
        score: 100,
        bestStreak: 0,
        biggestWagerWon: 0,
      ),
      GameStanding(
        playerId: 'b',
        nickname: 'B',
        score: 100,
        bestStreak: 0,
        biggestWagerWon: 0,
      ),
      GameStanding(
        playerId: 'c',
        nickname: 'C',
        score: 100,
        bestStreak: 0,
        biggestWagerWon: 0,
      ),
      GameStanding(
        playerId: 'd',
        nickname: 'D',
        score: 100,
        bestStreak: 0,
        biggestWagerWon: 0,
      ),
      GameStanding(
        playerId: 'e',
        nickname: 'E',
        score: 80,
        bestStreak: 0,
        biggestWagerWon: 0,
      ),
    ];
    final sorted = sortStandings(tied);
    final ranks = displayRanks(sorted);
    expect(ranks, [1, 1, 1, 1, 5]);
    expect(hasUniqueWinner(ranks), isFalse);
    await tester.pumpWidget(
      _wrap(
        BrainPodium(standings: sorted, ranks: ranks, currentPlayerId: null),
      ),
    );
    await tester.pump();
    // Quatre cartes #1 égales, pas de hero dominant : quatre labels #1.
    expect(find.text('#1'), findsNWidgets(4));
    expect(find.text('#5'), findsOneWidget);
  });

  test('E3) rangs 1,1,3 inchangés + variante 1,1,1,1,5', () {
    List<GameStanding> rows(intscores) => [
      for (var i = 0; i < intscores.length; i++)
        GameStanding(
          playerId: 'p$i',
          nickname: 'N$i',
          score: intscores[i],
          bestStreak: 0,
          biggestWagerWon: 0,
        ),
    ];
    expect(displayRanks(sortStandings(rows([100, 100, 80]))), [1, 1, 3]);
    expect(displayRanks(sortStandings(rows([100, 100, 100, 100, 80]))), [
      1,
      1,
      1,
      1,
      5,
    ]);
  });

  testWidgets('F3) podium RTL : marqueur joueur affiché', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          home: Scaffold(
            body: BrainPodium(
              standings: [
                GameStanding(
                  playerId: 'a',
                  nickname: 'Alice',
                  score: 100,
                  bestStreak: 0,
                  biggestWagerWon: 0,
                ),
              ],
              ranks: [1],
              currentPlayerId: 'a',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.person), findsWidgets);
    expect(find.text('Alice'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_session/game_screen.dart';

Future<void> _pumpLobby(
  WidgetTester tester, {
  required bool isHost,
  int presenceCount = 2,
  int memberCount = 2,
  String? joinCode = '3MFKX',
  bool? startEnabled,
  Future<void> Function(String code)? onCopyCode,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LobbyWaitingView(
          isHost: isHost,
          presenceCount: presenceCount,
          memberCount: memberCount,
          maxMembers: 50,
          joinCode: joinCode,
          startEnabled: startEnabled ?? (isHost && memberCount >= 2),
          startHint: null,
          onStart: () {},
          onCopyCode: onCopyCode ?? (_) async {},
        ),
      ),
    ),
  );
}

void main() {
  test('selectsLobbyView : lobby -> attente, question -> chemin existant', () {
    expect(selectsLobbyView(hasQuestion: false), isTrue);
    expect(selectsLobbyView(hasQuestion: true), isFalse);
  });

  testWidgets('lobby + hôte : bouton Démarrer visible', (tester) async {
    await _pumpLobby(tester, isHost: true);
    expect(find.text('En attente du lancement par l’hôte…'), findsOneWidget);
    expect(find.text('Démarrer la partie'), findsOneWidget);
  });

  testWidgets('lobby + non-hôte : bouton Démarrer caché', (tester) async {
    await _pumpLobby(tester, isHost: false);
    expect(find.text('En attente du lancement par l’hôte…'), findsOneWidget);
    expect(find.text('Démarrer la partie'), findsNothing);
  });

  testWidgets('lobby : Presence visible avant le start', (tester) async {
    await _pumpLobby(tester, isHost: false, presenceCount: 2);
    expect(find.text('En ligne : 2'), findsOneWidget);
  });

  testWidgets('bouton Démarrer appelle onStart', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LobbyWaitingView(
            isHost: true,
            presenceCount: 1,
            memberCount: 2,
            maxMembers: 50,
            joinCode: '3MFKX',
            startEnabled: true,
            startHint: null,
            onStart: () => called = true,
            onCopyCode: (_) async {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Démarrer la partie'));
    expect(called, isTrue);
  });

  testWidgets('lobby : code de partie affiché', (tester) async {
    await _pumpLobby(tester, isHost: false, joinCode: '3MFKX');
    expect(find.text('Code de partie'), findsOneWidget);
    expect(find.text('3MFKX'), findsOneWidget);
  });

  testWidgets('copie : le bouton transmet le code attendu', (tester) async {
    String? copied;
    await _pumpLobby(
      tester,
      isHost: false,
      joinCode: '3MFKX',
      onCopyCode: (code) async => copied = code,
    );
    await tester.tap(find.text('Copier le code'));
    expect(copied, '3MFKX');
  });

  testWidgets('code absent : placeholder neutre, pas de bouton copie',
      (tester) async {
    await _pumpLobby(tester, isHost: true, joinCode: null);
    expect(find.text('…'), findsOneWidget);
    expect(find.text('Copier le code'), findsNothing);
    expect(find.text('Démarrer la partie'), findsOneWidget);
  });

  testWidgets('lobby : aucun contenu de question', (tester) async {
    await _pumpLobby(tester, isHost: false, joinCode: '3MFKX');
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Ta réponse'), findsNothing);
    expect(find.textContaining('Valider'), findsNothing);
    expect(find.textContaining('Bonne réponse'), findsNothing);
  });

  testWidgets('membres affichés + Start grisé à 1 joueur', (tester) async {
    await _pumpLobby(tester, isHost: true, memberCount: 1, startEnabled: false);
    expect(find.text('Joueurs : 1 / 50'), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Démarrer la partie'),
    );
    expect(btn.enabled, isFalse);
  });

  testWidgets('Start actif à 2 joueurs', (tester) async {
    await _pumpLobby(tester, isHost: true, memberCount: 2, startEnabled: true);
    expect(find.text('Joueurs : 2 / 50'), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Démarrer la partie'),
    );
    expect(btn.enabled, isTrue);
  });
}

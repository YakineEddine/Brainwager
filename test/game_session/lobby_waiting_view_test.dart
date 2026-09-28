import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_session/game_screen.dart';

Future<void> _pumpLobby(
  WidgetTester tester, {
  required bool isHost,
  int presenceCount = 2,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LobbyWaitingView(
          isHost: isHost,
          presenceCount: presenceCount,
          onStart: () {},
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
            onStart: () => called = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Démarrer la partie'));
    expect(called, isTrue);
  });
}

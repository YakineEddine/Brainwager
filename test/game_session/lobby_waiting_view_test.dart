import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_session/game_screen.dart';
import 'package:brainwager/l10n/app_localizations.dart';

Future<void> _pumpLobby(
  WidgetTester tester, {
  required bool isHost,
  int presenceCount = 2,
  int memberCount = 2,
  String? joinCode = '3MFKX',
  bool? startEnabled,
  Future<void> Function(String code)? onCopyCode,
  String lang = 'en',
}) {
  return tester.pumpWidget(
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
      home: Scaffold(
        body: LobbyWaitingView(
          isHost: isHost,
          presenceCount: presenceCount,
          memberCount: memberCount,
          maxMembers: 50,
          minPlayers: 2,
          joinCode: joinCode,
          startEnabled: startEnabled ?? (isHost && memberCount >= 2),
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
    expect(
        find.text('Waiting for the host to start…'), findsOneWidget);
    expect(find.text('Start the game'), findsOneWidget);
  });

  testWidgets('lobby + non-hôte : bouton Démarrer caché', (tester) async {
    await _pumpLobby(tester, isHost: false);
    expect(
        find.text('Waiting for the host to start…'), findsOneWidget);
    expect(find.text('Start the game'), findsNothing);
  });

  testWidgets('lobby : Presence visible avant le start', (tester) async {
    await _pumpLobby(tester, isHost: false, presenceCount: 2);
    expect(find.text('Online: 2'), findsOneWidget);
  });

  testWidgets('bouton Démarrer appelle onStart', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
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
        home: Scaffold(
          body: LobbyWaitingView(
            isHost: true,
            presenceCount: 1,
            memberCount: 2,
            maxMembers: 50,
            minPlayers: 2,
            joinCode: '3MFKX',
            startEnabled: true,
            onStart: () => called = true,
            onCopyCode: (_) async {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start the game'));
    expect(called, isTrue);
  });

  testWidgets('lobby : code de partie affiché', (tester) async {
    await _pumpLobby(tester, isHost: false, joinCode: '3MFKX');
    expect(find.text('Join code'), findsOneWidget);
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
    await tester.tap(find.text('Copy code'));
    expect(copied, '3MFKX');
  });

  testWidgets('code absent : placeholder neutre, pas de bouton copie',
      (tester) async {
    await _pumpLobby(tester, isHost: true, joinCode: null);
    expect(find.text('…'), findsOneWidget);
    expect(find.text('Copy code'), findsNothing);
    expect(find.text('Start the game'), findsOneWidget);
  });

  testWidgets('lobby : aucun contenu de question', (tester) async {
    await _pumpLobby(tester, isHost: false, joinCode: '3MFKX');
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Your answer'), findsNothing);
    expect(find.textContaining('Submit'), findsNothing);
    expect(find.textContaining('Correct answer'), findsNothing);
  });

  testWidgets('membres affichés + Start grisé à 1 joueur', (tester) async {
    await _pumpLobby(tester, isHost: true, memberCount: 1, startEnabled: false);
    expect(find.text('Players: 1 / 50'), findsOneWidget);
    expect(find.text('Players: 1 / 50 — minimum 2'), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Start the game'),
    );
    expect(btn.enabled, isFalse);
  });

  testWidgets('Start actif à 2 joueurs', (tester) async {
    await _pumpLobby(tester, isHost: true, memberCount: 2, startEnabled: true);
    expect(find.text('Players: 2 / 50'), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Start the game'),
    );
    expect(btn.enabled, isTrue);
  });

  testWidgets('lobby arabe : textes arabes affichés', (tester) async {
    await _pumpLobby(tester, isHost: false, lang: 'ar');
    expect(find.text('في انتظار بدء المضيف…'), findsOneWidget);
    expect(find.text('متصل: 2'), findsOneWidget);
  });
}

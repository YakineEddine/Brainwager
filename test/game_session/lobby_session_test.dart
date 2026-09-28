import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/lobby/lobby_viewmodel.dart';

void main() {
  test('create : player_id serveur utilisé directement', () {
    final s = sessionFromCreateResponse(
      nickname: 'Moi',
      res: {
        'game_id': 'g1',
        'player_id': 'p1',
        'join_code': 'ABCDE',
      },
    );
    expect(s.gameId, 'g1');
    expect(s.playerId, 'p1');
    expect(s.joinCode, 'ABCDE');
    expect(s.isHost, isTrue);
    expect(s.nickname, 'Moi');
  });

  test('join nouveau : valeurs serveur adoptées', () {
    final s = sessionFromJoinResponse(
      typedNickname: 'Moi',
      fallbackCode: 'ABCDE',
      res: {
        'game_id': 'g1',
        'player_id': 'p2',
        'join_code': 'ABCDE',
        'nickname': 'Moi',
        'is_host': false,
        'already_joined': false,
      },
    );
    expect(s.playerId, 'p2');
    expect(s.isHost, isFalse);
    expect(s.nickname, 'Moi');
  });

  test('already_joined : reprise acceptée, pseudo serveur fait foi', () {
    final s = sessionFromJoinResponse(
      typedNickname: 'AutrePseudo',
      fallbackCode: 'ABCDE',
      res: {
        'game_id': 'g1',
        'player_id': 'p2',
        'join_code': 'ABCDE',
        'nickname': 'VraiPseudo',
        'is_host': false,
        'already_joined': true,
      },
    );
    expect(s.playerId, 'p2');
    expect(s.nickname, 'VraiPseudo');
  });

  test('restore : session depuis lignes players + games', () {
    final s = buildRestoredSession(
      gameId: 'g1',
      playerRow: {'id': 'p9', 'nickname': 'Moi', 'is_host': true},
      gameRow: {'join_code': 'ZZZZZ', 'status': 'lobby'},
    );
    expect(s.gameId, 'g1');
    expect(s.playerId, 'p9');
    expect(s.joinCode, 'ZZZZZ');
    expect(s.isHost, isTrue);
    expect(s.nickname, 'Moi');
  });
}

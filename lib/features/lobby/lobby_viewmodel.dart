// Session de partie Phase 3A : create (pack choisi) / join / restore.
// Pack démo hardcodé supprimé : CreateScreen fournit un packId du catalogue.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/supabase_client.dart';
import '../../core/utils/profanity_filter.dart';

class GameSession {
  final String gameId;
  final String playerId;
  final String joinCode;
  final bool isHost;
  final String nickname;
  const GameSession({
    required this.gameId,
    required this.playerId,
    required this.joinCode,
    required this.isHost,
    required this.nickname,
  });
}

/// Session depuis la réponse create_game (player_id retourné par le
/// serveur, migration 0009 : plus de requête players de rattrapage).
GameSession sessionFromCreateResponse({
  required String nickname,
  required Map<String, dynamic> res,
}) {
  return GameSession(
    gameId: res['game_id'] as String,
    playerId: res['player_id'] as String,
    joinCode: (res['join_code'] as String?) ?? '',
    isHost: true,
    nickname: nickname,
  );
}

/// Session depuis la réponse join_game. Si already_joined, le pseudo
/// retourné par le serveur fait foi (l'appelant a pu en taper un autre).
GameSession sessionFromJoinResponse({
  required String typedNickname,
  required String fallbackCode,
  required Map<String, dynamic> res,
}) {
  return GameSession(
    gameId: res['game_id'] as String,
    playerId: res['player_id'] as String,
    joinCode: (res['join_code'] as String?) ?? fallbackCode,
    isHost: (res['is_host'] as bool?) ?? false,
    nickname: (res['nickname'] as String?) ?? typedNickname,
  );
}

/// Lève not-member si la ligne est absente (RLS : zéro ligne = non-membre).
Map<String, dynamic> requirePlayerRow(Map<String, dynamic>? row) {
  if (row == null) throw Exception('not-member');
  return row;
}

/// Lève not-member si la partie est introuvable après adhésion établie.
Map<String, dynamic> requireGameRow(Map<String, dynamic>? row) {
  if (row == null) throw Exception('not-member');
  return row;
}
/// Session restaurée depuis les lignes autoritaires (refresh/deep link) :
/// players (id, nickname, is_host) + games (join_code). Identité stable
/// user_id, jamais le pseudo.
GameSession buildRestoredSession({
  required String gameId,
  required Map<String, dynamic> playerRow,
  required Map<String, dynamic> gameRow,
}) {
  return GameSession(
    gameId: gameId,
    playerId: playerRow['id'] as String,
    joinCode: (gameRow['join_code'] as String?) ?? '',
    isHost: (playerRow['is_host'] as bool?) ?? false,
    nickname: (playerRow['nickname'] as String?) ?? '',
  );
}

/// Paramètres create_game (pur, testé) : pack choisi, options Phase 2
/// figées (contrôles équipe/langue/durée = tickets séparés).
Map<String, dynamic> buildCreateGameParams({
  required String packId,
  required String nickname,
}) {
  return {
    'p_pack_id': packId,
    'p_nickname': nickname,
    'p_team_mode': false,
    'p_language': 'fr',
    'p_duration': 30,
  };
}

class LobbyViewModel extends Notifier<AsyncValue<GameSession?>> {
  @override
  AsyncValue<GameSession?> build() => const AsyncValue.data(null);

  Future<GameSession> createGame({
    required String nickname,
    required String packId,
  }) async {
    final n = nickname.trim();
    if (!isNicknameClean(n)) throw Exception('pseudo-invalide');
    if (packId.isEmpty) throw Exception('pack-manquant');
    state = const AsyncValue.loading();
    try {
      final res = await supa().rpc(
        'create_game',
        params: buildCreateGameParams(packId: packId, nickname: n),
      );
      final full = sessionFromCreateResponse(
        nickname: n,
        res: Map<String, dynamic>.from(res as Map),
      );
      state = AsyncValue.data(full);
      return full;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<GameSession> joinGame({
    required String code,
    required String nickname,
  }) async {
    final n = nickname.trim();
    if (!isNicknameClean(n)) throw Exception('pseudo-invalide');
    final fallbackCode = code.trim().toUpperCase();
    state = const AsyncValue.loading();
    try {
      final res = await supa().rpc('join_game', params: {
        'p_code': fallbackCode,
        'p_nickname': n,
      });
      // already_joined == true : reprise normale, pas une erreur.
      final full = sessionFromJoinResponse(
        typedNickname: n,
        fallbackCode: fallbackCode,
        res: Map<String, dynamic>.from(res as Map),
      );
      state = AsyncValue.data(full);
      return full;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Restaure la session après refresh/deep link via l'utilisateur courant.
  /// Zéro ligne (RLS) = non-membre explicite, pas d'erreur générique.
  Future<GameSession> restoreGameSession(String gameId) async {
    final userId = supa().auth.currentUser?.id;
    if (userId == null) throw Exception('session-absente');
    state = const AsyncValue.loading();
    try {
      final meRaw = await supa()
          .from('players')
          .select('id,nickname,is_host')
          .eq('game_id', gameId)
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();
      final me = requirePlayerRow(
        meRaw == null ? null : Map<String, dynamic>.from(meRaw as Map),
      );
      final gRaw = await supa()
          .from('games')
          .select('join_code,status')
          .eq('id', gameId)
          .limit(1)
          .maybeSingle();
      final g = requireGameRow(
        gRaw == null ? null : Map<String, dynamic>.from(gRaw as Map),
      );
      final full = buildRestoredSession(
        gameId: gameId,
        playerRow: me,
        gameRow: g,
      );
      state = AsyncValue.data(full);
      return full;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final lobbyViewModelProvider =
    NotifierProvider<LobbyViewModel, AsyncValue<GameSession?>>(
  LobbyViewModel.new,
);

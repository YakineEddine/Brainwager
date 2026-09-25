// Session de partie Phase 2 : create/join via RPC, pack démo DEMO01.
// Le sélecteur de packs arrive en Phase 3 ; ici on vise le multijoueur brut.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/supabase_client.dart';
import '../../core/utils/profanity_filter.dart';

class GameSession {
  final String gameId;
  final String playerId;
  final String joinCode;
  final bool isHost;
  const GameSession({
    required this.gameId,
    required this.playerId,
    required this.joinCode,
    required this.isHost,
  });
}

class LobbyViewModel extends Notifier<AsyncValue<GameSession?>> {
  @override
  AsyncValue<GameSession?> build() => const AsyncValue.data(null);

  Future<GameSession> createGame({required String nickname}) async {
    final n = nickname.trim();
    if (!isNicknameClean(n)) throw Exception('pseudo-invalide');
    state = const AsyncValue.loading();
    try {
      final c = supa();
      // Pack démo Phase 2 (seed_demo_pack.sql). Phase 3 : choix du pack.
      final pack = await c
          .from('packs')
          .select('id')
          .eq('share_code', 'DEMO01')
          .limit(1)
          .single();
      final res = await c.rpc('create_game', params: {
        'p_pack_id': (pack as Map)['id'],
        'p_nickname': n,
        'p_team_mode': false,
        'p_language': 'fr',
        'p_duration': 30,
      });
      final m = res as Map;
      final session = GameSession(
        gameId: m['game_id'] as String,
        playerId: '', // hôte : player_id retrouvé au besoin via players
        joinCode: m['join_code'] as String,
        isHost: true,
      );
      // Retrouve le player hôte pour la presence.
      final me = await c
          .from('players')
          .select('id')
          .eq('game_id', session.gameId)
          .eq('nickname', n)
          .limit(1)
          .single();
      final full = GameSession(
        gameId: session.gameId,
        playerId: (me as Map)['id'] as String,
        joinCode: session.joinCode,
        isHost: true,
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
    state = const AsyncValue.loading();
    try {
      final res = await supa().rpc('join_game', params: {
        'p_code': code.trim().toUpperCase(),
        'p_nickname': n,
      });
      final m = res as Map;
      final session = GameSession(
        gameId: m['game_id'] as String,
        playerId: m['player_id'] as String,
        joinCode: code.trim().toUpperCase(),
        isHost: false,
      );
      state = AsyncValue.data(session);
      return session;
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

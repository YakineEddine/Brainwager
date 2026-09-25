// Realtime Phase 2 : 1 canal Changes + 1 Broadcast ponctuel + 1 Presence par partie.
// Aucun tick périodique : le countdown est local (CountdownRing + BrainClock).
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class GameRealtime {
  final String gameId;
  RealtimeChannel? _changes;
  RealtimeChannel? _events;
  RealtimeChannel? _presence;

  GameRealtime(this.gameId);

  /// Écoute l'état durable (games/players/answers/wagers). RLS filtre déjà.
  void subscribeChanges({
    required void Function(Map<String, dynamic>) onGames,
    required void Function(Map<String, dynamic>) onPlayers,
    required void Function(Map<String, dynamic>) onScores,
  }) {
    final c = supa().channel('changes:game:$gameId');
    c
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: gameId,
          ),
          callback: (p) => onGames(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'game_id',
            value: gameId,
          ),
          callback: (p) => onPlayers(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'player_answers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'game_id',
            value: gameId,
          ),
          callback: (p) => onScores(p.newRecord),
        );
    c.subscribe();
    _changes = c;
  }

  /// Événements ponctuels hôte : opened / locked / revealed (payloads sans
  /// réponses avant lock). Envoyés par l'hôte après chaque RPC réussie.
  void subscribeEvents(void Function(Map<String, dynamic>) onEvent) {
    final c = supa().channel('game:$gameId');
    c.onBroadcast(event: 'game-event', callback: (p) => onEvent(p));
    c.subscribe();
    _events = c;
  }

  Future<void> broadcastEvent(Map<String, dynamic> payload) async {
    await _events?.sendBroadcastMessage(event: 'game-event', payload: payload);
  }

  /// Presence : qui est connecté. Heartbeat serveur via touch_presence (15 s).
  Future<void> subscribePresence(
    String playerId,
    String nickname,
    void Function(List<dynamic>) onSync,
  ) async {
    final c = supa().channel('presence:game:$gameId');
    c
        .onPresenceSync((_) => onSync(c.presenceState()))
        .onPresenceJoin((_) => onSync(c.presenceState()))
        .onPresenceLeave((_) => onSync(c.presenceState()));
    c.subscribe();
    await c.track({'player_id': playerId, 'nickname': nickname});
    _presence = c;
  }

  Future<void> dispose() async {
    for (final c in [_changes, _events, _presence]) {
      if (c != null) await supa().removeChannel(c);
    }
  }
}

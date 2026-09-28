// Realtime Phase 2B : 1 canal Changes + 1 Broadcast + 1 Presence par partie.
// Cycles de vie explicites et idempotents : chaque subscribe* est sans effet
// s'il est déjà actif, dispose() retire tout sans jamais lever.
// Règles : Broadcast = hints de latence uniquement (l'état vient de
// Postgres/RPC, jamais du payload) ; Presence ≠ players.last_seen_at
// (le heartbeat DB via touch_presence est séparé, voir heartbeat.dart).
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class GameRealtime {
  final String gameId;
  RealtimeChannel? _changes;
  RealtimeChannel? _events;
  RealtimeChannel? _presence;
  bool _presenceTracked = false;

  GameRealtime(this.gameId);

  bool get hasChanges => _changes != null;
  bool get hasEvents => _events != null;
  bool get hasPresence => _presence != null;

  /// Dernier échec de track() (diagnostic ; jamais propagé à l'UI).
  Object? presenceTrackError;

  /// Écoute l'état durable (games/players/answers/wagers). RLS filtre déjà.
  void subscribeChanges({
    required void Function(Map<String, dynamic>) onGames,
    required void Function(Map<String, dynamic>) onPlayers,
    required void Function(Map<String, dynamic>) onScores,
  }) {
    if (_changes != null) return;
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

  /// Événements ponctuels (opened/locked/revealed/scores) : hints seulement.
  /// L'appelant doit recharger l'état autoritaire à chaque événement.
  void subscribeEvents(void Function(Map<String, dynamic>) onEvent) {
    if (_events != null) return;
    final c = supa().channel('game:$gameId');
    c.onBroadcast(event: 'game-event', callback: (p) => onEvent(p));
    c.subscribe();
    _events = c;
  }

  /// Envoie un hint. Crée/souscrit le canal si besoin (jamais null).
  /// Payloads sans secrets (jamais de réponse, jamais de score faisant foi).
  Future<void> broadcastEvent(Map<String, dynamic> payload) async {
    final c = _events ?? _ensureEventsChannel();
    await c.sendBroadcastMessage(event: 'game-event', payload: payload);
  }

  RealtimeChannel _ensureEventsChannel() {
    final c = supa().channel('game:$gameId');
    c.subscribe();
    _events = c;
    return c;
  }

  /// Presence : track() UNIQUEMENT après statut SUBSCRIBED (sinon perdu).
  /// Payload : player_id + nickname + online_at (pas de last_seen_at DB ici).
  Future<void> subscribePresence({
    required String playerId,
    required String nickname,
    required void Function(List<dynamic>) onSync,
  }) async {
    if (_presence != null) return;
    final c = supa().channel('presence:game:$gameId');
    _presence = c;
    _presenceTracked = false;
    c
        .onPresenceSync((_) => onSync(c.presenceState()))
        .onPresenceJoin((_) => onSync(c.presenceState()))
        .onPresenceLeave((_) => onSync(c.presenceState()));
    c.subscribe((status, [Object? _]) {
      if (status == RealtimeSubscribeStatus.subscribed && !_presenceTracked) {
        _presenceTracked = true;
        unawaited(_trackPresence(c, playerId: playerId, nickname: nickname));
      }
    });
  }

  Future<void> _trackPresence(
    RealtimeChannel c, {
    required String playerId,
    required String nickname,
  }) async {
    try {
      await c.track({
        'player_id': playerId,
        'nickname': nickname,
        'online_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      presenceTrackError = e;
    }
  }

  /// Retire tous les canaux. Idempotent, ne lève jamais.
  Future<void> dispose() async {
    final channels = [_changes, _events, _presence];
    _changes = null;
    _events = null;
    _presence = null;
    _presenceTracked = false;
    for (final c in channels) {
      if (c != null) {
        try {
          await supa().removeChannel(c);
        } catch (_) {
          // Canal déjà parti / réseau coupé : rien à faire.
        }
      }
    }
  }
}

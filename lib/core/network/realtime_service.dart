// Realtime Phase 2B : 1 canal Changes + 1 Broadcast + 1 Presence par partie.
// Cycles de vie explicites et idempotents : chaque subscribe* est sans effet
// s'il est déjà actif, dispose() retire tout sans jamais lever.
// Règles : Broadcast = hints de latence uniquement (l'état vient de
// Postgres/RPC, jamais du payload) ; Presence ≠ players.last_seen_at
// (le heartbeat DB via touch_presence est séparé, voir heartbeat.dart).
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

/// Suit le cycle de vie d'abonnement d'un canal (pur, testable).
/// Émet un rattrapage une seule fois par retour à SUBSCRIBED après un état
/// non-souscrit : des callbacks SUBSCRIBED dupliqués ne déclenchent PAS
/// de catch-up incontrôlé.
enum SubscribeEvent { initial, reconnect, duplicate, lost }

class SubscribeTracker {
  bool _currentlySubscribed = false;
  bool _everSubscribed = false;

  /// Signale un changement de statut. [isSubscribed] = statut SUBSCRIBED ?
  SubscribeEvent onStatus(bool isSubscribed) {
    if (!isSubscribed) {
      _currentlySubscribed = false;
      return SubscribeEvent.lost;
    }
    if (_currentlySubscribed) return SubscribeEvent.duplicate;
    _currentlySubscribed = true;
    final event =
        _everSubscribed ? SubscribeEvent.reconnect : SubscribeEvent.initial;
    _everSubscribed = true;
    return event;
  }

  void reset() {
    _currentlySubscribed = false;
    _everSubscribed = false;
  }
}

/// Sémantique de re-track Presence (pure, testable) : chaque SUBSCRIBED
/// réussi signifie "presence à tracker". Un seul track à la fois ; un
/// SUBSCRIBED pendant un track en cours arme exactement un suivi différé.
/// Jamais de retry agressif : une erreur ordinaire ne re-arme rien.
class PresenceRetrack {
  bool _inFlight = false;
  bool _pending = false;
  bool _disposed = false;

  /// Appelé à chaque SUBSCRIBED. Vrai → démarrer un track maintenant.
  bool onSubscribed() {
    if (_disposed) return false;
    if (_inFlight) {
      _pending = true;
      return false;
    }
    _inFlight = true;
    return true;
  }

  /// Appelé à la fin du track en cours. Vrai → exécuter exactement un suivi.
  bool onTrackDone() {
    _inFlight = false;
    if (_disposed || !_pending) {
      _pending = false;
      return false;
    }
    _pending = false;
    _inFlight = true;
    return true;
  }

  void dispose() {
    _disposed = true;
    _pending = false;
    _inFlight = false;
  }
}

class GameRealtime {
  final String gameId;
  RealtimeChannel? _changes;
  RealtimeChannel? _events;
  RealtimeChannel? _presence;
  final PresenceRetrack _presenceRetrack = PresenceRetrack();
  final SubscribeTracker _changesTracker = SubscribeTracker();

  GameRealtime(this.gameId);

  bool get hasChanges => _changes != null;
  bool get hasEvents => _events != null;
  bool get hasPresence => _presence != null;

  /// Dernier échec de track() (diagnostic ; jamais propagé à l'UI).
  Object? presenceTrackError;

  /// Écoute l'état durable (games/players/answers/wagers). RLS filtre déjà.
  /// [onSubscribed] distingue la première jonction (isReconnect: false) des
  /// SUBSCRIBED ultérieurs après reconnect/rejoin (isReconnect: true) :
  /// les Changes ne rejouent pas l'historique manqué, l'appelant doit
  /// recharger l'état autoritaire sur reconnect.
  void subscribeChanges({
    required void Function(Map<String, dynamic>) onGames,
    required void Function(Map<String, dynamic>) onPlayers,
    required void Function(Map<String, dynamic>) onScores,
    required void Function({required bool isReconnect}) onSubscribed,
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
    c.subscribe((status, [Object? _]) {
      switch (_changesTracker
          .onStatus(status == RealtimeSubscribeStatus.subscribed)) {
        case SubscribeEvent.initial:
          onSubscribed(isReconnect: false);
        case SubscribeEvent.reconnect:
          onSubscribed(isReconnect: true);
        case SubscribeEvent.duplicate:
        case SubscribeEvent.lost:
          break;
      }
    });
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

  /// Presence : track() UNIQUEMENT après statut SUBSCRIBED (sinon perdu),
  /// et à NOUVEAU à chaque re-SUBSCRIBED (le serveur oublie le track d'un
  /// canal déconnecté). Au plus un suivi différé si un SUBSCRIBED arrive
  /// pendant un track en cours ; jamais de retry agressif sur erreur.
  /// Payload : player_id + nickname + online_at (pas de last_seen_at DB ici).
  Future<void> subscribePresence({
    required String playerId,
    required String nickname,
    required void Function(List<dynamic>) onSync,
  }) async {
    if (_presence != null) return;
    final c = supa().channel('presence:game:$gameId');
    _presence = c;
    c
        .onPresenceSync((_) => onSync(c.presenceState()))
        .onPresenceJoin((_) => onSync(c.presenceState()))
        .onPresenceLeave((_) => onSync(c.presenceState()));
    c.subscribe((status, [Object? _]) {
      if (status == RealtimeSubscribeStatus.subscribed &&
          _presenceRetrack.onSubscribed()) {
        unawaited(_runPresenceTrack(c, playerId: playerId, nickname: nickname));
      }
    });
  }

  Future<void> _runPresenceTrack(
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
    // Un SUBSCRIBED pendant le track arme exactement un suivi, si actif.
    if (_presence != null && _presenceRetrack.onTrackDone()) {
      unawaited(_runPresenceTrack(c, playerId: playerId, nickname: nickname));
    }
  }

  /// Retire tous les canaux. Idempotent, ne lève jamais.
  Future<void> dispose() async {
    final channels = [_changes, _events, _presence];
    _changes = null;
    _events = null;
    _presence = null;
    _presenceRetrack.dispose();
    _changesTracker.reset();
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

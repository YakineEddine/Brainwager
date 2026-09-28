// SubscribeTracker/PresenceRetrack sont purs : l'import du service ne touche
// pas à Supabase tant qu'aucun GameRealtime n'est instancié.
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/core/network/realtime_service.dart';

void main() {
  group('SubscribeTracker', () {
    test('premier SUBSCRIBED = jonction initiale', () {
      final t = SubscribeTracker();
      expect(t.onStatus(true), SubscribeEvent.initial);
    });

    test('SUBSCRIBED dupliqué sans perte : pas de catch-up', () {
      final t = SubscribeTracker();
      expect(t.onStatus(true), SubscribeEvent.initial);
      expect(t.onStatus(true), SubscribeEvent.duplicate);
      expect(t.onStatus(true), SubscribeEvent.duplicate);
    });

    test('perte puis re-SUBSCRIBED = un seul reconnect', () {
      final t = SubscribeTracker();
      expect(t.onStatus(true), SubscribeEvent.initial);
      expect(t.onStatus(false), SubscribeEvent.lost);
      expect(t.onStatus(true), SubscribeEvent.reconnect);
      // Rejoin joué : un SUBSCRIBED immédiat redondant reste un doublon.
      expect(t.onStatus(true), SubscribeEvent.duplicate);
    });

    test('plusieurs cycles perte/rejoin', () {
      final t = SubscribeTracker();
      t.onStatus(true);
      t.onStatus(false);
      expect(t.onStatus(true), SubscribeEvent.reconnect);
      t.onStatus(false);
      expect(t.onStatus(true), SubscribeEvent.reconnect);
    });

    test('reset : prochaine jonction redevient initiale', () {
      final t = SubscribeTracker();
      t.onStatus(true);
      t.reset();
      expect(t.onStatus(true), SubscribeEvent.initial);
    });
  });

  group('PresenceRetrack', () {
    test('premier SUBSCRIBED -> un track', () {
      final t = PresenceRetrack();
      expect(t.onSubscribed(), isTrue);
    });

    test('second SUBSCRIBED après fin -> nouveau track', () {
      final t = PresenceRetrack();
      expect(t.onSubscribed(), isTrue);
      expect(t.onTrackDone(), isFalse); // Rien en attente.
      expect(t.onSubscribed(), isTrue);
    });

    test('SUBSCRIBED pendant un track -> exactement un suivi', () {
      final t = PresenceRetrack();
      expect(t.onSubscribed(), isTrue); // Track démarré.
      expect(t.onSubscribed(), isFalse); // En vol : différé, pas de doublon.
      expect(t.onSubscribed(), isFalse); // Re-différé : toujours un seul.
      expect(t.onTrackDone(), isTrue); // Le suivi s'exécute.
      expect(t.onTrackDone(), isFalse); // Suivi terminé : rien de plus.
    });

    test('erreur ordinaire sans SUBSCRIBED : pas de suivi spontané', () {
      final t = PresenceRetrack();
      expect(t.onSubscribed(), isTrue);
      expect(t.onTrackDone(), isFalse);
      expect(t.onTrackDone(), isFalse);
    });

    test('dispose/reset nettoie tout', () {
      final t = PresenceRetrack();
      expect(t.onSubscribed(), isTrue);
      expect(t.onSubscribed(), isFalse); // Différé armé.
      t.dispose();
      expect(t.onTrackDone(), isFalse); // Suivi annulé.
      expect(t.onSubscribed(), isFalse); // Plus rien après dispose.
    });
  });
}

// SubscribeTracker est pur : l'import du service ne touche pas à Supabase
// tant qu'aucun GameRealtime n'est instancié.
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/core/network/realtime_service.dart';

void main() {
  test('premier SUBSCRIBED = jonction initiale', () {
    final t = SubscribeTracker();
    expect(t.markSubscribed(), isFalse);
  });

  test('SUBSCRIBED ultérieur = reconnect', () {
    final t = SubscribeTracker();
    expect(t.markSubscribed(), isFalse);
    expect(t.markSubscribed(), isTrue);
    expect(t.markSubscribed(), isTrue);
  });

  test('reset après dispose : prochaine jonction redevient initiale', () {
    final t = SubscribeTracker();
    t.markSubscribed();
    t.reset();
    expect(t.markSubscribed(), isFalse);
  });
}

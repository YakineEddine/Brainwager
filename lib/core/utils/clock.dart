// Horloge Phase 2 : offset serveur mesuré via RPC server_time (moyenne de 3).
// Le compte à rebours reste calculé en local (aucun tick broadcast).
import '../network/supabase_client.dart';

class BrainClock {
  Duration offset = Duration.zero;

  Future<void> calibrate([int samples = 3]) async {
    if (!SupaConfig.isConfigured) {
      offset = Duration.zero;
      return;
    }
    final deltas = <Duration>[];
    for (var i = 0; i < samples; i++) {
      final before = DateTime.now().toUtc();
      final res = await supa().rpc('server_time');
      final after = DateTime.now().toUtc();
      final server = DateTime.parse(res as String).toUtc();
      final mid = before.add(after.difference(before) ~/ 2);
      deltas.add(server.difference(mid));
    }
    deltas.sort((a, b) => a.inMicroseconds.compareTo(b.inMicroseconds));
    offset = deltas[deltas.length ~/ 2];
  }

  DateTime nowUtc() => DateTime.now().toUtc().add(offset);
}

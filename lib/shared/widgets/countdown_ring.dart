// Anneau de compte à rebours : affiche remainingSec / durationSec.
// Le parent recalcule remainingSec à chaque seconde depuis opened_at absolu +
// offset serveur, donc reprise/reconnect restent exactes sans recevoir de tick.
// Aucun appel réseau ici, aucun timer interne (pas de dérive).
import 'package:flutter/material.dart';

class CountdownRing extends StatelessWidget {
  final int remainingSec;
  final int durationSec;
  const CountdownRing({
    super.key,
    required this.remainingSec,
    required this.durationSec,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = remainingSec < 0 ? 0 : remainingSec;
    final progress =
        durationSec <= 0 ? 0.0 : (remaining / durationSec).clamp(0.0, 1.0);
    final urgent = remaining <= 5;
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            color: urgent ? Colors.redAccent : null,
          ),
          Text('$remaining s'),
        ],
      ),
    );
  }
}

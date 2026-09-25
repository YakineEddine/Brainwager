// Compte à rebours 100 % client : restant = openedAt + duration − now.
// Aucun broadcast périodique (correction 6). openedAt vient du serveur,
// now est corrigé par l'offset mesuré via server_time().
import 'package:flutter/material.dart';

/// Calcule le temps restant (secondes). Jamais négatif.
int remainingSeconds({
  required DateTime openedAtUtc,
  required int durationSec,
  required DateTime nowUtc,
}) {
  final end = openedAtUtc.add(Duration(seconds: durationSec));
  final diff = end.difference(nowUtc).inSeconds;
  return diff < 0 ? 0 : diff;
}

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
    final progress =
        durationSec <= 0 ? 0.0 : remainingSec / durationSec;
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(value: progress),
          Text('$remainingSec s'),
        ],
      ),
    );
  }
}

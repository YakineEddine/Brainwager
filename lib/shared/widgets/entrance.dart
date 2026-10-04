// Entrée légère Phase brand-polish : fondu + glissement subtil, VRAI délai
// échelonné pour les listes (fraction de retard dans l'interpolation :
// palier à 0 pendant delayMs, puis 0 -> 1 sur ~280 ms). Flutter natif,
// sans package, sans StatefulWidget.
// Respecte MediaQuery.disableAnimations (rendu direct, sans mouvement).
import 'package:flutter/material.dart';

class BrainEntrance extends StatelessWidget {
  final Widget child;

  /// Délai réel avant le début de l'animation (ms, borné 0..400).
  final int delayMs;
  const BrainEntrance({super.key, required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final delay = delayMs.clamp(0, 400);
    const runMs = 280;
    final total = delay + runMs;
    return TweenAnimationBuilder<double>(
      tween: _DelayedTween(delayFraction: delay / total),
      duration: Duration(milliseconds: total),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Interpolation à retard réel : 0 jusqu'à delayFraction, puis 0 -> 1.
class _DelayedTween extends Tween<double> {
  final double delayFraction;
  _DelayedTween({required this.delayFraction}) : super(begin: 0, end: 1);

  @override
  double lerp(double t) {
    if (t <= delayFraction) return 0;
    return ((t - delayFraction) / (1 - delayFraction)).clamp(0.0, 1.0);
  }
}

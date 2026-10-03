// Entrée légère Phase brand-polish : fondu + glissement subtil, délai
// échelonné pour les listes. Flutter natif uniquement.
// Respecte MediaQuery.disableAnimations (rendu direct, sans mouvement).
import 'package:flutter/material.dart';

class BrainEntrance extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const BrainEntrance({super.key, required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + delayMs.clamp(0, 400)),
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

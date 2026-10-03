// Fond d'écran premium Brainwager : dégradé sombre + halos violets/or.
// RTL-safe (halos positionnés en relatif, jamais de gauche/droite durs).
// Utilisé par tous les écrans via BrainScaffold.
import 'package:flutter/material.dart';

import '../../app/theme.dart';

class BrainBackground extends StatelessWidget {
  final Widget child;
  const BrainBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [BrainColors.deepBackgroundTop, BrainColors.deepBackground],
        ),
      ),
      child: Stack(
        children: [
          Positioned.directional(
            textDirection: direction,
            top: -70,
            start: -50,
            child: const _Halo(
              size: 220,
              color: BrainColors.electricViolet,
              opacity: 0.28,
            ),
          ),
          Positioned.directional(
            textDirection: direction,
            bottom: -90,
            end: -60,
            child: const _Halo(
              size: 260,
              color: BrainColors.electricVioletDeep,
              opacity: 0.35,
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Halo({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

/// Scaffold standard : fond premium + AppBar transparente.
// Tous les textes/comportements viennent de l'appelant (aucune chaîne ici).
class BrainScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  const BrainScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBar,
      body: BrainBackground(child: SafeArea(child: body)),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

// Surfaces Brainwager : cartes/panneaux en couches (fond + bordure violette
// + ombre douce). Le contenu reste à l'appelant (textes, logique).
import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';

/// Carte standard (thème Card + padding homogène).
/// [featured] : bordure or pour les contenus premium désirables
/// (packs premium verrouillés) — jamais pour un état d'erreur.
class BrainCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool featured;
  const BrainCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BrainSpacing.md),
    this.onTap,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final tap = onTap;
    // Splash d'encre AU-DESSUS du fond Card : InkWell à l'intérieur de la
    // Card (pas l'inverse), sans Material opaque imbriqué superflu.
    if (tap == null) return Card(shape: _shape(featured), child: content);
    return Card(
      shape: _shape(featured),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(BrainRadius.lg),
        child: content,
      ),
    );
  }

  ShapeBorder _shape(bool featured) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(BrainRadius.lg),
    side: BorderSide(
      color: featured
          ? BrainColors.gold.withValues(alpha: 0.65)
          : BrainColors.outline,
      width: featured ? 1.5 : 1,
    ),
  );
}

/// Panneau hero : surface haute + bordure or subtile, pour codes/CTA.
/// Ex. code de partie, prix, statuts mis en avant.
class BrainHeroPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const BrainHeroPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BrainSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: BrainColors.surfaceHigh,
        borderRadius: BorderRadius.circular(BrainRadius.lg),
        border: Border.all(
          color: BrainColors.gold.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: BrainColors.electricViolet.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

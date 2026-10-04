// Badges Brainwager : chips colorés à emphase (premium, verrouillé,
// officiel, possédé…). Le texte vient de l'appelant (l10n).
import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';

enum BrainBadgeKind { premium, locked, official, mine, owned, info, success }

/// Chip unique : fonds pleins à fort contraste (texte 12 px lisible).
/// Jamais de texte coloré sur fond teinté.
class BrainBadge extends StatelessWidget {
  final String label;
  final BrainBadgeKind kind;
  const BrainBadge({super.key, required this.label, required this.kind});

  (Color, Color) get _colors {
    switch (kind) {
      case BrainBadgeKind.premium:
        return (BrainColors.gold, BrainColors.deepBackground);
      case BrainBadgeKind.locked:
        return (BrainColors.coral, BrainColors.deepBackground);
      case BrainBadgeKind.official:
        return (BrainColors.electricViolet, Colors.white);
      case BrainBadgeKind.mine:
      case BrainBadgeKind.owned:
      case BrainBadgeKind.success:
        return (BrainColors.turquoise, Colors.white);
      case BrainBadgeKind.info:
        return (BrainColors.surfaceHigh, BrainColors.textPrimary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BrainSpacing.sm,
        vertical: BrainSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(BrainRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Ligne de badges (wrap RTL-safe).
class BrainBadgeRow extends StatelessWidget {
  final List<Widget> badges;
  const BrainBadgeRow({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: BrainSpacing.xs,
      runSpacing: BrainSpacing.xs,
      children: badges,
    );
  }
}

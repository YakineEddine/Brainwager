// Badges Brainwager : chips colorés à emphase (premium, verrouillé,
// officiel, possédé…). Le texte vient de l'appelant (l10n).
import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';

enum BrainBadgeKind { premium, locked, official, mine, owned, info, success }

/// Chip unique : remplace les Text() bruts des badges actuels.
class BrainBadge extends StatelessWidget {
  final String label;
  final BrainBadgeKind kind;
  const BrainBadge({super.key, required this.label, required this.kind});

  Color get _color {
    switch (kind) {
      case BrainBadgeKind.premium:
        return BrainColors.gold;
      case BrainBadgeKind.locked:
        return BrainColors.coral;
      case BrainBadgeKind.official:
        return BrainColors.electricViolet;
      case BrainBadgeKind.mine:
        return BrainColors.turquoise;
      case BrainBadgeKind.owned:
        return BrainColors.turquoise;
      case BrainBadgeKind.success:
        return BrainColors.turquoise;
      case BrainBadgeKind.info:
        return BrainColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BrainSpacing.sm,
        vertical: BrainSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(BrainRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
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

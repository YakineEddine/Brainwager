// Sélecteur de mise Phase UI-2 : jetons de jeu, pas un formulaire.
// Normales : 1–10. Finale : 0/10/20 (variante accentuée).
// États : sélectionnable / sélectionné (or, évident) / déjà-utilisé
// (visible mais indisponible) / désactivé. Règles inchangées (appelant).
import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';

class BrainWagerSelector extends StatelessWidget {
  final List<int> wagers;
  final int selected;
  final Set<int> used;
  final bool enabled;
  final bool isFinal;
  final ValueChanged<int>? onSelect;
  const BrainWagerSelector({
    super.key,
    required this.wagers,
    required this.selected,
    required this.used,
    required this.enabled,
    required this.isFinal,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: BrainSpacing.sm,
      runSpacing: BrainSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        for (final w in wagers)
          BrainWagerToken(
            value: w,
            selected: selected == w,
            used: used.contains(w),
            enabled: enabled,
            isFinal: isFinal,
            onTap: enabled && !used.contains(w)
                ? () => onSelect?.call(w)
                : null,
          ),
      ],
    );
  }
}

/// Jeton de mise : pièce de jeu ronde, état lisible d'un coup d'œil.
class BrainWagerToken extends StatelessWidget {
  final int value;
  final bool selected;
  final bool used;
  final bool enabled;
  final bool isFinal;
  final VoidCallback? onTap;
  const BrainWagerToken({
    super.key,
    required this.value,
    required this.selected,
    required this.used,
    required this.enabled,
    required this.isFinal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && !used && onTap != null;
    final size = isFinal ? 68.0 : 56.0;
    final dimmed = !enabled || used;
    final fill = selected
        ? BrainColors.gold
        : dimmed
        ? BrainColors.surfaceHigh.withValues(alpha: 0.6)
        : BrainColors.surfaceHigh;
    final border = selected
        ? BrainColors.gold
        : isFinal
        ? BrainColors.gold.withValues(alpha: 0.7)
        : BrainColors.electricViolet.withValues(alpha: 0.6);
    final numberStyle = TextStyle(
      fontSize: isFinal ? 22 : 19,
      fontWeight: FontWeight.w800,
      color: selected
          ? BrainColors.deepBackground
          : dimmed
          ? BrainColors.textSecondary
          : BrainColors.textPrimary,
      decoration: used ? TextDecoration.lineThrough : null,
      decorationColor: BrainColors.textSecondary,
    );
    final token = AnimatedScale(
      scale: selected ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 160),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: border, width: selected ? 3 : 2),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: BrainColors.gold.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: used
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$value', style: numberStyle),
                  const Icon(
                    Icons.lock_outline,
                    size: 12,
                    color: BrainColors.textSecondary,
                  ),
                ],
              )
            : Text('$value', style: numberStyle),
      ),
    );
    return Semantics(
      label: 'wager $value',
      selected: selected,
      enabled: interactive,
      button: true,
      child: GestureDetector(
        onTap: interactive ? onTap : null,
        child: Opacity(opacity: dimmed && !selected ? 0.55 : 1.0, child: token),
      ),
    );
  }
}

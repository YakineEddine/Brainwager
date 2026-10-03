// Résultat joueur Phase UI-2 : Correct/Incorrect + delta AUTORITATIFS
// (player_answers.is_correct / scored_points, ligne du joueur courant).
// Jamais de matcher local, jamais de calcul local. Affiché après reveal
// uniquement (l'appelant verrouille les statuts autorisés).
import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';

/// Met en forme un delta de score : +7, 0, -20.
String formatScoreDelta(int points) => points > 0 ? '+$points' : '$points';

class BrainPlayerResultPanel extends StatelessWidget {
  final bool isCorrect;
  final int scoredPoints;
  final String correctLabel;
  final String incorrectLabel;
  const BrainPlayerResultPanel({
    super.key,
    required this.isCorrect,
    required this.scoredPoints,
    required this.correctLabel,
    required this.incorrectLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? BrainColors.turquoise : BrainColors.coral;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BrainSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BrainRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 28,
          ),
          const SizedBox(width: BrainSpacing.sm),
          Flexible(
            child: Text(
              isCorrect ? correctLabel : incorrectLabel,
              style: textTheme.titleMedium?.copyWith(color: color),
            ),
          ),
          const SizedBox(width: BrainSpacing.md),
          Text(
            formatScoreDelta(scoredPoints),
            style: textTheme.headlineSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

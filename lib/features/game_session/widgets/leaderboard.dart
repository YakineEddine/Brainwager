// Classement intermédiaire Phase UI-2 : rang, pseudo, score AUTORITATIF.
// Top 3 accentués, joueur courant surligné. Entrée légère (fondu).
// Aucun calcul de score ici : standings déjà triés par le serveur côté lecture.
import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../standings.dart';

class BrainLeaderboard extends StatelessWidget {
  final List<GameStanding> standings;
  final List<int> ranks;
  final String? currentPlayerId;
  const BrainLeaderboard({
    super.key,
    required this.standings,
    required this.ranks,
    required this.currentPlayerId,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: Column(
        children: [
          for (var i = 0; i < standings.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == standings.length - 1 ? 0 : BrainSpacing.sm,
              ),
              child: _StandingRow(
                standing: standings[i],
                rank: ranks[i],
                highlighted:
                    currentPlayerId != null &&
                    currentPlayerId!.isNotEmpty &&
                    standings[i].playerId == currentPlayerId,
              ),
            ),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  final GameStanding standing;
  final int rank;
  final bool highlighted;
  const _StandingRow({
    required this.standing,
    required this.rank,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final medal = rank == 1
        ? BrainColors.gold
        : rank == 2
        ? BrainColors.textPrimary
        : rank == 3
        ? BrainColors.gold.withValues(alpha: 0.65)
        : BrainColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BrainSpacing.md,
        vertical: BrainSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? BrainColors.electricViolet.withValues(alpha: 0.35)
            : BrainColors.surface,
        borderRadius: BorderRadius.circular(BrainRadius.md),
        border: Border.all(
          color: highlighted ? BrainColors.electricViolet : BrainColors.outline,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#$rank',
              style: textTheme.titleMedium?.copyWith(color: medal),
            ),
          ),
          Expanded(
            child: Text(
              standing.nickname,
              style: textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: BrainSpacing.sm),
          Text(
            '${standing.score}',
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 20,
              color: rank == 1 ? BrainColors.gold : null,
            ),
          ),
        ],
      ),
    );
  }
}

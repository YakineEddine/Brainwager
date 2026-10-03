// Podium Phase UI-2 : top 3 mis en scène (1er dominant), suite du
// classement en dessous. Ex æquo : même rang affiché, aucun faux ordre
// (jamais de vainqueur inventé entre égaux). Scores 100 % serveur.
import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/brain_card.dart';
import '../standings.dart';

class BrainPodium extends StatelessWidget {
  final List<GameStanding> standings;
  final List<int> ranks;
  final String? currentPlayerId;
  const BrainPodium({
    super.key,
    required this.standings,
    required this.ranks,
    required this.currentPlayerId,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final top = standings.length > 3 ? 3 : standings.length;
    bool isMe(int i) =>
        currentPlayerId != null &&
        currentPlayerId!.isNotEmpty &&
        standings[i].playerId == currentPlayerId;
    Widget card(int i, {required bool hero}) {
      final s = standings[i];
      return BrainHeroPanel(
        child: Column(
          children: [
            Text(
              '#${ranks[i]}',
              style: (hero ? textTheme.displaySmall : textTheme.headlineSmall)
                  ?.copyWith(color: BrainColors.gold),
            ),
            const SizedBox(height: 4),
            Text(
              s.nickname,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            Text('${s.score}', style: textTheme.headlineSmall),
            if (isMe(i))
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.person, color: BrainColors.electricViolet),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (top > 0) card(0, hero: true),
        if (top > 1) ...[
          const SizedBox(height: BrainSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card(1, hero: false)),
              const SizedBox(width: BrainSpacing.sm),
              if (top > 2) Expanded(child: card(2, hero: false)),
            ],
          ),
        ],
        if (standings.length > 3) ...[
          const SizedBox(height: BrainSpacing.md),
          for (var i = 3; i < standings.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: BrainSpacing.sm),
              child: BrainCard(
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text('#${ranks[i]}', style: textTheme.titleMedium),
                    ),
                    Expanded(
                      child: Text(
                        standings[i].nickname,
                        style: textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe(i))
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.person,
                          size: 18,
                          color: BrainColors.electricViolet,
                        ),
                      ),
                    Text('${standings[i].score}', style: textTheme.titleLarge),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

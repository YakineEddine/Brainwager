// Podium Phase UI-2 : hiérarchie honnête face aux égalités.
// - Vainqueur unique (#1 seul) : hero dominant + #2/#3 secondaires.
// - Premiers ex æquo : TOUS les #1 en cartes égales (jamais de faux
//   vainqueur via l'ordre alphabétique d'affichage), y compris >3 #1 :
//   traitement groupé vertical, suite du classement en dessous.
// Scores 100 % serveur. RTL-safe (directionnel uniquement).
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

  bool _isMe(int i) =>
      currentPlayerId != null &&
      currentPlayerId!.isNotEmpty &&
      standings[i].playerId == currentPlayerId;

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) return const SizedBox.shrink();
    final unique = hasUniqueWinner(ranks);
    if (unique) return _uniquePodium(context);
    return _tiedPodium(context);
  }

  /// Vainqueur unique : hero #1 dominant, #2/#3 secondaires, suite en lignes.
  Widget _uniquePodium(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final top = standings.length > 3 ? 3 : standings.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heroCard(context, 0),
        if (top > 1) ...[
          const SizedBox(height: BrainSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _placeCard(context, 1)),
              const SizedBox(width: BrainSpacing.sm),
              if (top > 2) Expanded(child: _placeCard(context, 2)),
            ],
          ),
        ],
        if (standings.length > 3) ...[
          const SizedBox(height: BrainSpacing.md),
          for (var i = 3; i < standings.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: BrainSpacing.sm),
              child: _rankRow(context, i, textTheme),
            ),
        ],
      ],
    );
  }

  /// Premiers ex æquo : cartes égales pour TOUS les #1 (même >3),
  /// puis la suite du classement naturellement en dessous.
  Widget _tiedPodium(BuildContext context) {
    final firsts = <int>[];
    final rest = <int>[];
    for (var i = 0; i < standings.length; i++) {
      if (ranks[i] == 1) {
        firsts.add(i);
      } else {
        rest.add(i);
      }
    }
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final i in firsts) ...[
          _equalFirstCard(context, i, textTheme),
          const SizedBox(height: BrainSpacing.sm),
        ],
        for (final i in rest)
          Padding(
            padding: const EdgeInsets.only(bottom: BrainSpacing.sm),
            child: _rankRow(context, i, textTheme),
          ),
      ],
    );
  }

  Widget _heroCard(BuildContext context, int i) {
    final textTheme = Theme.of(context).textTheme;
    final s = standings[i];
    return BrainHeroPanel(
      child: Column(
        children: [
          Text(
            '#${ranks[i]}',
            style: textTheme.displaySmall?.copyWith(
              color: BrainColors.goldDeep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.nickname,
            style: textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          Text('${s.score}', style: textTheme.headlineSmall),
          if (_isMe(i))
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.person, color: BrainColors.electricViolet),
            ),
        ],
      ),
    );
  }

  Widget _placeCard(BuildContext context, int i) {
    final textTheme = Theme.of(context).textTheme;
    final s = standings[i];
    return BrainHeroPanel(
      child: Column(
        children: [
          Text(
            '#${ranks[i]}',
            style: textTheme.headlineSmall?.copyWith(
              color: BrainColors.goldDeep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.nickname,
            style: textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          Text('${s.score}', style: textTheme.headlineSmall),
          if (_isMe(i))
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.person, color: BrainColors.electricViolet),
            ),
        ],
      ),
    );
  }

  /// Carte #1 ex æquo : importance STRICTEMENT égale entre premiers
  /// (même style pour tous, aucun hero dominant).
  Widget _equalFirstCard(BuildContext context, int i, TextTheme textTheme) {
    final s = standings[i];
    return BrainCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: BrainColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(BrainRadius.pill),
              border: Border.all(
                color: BrainColors.gold.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              '#${ranks[i]}',
              style: textTheme.titleMedium?.copyWith(
                color: BrainColors.goldDeep,
              ),
            ),
          ),
          const SizedBox(width: BrainSpacing.md),
          Expanded(
            child: Text(
              s.nickname,
              style: textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isMe(i))
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 8),
              child: Icon(
                Icons.person,
                size: 18,
                color: BrainColors.electricViolet,
              ),
            ),
          Text('${s.score}', style: textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _rankRow(BuildContext context, int i, TextTheme textTheme) {
    return BrainCard(
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
          if (_isMe(i))
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 8),
              child: Icon(
                Icons.person,
                size: 18,
                color: BrainColors.electricViolet,
              ),
            ),
          Text('${standings[i].score}', style: textTheme.titleLarge),
        ],
      ),
    );
  }
}

// Révélation Phase UI-2 : moment visuel majeur (lueur or + entrée
// échelle/fondu). Compose RevealedAnswerView (direction contenu, testé) :
// le label et la réponse viennent du serveur (reveal_answer).
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/brain_card.dart';
import '../game_screen.dart' show RevealedAnswerView;

class BrainRevealPanel extends StatelessWidget {
  final String label;
  final String answer;
  final String languageCode;
  const BrainRevealPanel({
    super.key,
    required this.label,
    required this.answer,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Opacity(
        opacity: 0.4 + 0.6 * ((scale - 0.92) / 0.08).clamp(0.0, 1.0),
        child: Transform.scale(scale: scale, child: child),
      ),
      child: BrainHeroPanel(
        child: Column(
          children: [
            const Icon(Icons.celebration, color: BrainColors.gold, size: 36),
            const SizedBox(height: 8),
            RevealedAnswerView(
              label: label,
              answer: answer,
              languageCode: languageCode,
            ),
          ],
        ),
      ),
    );
  }
}

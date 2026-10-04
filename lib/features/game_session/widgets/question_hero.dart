// Hero question Phase UI-2 : compteur "3 / 11", prompt dominant, timer.
// Le prompt suit la direction du CONTENU de partie (serveur), jamais celle
// de la locale UI. Le compteur reste LTR (pas de flip bidi en arabe).
// Finale : cadre or renforcé + rappel des règles (finalWagerTitle).
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/brain_card.dart';

class BrainQuestionHero extends StatelessWidget {
  final int position;
  final int total;
  final String prompt;
  final String languageCode;
  final bool isFinal;
  final String? finalLabel;
  final Widget timer;

  /// URL d'image officielle (image_url du RPC) : optionnelle, défensive.
  /// Absente/illisible => masquée sans casser la mise en page.
  /// (UGC : toujours null, images interdites côté serveur.)
  final String? imageUrl;
  const BrainQuestionHero({
    super.key,
    required this.position,
    required this.total,
    required this.prompt,
    required this.languageCode,
    required this.isFinal,
    this.finalLabel,
    required this.timer,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = languageCode == 'ar';
    final label = finalLabel;
    final image = imageUrl;
    return BrainHeroPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      (isFinal ? BrainColors.gold : BrainColors.electricViolet)
                          .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${position + 1} / $total',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: BrainColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            prompt,
            style: Theme.of(context).textTheme.headlineSmall,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            textAlign: rtl ? TextAlign.right : TextAlign.left,
          ),
          if (isFinal && label != null && label.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: BrainColors.goldDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (image != null && image.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(child: timer),
        ],
      ),
    );
  }
}

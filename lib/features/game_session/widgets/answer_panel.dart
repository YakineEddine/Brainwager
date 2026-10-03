// Panneau réponse Phase UI-2 : carte dédiée (plus de champ nu), focus
// marqué, bouton de soumission intégré visuellement au panneau.
// États pilotés par l'appelant : editable / submitting / locked.
// Direction du CONTENU de partie (serveur), jamais locale UI.
import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/brain_buttons.dart';
import '../../../shared/widgets/brain_card.dart';

class BrainAnswerPanel extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String languageCode;
  final String hintLabel;
  final String submitLabel;
  final bool submitting;
  final VoidCallback? onSubmit;
  final ValueChanged<String> onChanged;

  /// Slot mises : rendu entre le champ et le CTA (une soumission =
  /// réponse + mise, l'utilisateur décide des deux avant de valider).
  final Widget? wagerContent;

  /// Slot feedback : rendu sous le CTA (sauvé / modifié).
  final Widget? statusContent;
  const BrainAnswerPanel({
    super.key,
    required this.controller,
    required this.enabled,
    required this.languageCode,
    required this.hintLabel,
    required this.submitLabel,
    required this.submitting,
    required this.onSubmit,
    required this.onChanged,
    this.wagerContent,
    this.statusContent,
  });

  @override
  Widget build(BuildContext context) {
    final wager = wagerContent;
    final status = statusContent;
    return BrainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            enabled: enabled && !submitting,
            textDirection: languageCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            style: const TextStyle(fontSize: 18),
            onChanged: onChanged,
            decoration: InputDecoration(labelText: hintLabel),
          ),
          if (wager != null) ...[
            const SizedBox(height: BrainSpacing.md),
            wager,
          ],
          const SizedBox(height: BrainSpacing.md),
          BrainPrimaryButton(
            onPressed: submitting ? null : onSubmit,
            child: submitting
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: BrainSpacing.sm),
                      Text(submitLabel),
                    ],
                  )
                : Text(submitLabel),
          ),
          if (status != null) ...[
            const SizedBox(height: BrainSpacing.sm),
            status,
          ],
        ],
      ),
    );
  }
}

/// Feedback de soumission : badge succès discret (apparition animée) ou
/// avertissement "modifié, à revalider". Jamais de correctness avant reveal.
class BrainSubmissionStatus extends StatelessWidget {
  final bool saved;
  final bool edited;
  final String savedLabel;
  final String editedLabel;
  const BrainSubmissionStatus({
    super.key,
    required this.saved,
    required this.edited,
    required this.savedLabel,
    required this.editedLabel,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? badge;
    if (saved) {
      badge = _StatusChip(
        key: const ValueKey('saved'),
        icon: Icons.check_circle,
        color: BrainColors.turquoise,
        label: savedLabel,
      );
    } else if (edited) {
      badge = _StatusChip(
        key: const ValueKey('edited'),
        icon: Icons.edit,
        color: BrainColors.gold,
        label: editedLabel,
      );
    } else {
      badge = null;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: badge ?? const SizedBox.shrink(key: ValueKey('none')),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _StatusChip({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BrainSpacing.md,
        vertical: BrainSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(BrainRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: BrainSpacing.sm),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

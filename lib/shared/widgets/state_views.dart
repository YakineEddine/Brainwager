// États Brainwager : chargement / vide / erreur avec retry.
// Unifie les états aujourd'hui bricolés écran par écran.
// Les libellés viennent de l'appelant (l10n) : aucun texte en dur ici
// sauf le strict minimum structurel.
import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import 'brain_buttons.dart';

class BrainLoading extends StatelessWidget {
  const BrainLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class BrainEmpty extends StatelessWidget {
  final String message;
  final IconData icon;
  const BrainEmpty({super.key, required this.message, this.icon = Icons.inbox});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BrainSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: textTheme.bodyMedium?.color),
            const SizedBox(height: BrainSpacing.sm),
            Text(
              message,
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class BrainError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  const BrainError({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BrainSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null && retryLabel != null) ...[
              const SizedBox(height: BrainSpacing.md),
              BrainSecondaryButton(
                onPressed: onRetry,
                child: Text(retryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

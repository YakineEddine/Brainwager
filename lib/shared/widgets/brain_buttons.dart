// Boutons Brainwager : wrappers fins des boutons Material (mêmes classes
// sous-jacentes : Elevated/Outlined/TextButton) pour une emphase CTA
// constante. Aucune chaîne ici ; les libellés viennent de l'appelant.
import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

/// CTA principal (heritage ElevatedButton : style thème, hauteur 56).
class BrainPrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool expanded;
  const BrainPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(onPressed: onPressed, child: child);
    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Action secondaire (OutlinedButton thème).
class BrainSecondaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool expanded;
  const BrainSecondaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(onPressed: onPressed, child: child);
    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Action discrète (TextButton thème).
class BrainGhostButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const BrainGhostButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onPressed, child: child);
  }
}

/// Carte menu compacte (secondaire, demi-largeur) : icône au-dessus du
/// libellé, centrée, titre sur 2 lignes max. Hauteurs égales obtenues par
/// la Row parente (crossAxisAlignment.stretch). 48dp+ garanti, RTL-safe.
class BrainCompactMenuCard extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String title;
  final Color iconColor;
  const BrainCompactMenuCard({
    super.key,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrainRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BrainSpacing.sm,
            vertical: BrainSpacing.md,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(BrainRadius.md),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(height: BrainSpacing.sm),
                Text(
                  title,
                  style: textTheme.titleSmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grand bouton menu (Home, pleine largeur) : carte cliquable avec
/// icône + libellé + chevron. Conçu pour la pleine largeur uniquement ;
/// en demi-largeur, préférer BrainCompactMenuCard.
class BrainMenuCard extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  const BrainMenuCard({
    super.key,
    required this.onTap,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrainRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(BrainSpacing.md),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(BrainRadius.md),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: BrainSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: textTheme.titleMedium),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: BrainSpacing.xs),
                        child: Text(subtitle!, style: textTheme.bodyMedium),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

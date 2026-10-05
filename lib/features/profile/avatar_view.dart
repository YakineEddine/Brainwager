// Avatar Brainwager réutilisable (profil/onboarding, lobby/futur
// classement) : mapping local clé -> icône Material. La DISPONIBILITÉ
// vient du serveur (unlocked) ; l'art est une représentation locale.
// La SÉLECTION visuelle suit `selectedKey` quand fourni (état local
// immédiat, sans attendre le serveur) ; sinon le flag serveur.
// Les libellés d'accessibilité sont localisés (jamais la clé brute).
import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'profile.dart';

IconData avatarIconFor(String avatarKey) {
  switch (avatarKey) {
    case 'brain':
      return Icons.psychology;
    case 'rocket':
      return Icons.rocket_launch;
    case 'star':
      return Icons.star;
    case 'bolt':
      return Icons.bolt;
    case 'planet':
      return Icons.public;
    case 'trophy':
      return Icons.emoji_events;
    case 'football':
      return Icons.sports_soccer;
    case 'basketball':
      return Icons.sports_basketball;
    default:
      return Icons.person;
  }
}

/// Nom localisé pour lecteurs d'écran. Clé inconnue => générique localisé,
/// jamais la clé brute de la base.
String avatarNameFor(String avatarKey, AppLocalizations l10n) {
  switch (avatarKey) {
    case 'brain':
      return l10n.avatarBrain;
    case 'rocket':
      return l10n.avatarRocket;
    case 'star':
      return l10n.avatarStar;
    case 'bolt':
      return l10n.avatarLightning;
    case 'planet':
      return l10n.avatarPlanet;
    case 'trophy':
      return l10n.avatarTrophy;
    case 'football':
      return l10n.avatarFootball;
    case 'basketball':
      return l10n.avatarBasketball;
    default:
      return l10n.profileAvatar;
  }
}

/// Avatar circulaire : fond lumineux, sélection évidente (anneau + check),
/// verrouillé = visible mais insensible (cadenas). Jamais de faux débloqué.
class BrainAvatarView extends StatelessWidget {
  final BrainAvatar avatar;

  /// Surcharge visuelle locale (ex. choix en cours) ; null => flag serveur.
  final bool? selected;

  /// Libellé d'accessibilité localisé ; null => clé brute (éviter : les
  /// appelants passent `avatarNameFor`).
  final String? semanticLabel;
  final double size;
  final bool selectable;
  final VoidCallback? onSelect;
  const BrainAvatarView({
    super.key,
    required this.avatar,
    this.selected,
    this.semanticLabel,
    this.size = 64,
    this.selectable = true,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected ?? avatar.selected;
    final interactive = selectable && avatar.unlocked && onSelect != null;
    return Semantics(
      label: semanticLabel ?? avatar.avatarKey,
      selected: isSelected,
      enabled: interactive,
      button: true,
      child: GestureDetector(
        onTap: interactive ? onSelect : null,
        child: AnimatedScale(
          scale: isSelected ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 160),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? BrainColors.electricViolet.withValues(alpha: 0.16)
                  : BrainColors.surfaceHigh,
              border: Border.all(
                color: isSelected
                    ? BrainColors.electricViolet
                    : BrainColors.outline,
                width: isSelected ? 3 : 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  avatarIconFor(avatar.avatarKey),
                  size: size * 0.48,
                  color: avatar.unlocked
                      ? BrainColors.textPrimary
                      : BrainColors.textSecondary,
                ),
                if (!avatar.unlocked)
                  Positioned(
                    bottom: size * 0.08,
                    right: size * 0.08,
                    child: const Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: BrainColors.textSecondary,
                    ),
                  ),
                if (isSelected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: BrainColors.electricViolet,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grille de choix : seuls les unlocked sont sélectionnables.
/// `selectedKey` (état local immédiat) prime sur le flag serveur.
/// Le serveur (update_my_profile) tranche en dernier ressort.
class BrainAvatarChooser extends StatelessWidget {
  final List<BrainAvatar> avatars;

  /// Sélection visuelle locale ; null => flags serveur.
  final String? selectedKey;

  /// Libellés localisés par clé (ex. `(k) => avatarNameFor(k, l10n)`).
  final String Function(String avatarKey)? semanticLabelFor;
  final ValueChanged<String> onSelect;
  const BrainAvatarChooser({
    super.key,
    required this.avatars,
    this.selectedKey,
    this.semanticLabelFor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: BrainSpacing.sm,
      runSpacing: BrainSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        for (final a in avatars)
          BrainAvatarView(
            key: ValueKey('avatar-${a.avatarKey}'),
            avatar: a,
            selected: selectedKey == null ? null : a.avatarKey == selectedKey,
            semanticLabel: semanticLabelFor?.call(a.avatarKey),
            onSelect: () => onSelect(a.avatarKey),
          ),
      ],
    );
  }
}

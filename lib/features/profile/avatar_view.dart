// Avatar Brainwager réutilisable (profil/onboarding, lobby/futur
// classement) : mapping local clé -> icône Material. La DISPONIBILITÉ
// vient du serveur (unlocked) ; l'art est une représentation locale.
import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';
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

/// Avatar circulaire : fond lumineux, sélection évidente (anneau + check),
/// verrouillé = visible mais insensible (cadenas). Jamais de faux débloqué.
class BrainAvatarView extends StatelessWidget {
  final BrainAvatar avatar;
  final double size;
  final bool selectable;
  final VoidCallback? onSelect;
  const BrainAvatarView({
    super.key,
    required this.avatar,
    this.size = 64,
    this.selectable = true,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final interactive = selectable && avatar.unlocked && onSelect != null;
    return Semantics(
      label: avatar.avatarKey,
      selected: avatar.selected,
      enabled: interactive,
      button: true,
      child: GestureDetector(
        onTap: interactive ? onSelect : null,
        child: AnimatedScale(
          scale: avatar.selected ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 160),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatar.selected
                  ? BrainColors.electricViolet.withValues(alpha: 0.16)
                  : BrainColors.surfaceHigh,
              border: Border.all(
                color: avatar.selected
                    ? BrainColors.electricViolet
                    : BrainColors.outline,
                width: avatar.selected ? 3 : 1.5,
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
                if (avatar.selected)
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
/// Le serveur (update_my_profile) tranche en dernier ressort.
class BrainAvatarChooser extends StatelessWidget {
  final List<BrainAvatar> avatars;
  final ValueChanged<String> onSelect;
  const BrainAvatarChooser({
    super.key,
    required this.avatars,
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
          BrainAvatarView(avatar: a, onSelect: () => onSelect(a.avatarKey)),
      ],
    );
  }
}

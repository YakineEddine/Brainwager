// Profil : données serveur 0014 (get_my_profile / list_my_avatars).
// Anonyme (état contrôleur) => "Sécuriser" (linkIdentity, UUID préservé).
// Non-anonyme => identités connectées (getUserIdentities, sans tokens).
// Édition : pseudo + avatars débloqués, save via update_my_profile,
// sélection visuelle immédiate (selectedKey local).
// Ni suppression, ni unlink, ni sign-out dans ce ticket.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/brain_buttons.dart';
import '../../shared/widgets/brain_card.dart';
import '../../shared/widgets/brain_scaffold.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/state_views.dart';
import 'avatar_view.dart';
import 'profile.dart';
import 'profile_controller.dart';
import 'profile_errors.dart';

/// Pseudo connu localement (métadonnées auth), sinon null.
/// Aucun appel réseau ici (la fiche profiles complète viendra plus tard).
String? localDisplayName(Map<String, dynamic>? metadata) {
  final raw = metadata?['display_name'];
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  return null;
}

/// Avatar visible : clé du profil d'abord (jamais un flag serveur périmé),
/// repli sur le flag serveur, sinon aucun (icône générique).
BrainAvatarView? resolveVisibleAvatar(
  List<BrainAvatar> avatars,
  String profileAvatarKey, {
  required String Function(String avatarKey) labelFor,
  double size = 64,
}) {
  for (final a in avatars) {
    if (a.avatarKey == profileAvatarKey) {
      return BrainAvatarView(
        key: ValueKey('avatar-${a.avatarKey}'),
        avatar: a,
        selected: true,
        semanticLabel: labelFor(a.avatarKey),
        size: size,
      );
    }
  }
  for (final a in avatars) {
    if (a.selected) {
      return BrainAvatarView(
        key: ValueKey('avatar-${a.avatarKey}'),
        avatar: a,
        semanticLabel: labelFor(a.avatarKey),
        size: size,
      );
    }
  }
  return null;
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  bool _editing = false;
  bool _touched = false;
  String? _avatarKey;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    final profile = state.profile;

    // État compte autoritaire (contrôleur) : jamais supa() direct ici.
    final anonymous = state.isAnonymous;

    if (profile == null) {
      return BrainScaffold(
        appBar: AppBar(title: Text(l10n.profileTitle)),
        body: state.profileLoading
            ? const BrainLoading()
            : BrainError(
                message: state.profileError != null
                    ? friendlyProfileError(state.profileError!, l10n)
                    : l10n.profileLoadError,
                onRetry: () => controller.reloadAll(),
                retryLabel: l10n.retry,
              ),
      );
    }

    if (!_editing) {
      _avatarKey = profile.avatarKey;
      if (!_touched && _name.text.isEmpty && profile.displayName.isNotEmpty) {
        _name.text = profile.displayName;
      }
    }
    final visibleAvatar = resolveVisibleAvatar(
      state.avatars,
      profile.avatarKey,
      labelFor: (k) => avatarNameFor(k, l10n),
    );

    return BrainScaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: BrainBrand(variant: BrainBrandVariant.markOnly, height: 88),
          ),
          const SizedBox(height: 16),
          BrainCard(
            child: Row(
              children: [
                if (visibleAvatar != null)
                  visibleAvatar
                else
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BrainColors.surfaceHigh,
                      border: Border.all(
                        color: BrainColors.outline,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.person,
                      size: 34,
                      color: BrainColors.textSecondary,
                      semanticLabel: l10n.profileAvatar,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName.isNotEmpty
                            ? profile.displayName
                            : l10n.profileGuest,
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        anonymous ? l10n.accountGuest : l10n.accountConnected,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BrainCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.language,
                      color: BrainColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.profileLocale,
                        style: textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      profile.locale.toUpperCase(),
                      style: textTheme.bodyLarge,
                    ),
                  ],
                ),
                if (!anonymous && state.providers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user,
                        color: BrainColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.connectedWith(state.providers.join(', ')),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (anonymous) ...[
            BrainCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(title: l10n.secureAccount),
                  BrainSecondaryButton(
                    expanded: true,
                    onPressed: state.oauthPending
                        ? null
                        : () => controller.secureWithGoogle(),
                    child: Text(l10n.continueGoogle),
                  ),
                  const SizedBox(height: 8),
                  BrainSecondaryButton(
                    expanded: true,
                    onPressed: state.oauthPending
                        ? null
                        : () => controller.secureWithFacebook(),
                    child: Text(l10n.continueFacebook),
                  ),
                  if (state.oauthPending)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.oauthPending,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (state.oauthError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        friendlyProfileError(state.oauthError!, l10n),
                        style: const TextStyle(color: BrainColors.coral),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          BrainCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: l10n.editProfile,
                  trailing: _editing
                      ? null
                      : BrainGhostButton(
                          onPressed: () => setState(() => _editing = true),
                          child: Text(l10n.editProfile),
                        ),
                ),
                if (_editing) ...[
                  TextField(
                    controller: _name,
                    textDirection: lang == 'ar'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    decoration: InputDecoration(labelText: l10n.displayName),
                    onChanged: (_) => _touched = true,
                  ),
                  const SizedBox(height: 12),
                  SectionHeader(title: l10n.chooseAvatar),
                  BrainAvatarChooser(
                    avatars: state.avatars,
                    selectedKey: _avatarKey ?? profile.avatarKey,
                    semanticLabelFor: (k) => avatarNameFor(k, l10n),
                    onSelect: (key) => setState(() => _avatarKey = key),
                  ),
                  const SizedBox(height: 12),
                  BrainPrimaryButton(
                    onPressed: state.saving
                        ? null
                        : () async {
                            final ok = await controller.save(
                              displayName: _name.text,
                              avatarKey: _avatarKey ?? profile.avatarKey,
                              locale: lang,
                            );
                            if (ok && context.mounted) {
                              setState(() {
                                _editing = false;
                                _touched = false;
                              });
                            }
                          },
                    child: Text(l10n.saveProfile),
                  ),
                  if (state.saveError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        friendlyProfileError(state.saveError!, l10n),
                        style: const TextStyle(color: BrainColors.coral),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 8),
                  BrainGhostButton(
                    onPressed: () => setState(() {
                      // Annulation : restaure les valeurs serveur
                      // (aucun RPC), sans garder la frappe/avatar non sauvés.
                      _editing = false;
                      _touched = false;
                      _name.text = profile.displayName;
                      _avatarKey = profile.avatarKey;
                    }),
                    child: Text(l10n.back),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

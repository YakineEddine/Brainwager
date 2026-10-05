// Onboarding Phase social : bienvenue + pseudo + avatar + compte.
// Design clair (shell). Une seule sauvegarde via update_my_profile
// (invité ou lié) ; la gate s'ouvre sur onboarding_complete serveur.
// La localisation router est préservée (la gate remasque l'enfant).
// Account-aware : après link (non-anonyme), le CTA invité et les
// contrôles guest-only disparaissent (état contrôleur, jamais supa()
// direct). Sélection avatar immédiate via selectedKey local.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/brain_buttons.dart';
import '../../shared/widgets/brain_card.dart';
import '../../shared/widgets/brain_scaffold.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/section_header.dart';
import 'auth_gateway.dart';
import 'avatar_view.dart';
import 'profile.dart';
import 'profile_controller.dart';
import 'profile_errors.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  bool _touchedName = false;
  bool _prefilled = false;
  String? _avatarKey;
  bool _showExisting = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Pré-remplissage unique depuis les métadonnées OAuth : jamais après
  /// que l'utilisateur a commencé à taper, jamais de valeur invalide.
  void _maybePrefill(SocialAuthGateway auth, List<BrainAvatar> avatars) {
    if (_prefilled || _touchedName) return;
    _prefilled = true;
    final suggestion = prefillDisplayName(auth.userMetadata);
    if (suggestion != null && _name.text.isEmpty) {
      _name.text = suggestion;
    }
    if (_avatarKey == null || _avatarKey!.isEmpty) {
      final unlocked = avatars.where((a) => a.unlocked).toList();
      BrainAvatar? current;
      for (final a in unlocked) {
        if (a.selected) current = a;
      }
      _avatarKey =
          current?.avatarKey ??
          (unlocked.isNotEmpty ? unlocked.first.avatarKey : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    final auth = ref.read(socialAuthGatewayProvider);
    if (state.profile != null || state.avatars.isNotEmpty) {
      _maybePrefill(auth, state.avatars);
    }
    final unlocked = state.avatars
        .where((a) => a.unlocked)
        .toList(growable: false);
    final selected =
        _avatarKey ?? (unlocked.isNotEmpty ? unlocked.first.avatarKey : null);
    // État compte autoritaire (contrôleur) : après link, l'utilisateur
    // n'est plus anonyme => plus de CTA invité ni de contrôles guest-only.
    final anonymous = state.isAnonymous;

    return BrainScaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: BrainBrand(variant: BrainBrandVariant.full, centered: true),
          ),
          Text(
            l10n.welcome,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.secureAccountExplanation,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          BrainCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(title: l10n.displayName),
                TextField(
                  controller: _name,
                  textDirection: lang == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  decoration: InputDecoration(labelText: l10n.displayName),
                  onChanged: (_) => _touchedName = true,
                ),
                const SizedBox(height: 16),
                SectionHeader(title: l10n.chooseAvatar),
                if (state.avatarsLoading && state.avatars.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else
                  BrainAvatarChooser(
                    avatars: state.avatars,
                    selectedKey: selected,
                    semanticLabelFor: (k) => avatarNameFor(k, l10n),
                    onSelect: (key) => setState(() => _avatarKey = key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BrainPrimaryButton(
            onPressed: state.saving
                ? null
                : () => controller.save(
                    displayName: _name.text,
                    avatarKey: selected ?? '',
                    locale: lang,
                  ),
            child: Text(
              state.saving
                  ? l10n.oauthPending
                  : anonymous
                  ? l10n.continueGuest
                  : l10n.saveProfile,
            ),
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
          if (anonymous) ...[
            const SizedBox(height: 16),
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
                  const SizedBox(height: 8),
                  BrainGhostButton(
                    onPressed: () =>
                        setState(() => _showExisting = !_showExisting),
                    child: Text(l10n.alreadyHaveAccount),
                  ),
                  if (_showExisting) ...[
                    Text(
                      l10n.existingAccountWarning,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    BrainSecondaryButton(
                      expanded: true,
                      onPressed: state.oauthPending
                          ? null
                          : () => controller.signInExistingGoogle(),
                      child: Text(l10n.continueGoogle),
                    ),
                    const SizedBox(height: 8),
                    BrainSecondaryButton(
                      expanded: true,
                      onPressed: state.oauthPending
                          ? null
                          : () => controller.signInExistingFacebook(),
                      child: Text(l10n.continueFacebook),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (state.providers.isNotEmpty) ...[
            const SizedBox(height: 16),
            BrainCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user,
                    color: BrainColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.connectedWith(state.providers.join(', ')),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

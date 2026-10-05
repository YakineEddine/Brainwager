// Profil (fondation visuelle light-shell) : état rÉEL uniquement.
// Auth anonyme inchangée, pas d'OAuth : affiche l'utilisateur courant
// (anonyme => Invité), le pseudo s'il est connu en métadonnées, la locale.
// Aucune donnée inventée (ni avatar acheté, ni solde). Prêt pour le ticket
// liaison de compte + avatars (carte "bientôt" explicite).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/network/supabase_client.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/brain_card.dart';
import '../../shared/widgets/brain_scaffold.dart';
import '../../shared/widgets/brand.dart';

/// Pseudo connu localement (métadonnées auth), sinon null.
/// Aucun appel réseau ici (la fiche profiles complète viendra plus tard).
String? localDisplayName(Map<String, dynamic>? metadata) {
  final raw = metadata?['display_name'];
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  return null;
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    String? userId;
    bool anonymous = true;
    String? displayName;
    try {
      final user = supa().auth.currentUser;
      userId = user?.id;
      anonymous = user?.isAnonymous ?? true;
      displayName = localDisplayName(user?.userMetadata);
    } catch (_) {
      userId = null;
    }
    final shortId = userId != null && userId.length >= 8
        ? userId.substring(0, 8)
        : null;
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
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: BrainColors.surfaceHigh,
                    border: Border.all(color: BrainColors.outline, width: 1.5),
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
                        displayName ?? l10n.profileGuest,
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        anonymous ? l10n.profileAnonymous : (shortId ?? ''),
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
                    Text(lang.toUpperCase(), style: textTheme.bodyLarge),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BrainCard(
            child: Row(
              children: [
                const Icon(Icons.link, color: BrainColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.profileComingSoon,
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

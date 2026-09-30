// Écrans catalogue Phase 3A : /packs (liste) + /packs/:id (détail).
// Anti-triche : aperçu via get_pack_preview uniquement, jamais de réponses.
// Textes via l10n ARB + locale courante pour le contenu pack FR/EN.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import 'pack.dart';
import 'pack_providers.dart';

String _lang(BuildContext context) =>
    Localizations.localeOf(context).languageCode;

class PacksScreen extends ConsumerWidget {
  const PacksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(packCatalogProvider);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.packs)),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.packLoadError),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(packCatalogProvider),
                child: Text(l10n.packRetry),
              ),
            ],
          ),
        ),
        data: (c) {
          if (c.packs.isEmpty) return Center(child: Text(l10n.packEmpty));
          final lang = _lang(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final p in c.packs)
                Card(
                  child: ListTile(
                    title: Text(p.localizedTitle(lang)),
                    subtitle: Text(p.localizedDescription(lang)),
                    trailing: _PackBadges(
                      pack: p,
                      locked: !p.isAccessible(c.activeEntitlements),
                    ),
                    onTap: () => context.push('/packs/${p.id}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PackBadges extends StatelessWidget {
  final PackSummary pack;
  final bool locked;
  const _PackBadges({required this.pack, required this.locked});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(pack.isOfficial ? l10n.packOfficial : l10n.packMine),
        if (pack.isPremium) Text(l10n.packPremium),
        if (locked) Text(l10n.packLocked),
      ],
    );
  }
}

class PackDetailScreen extends ConsumerWidget {
  final String packId;
  const PackDetailScreen({super.key, required this.packId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(packCatalogProvider);
    final l10n = AppLocalizations.of(context)!;
    final lang = _lang(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.packs)),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.packLoadError),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(packCatalogProvider),
                child: Text(l10n.packRetry),
              ),
            ],
          ),
        ),
        data: (c) {
          PackSummary? pack;
          for (final p in c.packs) {
            if (p.id == packId) pack = p;
          }
          if (pack == null) return Center(child: Text(l10n.packLoadError));
          final p = pack;
          final locked = !p.isAccessible(c.activeEntitlements);
          final preview = ref.watch(packPreviewProvider(packId));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                p.localizedTitle(lang),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(p.isOfficial ? l10n.packOfficial : l10n.packMine),
              if (p.localizedDescription(lang).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(p.localizedDescription(lang)),
                ),
              if (p.isPremium) ...[
                const SizedBox(height: 8),
                Text(locked
                    ? '${l10n.packPremium} · ${l10n.packLocked}'
                    : l10n.packPremium),
                if (locked)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ElevatedButton(
                      onPressed: null,
                      child: Text(l10n.packComingSoon),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Text(l10n.packPreview,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              preview.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => Text(l10n.packLoadError),
                data: (rows) {
                  if (rows.isEmpty) return Text(l10n.packEmpty);
                  return Column(
                    children: [
                      for (final r in rows)
                        ListTile(
                          leading: Text('#${r.idx + 1}'),
                          title: Text(r.localizedPrompt(lang)),
                          subtitle:
                              Text('${r.category} · ${r.difficulty}/3'),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// Écrans catalogue Phase 3A : /packs (liste) + /packs/:id (détail).
// Anti-triche : aperçu via get_pack_preview uniquement, jamais de réponses.
// Textes via l10n ARB + locale courante pour le contenu pack FR/EN/AR.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/brain_card.dart';
import '../../shared/widgets/brain_scaffold.dart';
import '../../shared/widgets/entrance.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/state_views.dart';
import '../shop/billing_controller.dart';
import '../shop/billing_errors.dart';
import 'pack.dart';
import 'pack_providers.dart';
import 'report_pack_dialog.dart';
import 'ugc_draft.dart';

String _lang(BuildContext context) =>
    Localizations.localeOf(context).languageCode;

class PacksScreen extends ConsumerWidget {
  const PacksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(packCatalogProvider);
    final l10n = AppLocalizations.of(context)!;
    return BrainScaffold(
      appBar: AppBar(
        title: Text(l10n.packs),
        // Menu compact : tient à 320px même en 1.3x (deux TextButtons
        // débordaient). Mêmes routes, mêmes libellés.
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'create') {
                context.push('/packs/edit');
              } else {
                context.push('/packs/import');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'create', child: Text(l10n.packCreate)),
              PopupMenuItem(value: 'import', child: Text(l10n.packImport)),
            ],
          ),
        ],
      ),
      body: catalog.when(
        loading: () => const BrainLoading(),
        error: (_, _) => BrainError(
          message: l10n.packLoadError,
          onRetry: () => ref.invalidate(packCatalogProvider),
          retryLabel: l10n.packRetry,
        ),
        data: (c) {
          if (c.packs.isEmpty) return BrainEmpty(message: l10n.packEmpty);
          final lang = _lang(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var i = 0; i < c.packs.length; i++) ...[
                BrainEntrance(
                  delayMs: (i * 60).clamp(0, 300),
                  child: _PackCatalogCard(
                    pack: c.packs[i],
                    lang: lang,
                    locked: !c.packs[i].isAccessible(c.activeEntitlements),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PackCatalogCard extends StatelessWidget {
  final PackSummary pack;
  final String lang;
  final bool locked;
  const _PackCatalogCard({
    required this.pack,
    required this.lang,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Premium verrouillé = désirable : bordure or + titre fort.
    // UGC possédé : badge turquoise via _PackBadges (inchangé).
    return BrainCard(
      featured: pack.isPremium && locked,
      onTap: () => context.push('/packs/${pack.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pack.localizedTitle(lang),
                  style: pack.isPremium && locked
                      ? textTheme.titleLarge?.copyWith(
                          color: BrainColors.goldDeep,
                        )
                      : textTheme.titleMedium,
                ),
              ),
              if (locked)
                const Padding(
                  padding: EdgeInsetsDirectional.only(start: 8),
                  child: Icon(Icons.lock_outline, size: 20),
                ),
            ],
          ),
          if (pack.localizedDescription(lang).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                pack.localizedDescription(lang),
                style: textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 8),
          _PackBadges(pack: pack, locked: locked),
        ],
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
    return BrainBadgeRow(
      badges: [
        BrainBadge(
          label: pack.isOfficial ? l10n.packOfficial : l10n.packMine,
          kind: pack.isOfficial ? BrainBadgeKind.official : BrainBadgeKind.mine,
        ),
        if (pack.isPremium)
          BrainBadge(label: l10n.packPremium, kind: BrainBadgeKind.premium),
        if (locked)
          BrainBadge(label: l10n.packLocked, kind: BrainBadgeKind.locked),
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
    return BrainScaffold(
      appBar: AppBar(title: Text(l10n.packs)),
      body: catalog.when(
        loading: () => const BrainLoading(),
        error: (_, _) => BrainError(
          message: l10n.packLoadError,
          onRetry: () => ref.invalidate(packCatalogProvider),
          retryLabel: l10n.packRetry,
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
          final editable = canEditPack(
            isOfficial: p.isOfficial,
            isOwned: p.isOwned,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BrainHeroPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.localizedTitle(lang),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    BrainBadgeRow(
                      badges: [
                        BrainBadge(
                          label: p.isOfficial
                              ? l10n.packOfficial
                              : l10n.packMine,
                          kind: p.isOfficial
                              ? BrainBadgeKind.official
                              : BrainBadgeKind.mine,
                        ),
                        if (p.isPremium)
                          BrainBadge(
                            label: locked
                                ? '${l10n.packPremium} · ${l10n.packLocked}'
                                : l10n.packPremium,
                            kind: locked
                                ? BrainBadgeKind.locked
                                : BrainBadgeKind.premium,
                          ),
                      ],
                    ),
                    if (p.localizedDescription(lang).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(p.localizedDescription(lang)),
                      ),
                    if (p.isPremium && locked) _PackBuyButton(pack: p),
                  ],
                ),
              ),
              if (editable) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.push('/packs/edit/${p.id}'),
                  child: Text(l10n.packEdit),
                ),
              ],
              // Signalement : jamais pour son propre pack (serveur :
              // cannot-report-own-pack). Officiels signalables.
              if (!editable) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => showReportPackDialog(context, p.id),
                  child: Text(l10n.packReport),
                ),
              ],
              const SizedBox(height: 16),
              SectionHeader(title: l10n.packPreview),
              preview.when(
                loading: () => const BrainLoading(),
                error: (_, _) => Text(l10n.packLoadError),
                data: (rows) {
                  if (rows.isEmpty) return Text(l10n.packEmpty);
                  return BrainCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          ListTile(
                            leading: Text('#${rows[i].idx + 1}'),
                            title: Text(rows[i].localizedPrompt(lang)),
                            subtitle: Text(
                              '${rows[i].category} · ${rows[i].difficulty}/3',
                            ),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          if (i != rows.length - 1) const Divider(height: 1),
                        ],
                      ],
                    ),
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

/// CTA achat pack premium verrouillé (Phase 3E).
/// Prix réel Play uniquement, jamais de prix inventé. L'écran se déverrouille
/// via packCatalogProvider après vérification serveur + refresh entitlements.
class _PackBuyButton extends ConsumerStatefulWidget {
  final PackSummary pack;
  const _PackBuyButton({required this.pack});

  @override
  ConsumerState<_PackBuyButton> createState() => _PackBuyButtonState();
}

class _PackBuyButtonState extends ConsumerState<_PackBuyButton> {
  bool _initRequested = false;

  void _ensure(String sku) {
    if (_initRequested) return;
    _initRequested = true;
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(billingControllerProvider.notifier)
          .ensureInitialized(productIds: {sku});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final sku = widget.pack.priceSku;
    if (sku == null || sku.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ElevatedButton(
          onPressed: null,
          child: Text(l10n.shopNoProducts),
        ),
      );
    }
    _ensure(sku);
    final billing = ref.watch(billingControllerProvider);
    final product = billing.productsById[sku];
    final err = billing.lastErrorCode;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: billing.canBuy(sku)
                ? () => ref.read(billingControllerProvider.notifier).buySku(sku)
                : null,
            child: Text(
              product == null
                  ? l10n.shopBuy
                  : l10n.shopBuyWithPrice(product.price),
            ),
          ),
          if (product == null && billing.initialized && billing.backendReady)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.shopNoProducts),
            ),
          if (!billing.backendReady && billing.initialized)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.shopBackendUnavailable),
            ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(friendlyBillingError(err, lang)),
            ),
        ],
      ),
    );
  }
}

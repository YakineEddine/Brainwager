// Boutique Phase 3E : packs premium officiels + remove_ads.
// Prix Play réels uniquement (ProductDetails.price). Autorité serveur :
// l'accessibilité est recalculée depuis les entitlements serveur.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/brain_card.dart';
import '../../shared/widgets/brain_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/state_views.dart';
import '../packs/pack.dart';
import '../packs/pack_providers.dart';
import 'billing_controller.dart';
import 'billing_errors.dart';
import 'billing_models.dart';

String _lang(BuildContext context) =>
    Localizations.localeOf(context).languageCode;

/// Section visuelle boutique (préparée pour les futurs groupes :
/// BrainCoins, Avatars, Packs, offres, Remove Ads). Aujourd'hui seuls
/// les groupes réellement configurés sont rendus — jamais de faux
/// contenu.
class ShopSection extends StatelessWidget {
  final String title;
  final Widget child;
  const ShopSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        child,
      ],
    );
  }
}

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  /// IDs déjà demandés au billing (union croissante). L'init démarre une
  /// fois, puis un SEUL suivi si l'union grandit pendant un vol :
  /// jamais de relance à chaque rebuild (Refresh manuel = retry explicite).
  final Set<String> _requestedIds = {};
  bool _initStarted = false;
  bool _initInFlight = false;
  bool _followUpPending = false;

  void _ensureBilling(Set<String> ids) {
    final before = _requestedIds.length;
    _requestedIds.addAll(ids);
    if (_initInFlight) {
      // Croissance pendant le vol : un seul suivi avec l'union complète
      // après la fin du vol en cours (pas de spin sur les rebuilds).
      if (_requestedIds.length > before) _followUpPending = true;
      return;
    }
    if (_initStarted && _requestedIds.length == before) return;
    _runInit();
  }

  void _runInit() {
    _initStarted = true;
    _initInFlight = true;
    final wanted = Set<String>.of(_requestedIds);
    Future.microtask(() async {
      try {
        if (!mounted) return;
        await ref
            .read(billingControllerProvider.notifier)
            .ensureInitialized(productIds: wanted);
      } finally {
        // Toujours refermé, même si ensureInitialized levait.
        // (Les rebuilds UI viennent de l'état du contrôleur lui-même.)
        _initInFlight = false;
        final followUp = _followUpPending;
        _followUpPending = false;
        // Un seul suivi si l'union a grandi pendant le vol.
        if (followUp && mounted) _runInit();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = _lang(context);
    final catalog = ref.watch(packCatalogProvider);
    final billing = ref.watch(billingControllerProvider);
    final controller = ref.read(billingControllerProvider.notifier);

    return BrainScaffold(
      appBar: AppBar(title: Text(l10n.shop)),
      body: catalog.when(
        loading: () => const BrainLoading(),
        error: (_, _) => BrainError(
          message: l10n.packLoadError,
          onRetry: () => ref.invalidate(packCatalogProvider),
          retryLabel: l10n.packRetry,
        ),
        data: (c) {
          final ids = billingProductIds(c.packs);
          // Init billing en arrière-plan : la page reste stable et visible
          // immédiatement, même avant la fin de l'initialisation.
          _ensureBilling(ids);
          return _ShopBody(
            packs: c.packs,
            // Set vide autoritaire : une fois chargé, il fait foi même
            // s'il est vide (refund). Jamais de repli stale via isEmpty.
            activeEntitlements: billing.entitlementsLoaded
                ? billing.activeEntitlements
                : c.activeEntitlements,
            productIds: ids,
            onBuy: controller.buySku,
            onRestore: controller.restore,
            onRefresh: controller.refresh,
            lang: lang,
          );
        },
      ),
    );
  }
}

class _ShopBody extends ConsumerWidget {
  final List<PackSummary> packs;
  final Set<String> activeEntitlements;
  final Set<String> productIds;
  final Future<void> Function(String sku) onBuy;
  final Future<void> Function() onRestore;
  final Future<void> Function() onRefresh;
  final String lang;

  const _ShopBody({
    required this.packs,
    required this.activeEntitlements,
    required this.productIds,
    required this.onBuy,
    required this.onRestore,
    required this.onRefresh,
    required this.lang,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final billing = ref.watch(billingControllerProvider);

    final premiumPacks = packs
        .where(
          (p) =>
              p.isOfficial &&
              p.isPremium &&
              (p.priceSku?.trim().isNotEmpty ?? false),
        )
        .toList();

    Widget statusBanner() {
      // Initialisation en cours : la page est déjà visible, seule cette
      // section patiente (jamais de spinner plein écran pour le billing).
      if (!billing.initialized) {
        return const BrainCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        );
      }
      if (!billing.supported) {
        return ListTile(title: Text(l10n.shopUnsupported));
      }
      if (!billing.storeAvailable) {
        return ListTile(title: Text(l10n.shopPlayUnavailable));
      }
      if (!billing.backendReady) {
        final code = billing.backendErrorCode;
        return ListTile(
          title: Text(l10n.shopBackendUnavailable),
          subtitle: code == null
              ? null
              : Text(friendlyBillingError(code, lang)),
        );
      }
      if (billing.productsById.isEmpty) {
        return ListTile(title: Text(l10n.shopNoProducts));
      }
      return const SizedBox.shrink();
    }

    Widget feedbackRow() {
      final children = <Widget>[];
      if (billing.syncing) {
        children.add(
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (billing.pendingSku != null) {
        children.add(
          Chip(label: Text('${l10n.shopPending} · ${billing.pendingSku}')),
        );
      }
      if (billing.purchasingSku != null) {
        children.add(Chip(label: Text(l10n.shopPurchasing)));
      }
      if (billing.lastSuccessSku != null) {
        children.add(Chip(label: Text(l10n.shopSuccess)));
      }
      if (billing.lastCanceled) {
        children.add(Chip(label: Text(l10n.shopCanceled)));
      }
      final err = billing.lastErrorCode;
      if (err != null) {
        children.add(Chip(label: Text(friendlyBillingError(err, lang))));
      }
      if (children.isEmpty) return const SizedBox.shrink();
      return Wrap(spacing: 8, children: children);
    }

    Widget buyButton(String sku) {
      final owned = activeEntitlements.contains(sku);
      if (owned) return Text(l10n.shopOwned);
      final product = billing.productsById[sku];
      final enabled = billing.canBuy(sku);
      final label = product == null
          ? l10n.shopBuy
          : l10n.shopBuyWithPrice(product.price);
      return ElevatedButton(
        onPressed: enabled ? () => onBuy(sku) : null,
        child: Text(label),
      );
    }

    Widget productRow({
      required String title,
      required String sku,
      VoidCallback? onTap,
    }) {
      final owned = activeEntitlements.contains(sku);
      final price = billing.productsById[sku]?.price;
      final textTheme = Theme.of(context).textTheme;
      return BrainCard(
        onTap: onTap,
        featured: !owned && price != null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (owned)
                    BrainBadge(
                      label: l10n.shopOwned,
                      kind: BrainBadgeKind.owned,
                    )
                  else if (price != null)
                    Text(
                      price,
                      style: textTheme.titleLarge?.copyWith(
                        color: BrainColors.goldDeep,
                      ),
                    )
                  else
                    Text(l10n.shopNoProducts, style: textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 12),
            buyButton(sku),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        statusBanner(),
        feedbackRow(),
        if (!billing.initialized)
          // Produits pas encore connus : section en attente, page stable.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: BrainLoading(),
          )
        else ...[
          if (premiumPacks.isNotEmpty)
            ShopSection(
              title: l10n.packs,
              child: Column(
                children: [
                  for (final p in premiumPacks) ...[
                    productRow(
                      title: p.localizedTitle(lang),
                      sku: p.priceSku!,
                      onTap: () => context.push('/packs/${p.id}'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          productRow(title: l10n.shopRemoveAds, sku: removeAdsSku),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                // Restore exige la readiness backend (vérification
                // indisponible => visiblement désactivé).
                onPressed:
                    billing.initialized &&
                        billing.supported &&
                        billing.storeAvailable &&
                        billing.backendReady &&
                        !billing.syncing
                    ? () => onRestore()
                    : null,
                child: Text(l10n.shopRestorePurchases),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                // Refresh reste utilisable pour retenter la readiness.
                onPressed: billing.supported && !billing.syncing
                    ? () => onRefresh()
                    : null,
                child: Text(l10n.shopRefreshPurchases),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

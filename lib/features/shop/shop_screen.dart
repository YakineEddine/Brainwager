// Boutique Phase 3E : packs premium officiels + remove_ads.
// Prix Play réels uniquement (ProductDetails.price). Autorité serveur :
// l'accessibilité est recalculée depuis les entitlements serveur.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../packs/pack.dart';
import '../packs/pack_providers.dart';
import 'billing_controller.dart';
import 'billing_errors.dart';
import 'billing_models.dart';

String _lang(BuildContext context) =>
    Localizations.localeOf(context).languageCode;

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  Set<String>? _lastInitIds;

  void _ensureBilling(Set<String> ids) {
    if (_lastInitIds != null &&
        _lastInitIds!.length == ids.length &&
        _lastInitIds!.containsAll(ids)) {
      return;
    }
    _lastInitIds = ids;
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(billingControllerProvider.notifier)
          .ensureInitialized(productIds: ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = _lang(context);
    final catalog = ref.watch(packCatalogProvider);
    final billing = ref.watch(billingControllerProvider);
    final controller = ref.read(billingControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.shop)),
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
          final ids = billingProductIds(c.packs);
          // Best-effort sync/readiness avant tout achat.
          if (!billing.initialized) {
            _ensureBilling(ids);
            return const Center(child: CircularProgressIndicator());
          }
          if (_lastInitIds == null ||
              _lastInitIds!.length != ids.length ||
              !_lastInitIds!.containsAll(ids)) {
            _ensureBilling(ids);
          }
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        statusBanner(),
        feedbackRow(),
        for (final p in premiumPacks)
          Card(
            child: ListTile(
              title: Text(p.localizedTitle(lang)),
              subtitle: Text(
                activeEntitlements.contains(p.priceSku)
                    ? l10n.shopOwned
                    : (billing.productsById[p.priceSku]?.price ??
                          l10n.shopNoProducts),
              ),
              trailing: buyButton(p.priceSku!),
              onTap: () => context.push('/packs/${p.id}'),
            ),
          ),
        Card(
          child: ListTile(
            title: Text(l10n.shopRemoveAds),
            subtitle: Text(
              activeEntitlements.contains(removeAdsSku)
                  ? l10n.shopOwned
                  : (billing.productsById[removeAdsSku]?.price ??
                        l10n.shopNoProducts),
            ),
            trailing: buyButton(removeAdsSku),
          ),
        ),
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

// Billing controller Phase 3E : orchestration Play + verify-purchase.
// Autorité = serveur. PurchaseStatus seul ne débloque jamais rien.
// Riverpod sans code-gen. Gateway/backend injectés (fakes en tests).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/network/supabase_client.dart';
import '../packs/pack_providers.dart';
import '../packs/pack_repository.dart';
import 'billing_backend.dart';
import 'billing_errors.dart';
import 'billing_gateway.dart';
import 'billing_models.dart';

/// Fournisseurs injectables (override en tests par des fakes).
final billingGatewayProvider = Provider<BillingGateway>(
  (ref) => GooglePlayBillingGateway(),
);

final billingBackendProvider = Provider<BillingBackend>(
  (ref) => SupabaseBillingBackend(),
);

/// Chargeur entitlements (lecture seule). Prod = Supabase, tests = fake.
final billingEntitlementsLoaderProvider =
    Provider<Future<Set<String>> Function()>((ref) {
      return () {
        try {
          return PackRepository().activeEntitlements();
        } catch (_) {
          return Future.value(<String>{});
        }
      };
    });

/// User id courant (anon Supabase). Prod = session, tests = override.
final billingCurrentUserIdProvider = Provider<String? Function()>((ref) {
  return () {
    try {
      return supa().auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  };
});

/// État UI billing (immuable).
class BillingUiState {
  final bool initialized;
  final bool supported;
  final bool storeAvailable;
  final bool backendReady;
  final String? backendErrorCode;
  final Map<String, ProductDetails> productsById;
  final Set<String> notFoundIds;
  final Set<String> activeEntitlements;
  final bool syncing;
  final String? purchasingSku;
  final String? pendingSku;
  final String? lastSuccessSku;
  final String? lastErrorCode;
  final bool lastCanceled;

  const BillingUiState({
    this.initialized = false,
    this.supported = false,
    this.storeAvailable = false,
    this.backendReady = false,
    this.backendErrorCode,
    this.productsById = const {},
    this.notFoundIds = const {},
    this.activeEntitlements = const {},
    this.syncing = false,
    this.purchasingSku,
    this.pendingSku,
    this.lastSuccessSku,
    this.lastErrorCode,
    this.lastCanceled = false,
  });

  /// Buy autorisé uniquement si tout est vert (readiness gate).
  bool canBuy(String sku) {
    if (!initialized || !supported) return false;
    if (!storeAvailable || !backendReady) return false;
    if (purchasingSku != null) return false;
    if (!productsById.containsKey(sku)) return false;
    if (activeEntitlements.contains(sku)) return false;
    return true;
  }

  BillingUiState copyWith({
    bool? initialized,
    bool? supported,
    bool? storeAvailable,
    bool? backendReady,
    String? Function()? backendErrorCode,
    Map<String, ProductDetails>? productsById,
    Set<String>? notFoundIds,
    Set<String>? activeEntitlements,
    bool? syncing,
    String? Function()? purchasingSku,
    String? Function()? pendingSku,
    String? Function()? lastSuccessSku,
    String? Function()? lastErrorCode,
    bool? lastCanceled,
  }) {
    return BillingUiState(
      initialized: initialized ?? this.initialized,
      supported: supported ?? this.supported,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      backendReady: backendReady ?? this.backendReady,
      backendErrorCode: backendErrorCode == null
          ? this.backendErrorCode
          : backendErrorCode(),
      productsById: productsById ?? this.productsById,
      notFoundIds: notFoundIds ?? this.notFoundIds,
      activeEntitlements: activeEntitlements ?? this.activeEntitlements,
      syncing: syncing ?? this.syncing,
      purchasingSku: purchasingSku == null
          ? this.purchasingSku
          : purchasingSku(),
      pendingSku: pendingSku == null ? this.pendingSku : pendingSku(),
      lastSuccessSku: lastSuccessSku == null
          ? this.lastSuccessSku
          : lastSuccessSku(),
      lastErrorCode: lastErrorCode == null
          ? this.lastErrorCode
          : lastErrorCode(),
      lastCanceled: lastCanceled ?? this.lastCanceled,
    );
  }
}

class BillingController extends Notifier<BillingUiState> {
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _subscribed = false;

  /// Tokens en cours de vérification (mémoire seule, anti-doublons).
  final Set<String> verifyingTokens = <String>{};

  @override
  BillingUiState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
      _subscribed = false;
    });
    return const BillingUiState();
  }

  BillingGateway get _gateway => ref.read(billingGatewayProvider);
  BillingBackend get _backend => ref.read(billingBackendProvider);

  /// Init unique : abonnement stream, dispo store, produits, sync readiness.
  /// Un 2e appel ne duplique jamais l'abonnement.
  Future<void> ensureInitialized({required Set<String> productIds}) async {
    if (_subscribed) {
      // Rafraîchir les produits si la liste change, sans réabonner.
      await _loadProducts(productIds);
      return;
    }
    _subscribed = true;
    final supported = isBillingSupportedNow;
    if (!supported) {
      state = state.copyWith(
        initialized: true,
        supported: false,
        storeAvailable: false,
        backendReady: false,
        backendErrorCode: () => 'billing-unsupported-platform',
      );
      return;
    }
    state = state.copyWith(supported: true);
    _sub = _gateway.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        state = state.copyWith(lastErrorCode: () => billingErrorCode(e));
      },
    );
    final available = await _gateway.isAvailable();
    state = state.copyWith(storeAvailable: available);
    await _loadProducts(productIds);
    await refreshReadiness();
    state = state.copyWith(initialized: true);
  }

  Future<void> _loadProducts(Set<String> ids) async {
    if (!state.supported) return;
    if (ids.isEmpty) {
      state = state.copyWith(productsById: {}, notFoundIds: {});
      return;
    }
    try {
      final res = await _gateway.queryProducts(ids);
      state = state.copyWith(
        productsById: {for (final p in res.productDetails) p.id: p},
        notFoundIds: res.notFoundIDs.toSet(),
      );
    } catch (e) {
      state = state.copyWith(lastErrorCode: () => billingErrorCode(e));
    }
  }

  /// Readiness gate : sync serveur obligatoire avant tout Buy.
  /// Échec fatal => Buy désactivé, UI "temporairement indisponible".
  Future<void> refreshReadiness() async {
    if (!state.supported || !state.storeAvailable) {
      state = state.copyWith(backendReady: false);
      return;
    }
    state = state.copyWith(syncing: true);
    try {
      final res = await _backend.syncPurchases();
      if (res.ok) {
        state = state.copyWith(
          backendReady: true,
          backendErrorCode: () => null,
        );
        await reloadEntitlements();
      } else {
        final code = res.errorCode ?? 'billing-network-error';
        state = state.copyWith(
          backendReady: false,
          backendErrorCode: () => code,
        );
      }
    } catch (e) {
      state = state.copyWith(
        backendReady: false,
        backendErrorCode: () => billingErrorCode(e),
      );
    } finally {
      state = state.copyWith(syncing: false);
    }
  }

  /// Recharge les entitlements serveur (source de vérité).
  Future<void> reloadEntitlements() async {
    try {
      final loader = ref.read(billingEntitlementsLoaderProvider);
      final entitlements = await loader();
      state = state.copyWith(activeEntitlements: entitlements);
    } catch (_) {
      // Ne jamais révoquer localement sur échec transport.
    }
  }

  /// Achat : hash SHA-256 obligatoire, jamais buyConsumable/offerToken.
  Future<void> buySku(String sku) async {
    state = state.copyWith(
      lastErrorCode: () => null,
      lastSuccessSku: () => null,
      lastCanceled: false,
    );
    if (!state.supported) {
      state = state.copyWith(
        lastErrorCode: () => 'billing-unsupported-platform',
      );
      return;
    }
    if (!state.backendReady) {
      state = state.copyWith(
        lastErrorCode: () => state.backendErrorCode ?? 'billing-not-configured',
      );
      return;
    }
    final product = state.productsById[sku];
    if (product == null) {
      state = state.copyWith(
        lastErrorCode: () => 'billing-product-unavailable',
      );
      return;
    }
    String? userId;
    try {
      userId = ref.read(billingCurrentUserIdProvider)();
    } catch (_) {
      userId = null;
    }
    if (userId == null || userId.isEmpty) {
      state = state.copyWith(lastErrorCode: () => 'not-authenticated');
      return;
    }
    state = state.copyWith(purchasingSku: () => sku);
    try {
      final ok = await _gateway.buyNonConsumable(
        product,
        billingAccountHash(userId),
      );
      if (!ok) {
        state = state.copyWith(
          lastErrorCode: () => 'billing-store-unavailable',
          purchasingSku: () => null,
        );
      }
      // Le résultat arrive via purchaseStream (verify serveur).
    } catch (e) {
      state = state.copyWith(
        lastErrorCode: () => billingErrorCode(e),
        purchasingSku: () => null,
      );
    }
  }

  /// Restauration : hash courant, events restored => mode=restore serveur.
  /// Ne requiert jamais l'ancien UUID anon (transfert backend).
  Future<void> restore() async {
    state = state.copyWith(
      lastErrorCode: () => null,
      lastSuccessSku: () => null,
      lastCanceled: false,
    );
    if (!state.supported || !state.storeAvailable || !state.backendReady) {
      state = state.copyWith(
        lastErrorCode: () =>
            state.backendErrorCode ?? 'billing-store-unavailable',
      );
      return;
    }
    String? userId;
    try {
      userId = ref.read(billingCurrentUserIdProvider)();
    } catch (_) {
      userId = null;
    }
    if (userId == null || userId.isEmpty) {
      state = state.copyWith(lastErrorCode: () => 'not-authenticated');
      return;
    }
    try {
      await _gateway.restorePurchases(billingAccountHash(userId));
    } catch (e) {
      state = state.copyWith(lastErrorCode: () => billingErrorCode(e));
    }
  }

  /// Refresh manuel : sync + entitlements (jamais de révocation locale
  /// sur échec transport).
  Future<void> refresh() async {
    await refreshReadiness();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      await _handleOne(p);
    }
  }

  Future<void> _handleOne(PurchaseDetails p) async {
    // A. productID vide : ignorer défensivement.
    if (p.productID.isEmpty) return;
    final token = billingPurchaseToken(p);
    // B. token vide : pas de verify, erreur localisée.
    if (token.isEmpty) {
      state = state.copyWith(
        lastErrorCode: () => 'billing-invalid-purchase-data',
        purchasingSku: () => null,
      );
      return;
    }
    switch (p.status) {
      case PurchaseStatus.canceled:
        // F. annulé : pas de verify, état non-erreur.
        state = state.copyWith(
          lastCanceled: true,
          purchasingSku: () => null,
          pendingSku: () => null,
        );
        return;
      case PurchaseStatus.error:
        // G. erreur : friendly, jamais de déblocage.
        state = state.copyWith(
          lastErrorCode: () =>
              billingErrorCode(p.error ?? Exception('billing-network-error')),
          purchasingSku: () => null,
          pendingSku: () => null,
        );
        return;
      case PurchaseStatus.pending:
        // C. pending : verify serveur si valide, affichage Pending,
        // jamais de déblocage ni de completePurchase.
        state = state.copyWith(pendingSku: () => p.productID);
        await _verifyToken(
          p,
          token: token,
          mode: 'verify',
          allowComplete: false,
        );
        return;
      case PurchaseStatus.purchased:
        // D. purchased => mode=verify.
        await _verifyToken(
          p,
          token: token,
          mode: 'verify',
          allowComplete: true,
        );
        return;
      case PurchaseStatus.restored:
        // E. restored => mode=restore.
        await _verifyToken(
          p,
          token: token,
          mode: 'restore',
          allowComplete: true,
        );
        return;
    }
  }

  Future<void> _verifyToken(
    PurchaseDetails p, {
    required String token,
    required String mode,
    required bool allowComplete,
  }) async {
    // 16. Déduplication en vol (mémoire seule).
    if (verifyingTokens.contains(token)) return;
    verifyingTokens.add(token);
    try {
      late final BillingBackendResult res;
      if (mode == 'restore') {
        res = await _backend.restorePurchase(
          sku: p.productID,
          purchaseToken: token,
        );
      } else {
        res = await _backend.verifyPurchase(
          sku: p.productID,
          purchaseToken: token,
        );
      }
      if (res.isVerifiedActiveFor(p.productID)) {
        // 14. Succès serveur uniquement : refresh entitlements + catalogue.
        await reloadEntitlements();
        try {
          ref.invalidate(packCatalogProvider);
        } catch (_) {}
        state = state.copyWith(
          lastSuccessSku: () => p.productID,
          lastErrorCode: () => null,
          pendingSku: () => null,
          purchasingSku: () => null,
          lastCanceled: false,
        );
        // 15. Acknowledgement : serveur d'abord.
        if (allowComplete && res.acknowledged) {
          return; // Pas de completePurchase redondant.
        }
        if (allowComplete && !res.acknowledged && p.pendingCompletePurchase) {
          try {
            await _gateway.completePurchase(p);
            // Best-effort : le ledger suit après fallback.
            await _backend.syncPurchases();
          } catch (_) {}
        }
      } else {
        // Échec/pending/inactif : jamais de déblocage, jamais de complete.
        final code =
            res.errorCode ??
            (res.ok ? 'purchase-not-active' : 'billing-network-error');
        if (code == 'purchase-pending') {
          state = state.copyWith(
            pendingSku: () => p.productID,
            purchasingSku: () => null,
          );
        } else {
          state = state.copyWith(
            lastErrorCode: () => code,
            purchasingSku: () => null,
            pendingSku: () => null,
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        lastErrorCode: () => billingErrorCode(e),
        purchasingSku: () => null,
      );
    } finally {
      verifyingTokens.remove(token);
    }
  }
}

final billingControllerProvider =
    NotifierProvider<BillingController, BillingUiState>(BillingController.new);

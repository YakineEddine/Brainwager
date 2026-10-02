// Billing client Phase 3E : modèles purs (aucun SDK, aucun Supabase).
// L'autorité reste verify-purchase côté serveur ; Flutter ne débloque
// jamais un pack depuis PurchaseStatus seul.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../packs/pack.dart';

/// SKU constant : suppression des pubs (entitlement achetable/restaurable
/// dès ce ticket ; le câblage AdMob reste un ticket ultérieur).
const removeAdsSku = 'remove_ads';

/// Hash compte Play : SHA-256 hex minuscule de l'UUID Supabase exact.
/// 64 caractères. Jamais l'UUID brut dans applicationUserName.
String billingAccountHash(String userId) {
  final digest = sha256.convert(utf8.encode(userId));
  return digest.toString();
}

/// IDs acheteables : packs officiels premium avec priceSku non vide,
/// PLUS remove_ads. Dédupliqué. Aucun SKU UGC.
Set<String> billingProductIds(List<PackSummary> packs) {
  final ids = <String>{};
  for (final p in packs) {
    if (!p.isOfficial) continue;
    if (!p.isPremium) continue;
    final sku = p.priceSku;
    if (sku == null || sku.trim().isEmpty) continue;
    ids.add(sku);
  }
  ids.add(removeAdsSku);
  return ids;
}

/// Jeton serveur Google Play : serverVerificationData uniquement.
/// Jamais orderId, jamais loggé/exposé.
String billingPurchaseToken(PurchaseDetails purchase) {
  return purchase.verificationData.serverVerificationData;
}

/// Constructeur pur du param Android (testable sans mock plugin).
GooglePlayPurchaseParam buildGooglePlayParam(
  ProductDetails product,
  String obfuscatedAccountId,
) {
  return GooglePlayPurchaseParam(
    productDetails: product,
    applicationUserName: obfuscatedAccountId,
  );
}

/// Garde plateforme pure/testable : Play billing uniquement sur Android
/// hors web.
bool isBillingSupportedPlatform({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  return !isWeb && platform == TargetPlatform.android;
}

/// Garde réelle (kIsWeb + defaultTargetPlatform, sans dart:io).
bool get isBillingSupportedNow =>
    isBillingSupportedPlatform(isWeb: kIsWeb, platform: defaultTargetPlatform);

/// Erreurs backend/config fatales : le bouton Buy doit rester désactivé
/// (ne jamais laisser payer si on ne peut pas vérifier/acknowledger).
/// Inclut aussi les erreurs internes/réseau de vérification : après un
/// échec infra, la readiness se referme jusqu'au prochain sync réussi.
const backendFatalBillingCodes = <String>{
  'billing-not-configured',
  'billing-backend-not-configured',
  'google-auth-failed',
  'google-play-permission-denied',
  'google-verify-failed',
  'billing-database-error',
  'billing-internal-error',
  'billing-network-error',
};

bool isBackendFatalBillingCode(String code) =>
    backendFatalBillingCodes.contains(code);

/// Résultat backend défensif (verify/restore/sync). Champs inconnus ignorés.
/// Un succès exige ok==true ET active==true (jamais de défaut optimiste).
class BillingBackendResult {
  final bool ok;
  final String? sku;
  final bool active;
  final bool acknowledged;
  final bool transferred;
  final String? mode;
  final int checked;
  final int failures;
  final List<String> activeSkus;
  final String? errorCode;

  const BillingBackendResult({
    required this.ok,
    required this.active,
    this.sku,
    this.acknowledged = false,
    this.transferred = false,
    this.mode,
    this.checked = 0,
    this.failures = 0,
    this.activeSkus = const [],
    this.errorCode,
  });

  /// Vrai uniquement si le serveur confirme actif pour ce SKU.
  bool isVerifiedActiveFor(String productId) {
    if (!ok || !active) return false;
    final s = sku;
    if (s == null || s.isEmpty) return false;
    return s == productId;
  }

  factory BillingBackendResult.fromJson(Map<String, dynamic> json) {
    final ok = json['ok'] as bool? ?? false;
    final active = json['active'] as bool? ?? false;
    final sku = json['sku'] as String?;
    final acknowledged = json['acknowledged'] as bool? ?? false;
    final transferred = json['transferred'] as bool? ?? false;
    final mode = json['mode'] as String?;
    int checked = 0;
    final checkedRaw = json['checked'];
    if (checkedRaw is int) checked = checkedRaw;
    int failures = 0;
    final failuresRaw = json['failures'];
    if (failuresRaw is int) failures = failuresRaw;
    final activeSkusRaw = json['activeSkus'];
    final activeSkus = activeSkusRaw is List
        ? activeSkusRaw.whereType<String>().toList()
        : <String>[];
    final errorCode = json['error'] as String?;
    return BillingBackendResult(
      ok: ok,
      active: active,
      sku: sku,
      acknowledged: acknowledged,
      transferred: transferred,
      mode: mode,
      checked: checked,
      failures: failures,
      activeSkus: activeSkus,
      errorCode: errorCode,
    );
  }

  factory BillingBackendResult.failure(String code) {
    return BillingBackendResult(ok: false, active: false, errorCode: code);
  }
}

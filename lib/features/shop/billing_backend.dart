// Billing backend Phase 3E : client Edge Function verify-purchase.
// Seule autorité app-facing. Interdit : apply_google_play_purchase direct,
// écritures entitlements / google_play_purchases, clés secrètes.
import '../../core/network/supabase_client.dart';
import 'billing_errors.dart';
import 'billing_models.dart';

/// Backend vérification (verify/restore/sync). Tests = fake en mémoire.
abstract interface class BillingBackend {
  Future<BillingBackendResult> verifyPurchase({
    required String sku,
    required String purchaseToken,
  });

  Future<BillingBackendResult> restorePurchase({
    required String sku,
    required String purchaseToken,
  });

  Future<BillingBackendResult> syncPurchases();
}

/// Production : supa().functions.invoke('verify-purchase', body: ...).
/// Les erreurs FunctionException deviennent des BillingBackendResult.failure
/// (jamais d'exception brute vers l'UI).
class SupabaseBillingBackend implements BillingBackend {
  final dynamic Function()? clientOverride;

  /// clientOverride réservé aux tests (fake client Supabase).
  SupabaseBillingBackend({this.clientOverride});

  dynamic get _client {
    final o = clientOverride;
    if (o != null) return o();
    return supa();
  }

  Future<BillingBackendResult> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('verify-purchase', body: body);
      final data = res.data;
      if (data is Map) {
        return BillingBackendResult.fromJson(Map<String, dynamic>.from(data));
      }
      return BillingBackendResult.failure('billing-network-error');
    } catch (e) {
      return BillingBackendResult.failure(billingErrorCode(e));
    }
  }

  @override
  Future<BillingBackendResult> verifyPurchase({
    required String sku,
    required String purchaseToken,
  }) {
    return _invoke({
      'mode': 'verify',
      'sku': sku,
      'purchaseToken': purchaseToken,
    });
  }

  @override
  Future<BillingBackendResult> restorePurchase({
    required String sku,
    required String purchaseToken,
  }) {
    return _invoke({
      'mode': 'restore',
      'sku': sku,
      'purchaseToken': purchaseToken,
    });
  }

  @override
  Future<BillingBackendResult> syncPurchases() {
    return _invoke({'mode': 'sync'});
  }
}

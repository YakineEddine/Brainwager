// Billing erreurs Phase 3E : extraction + messages FR/EN/AR.
// Pattern repo (game_errors.dart) : pur, testable, jamais de texte brut
// FunctionException/IAPError en UI. L'appelant transmet la langue UI.
const _knownBillingTokens = <String>{
  'billing-not-configured',
  'billing-backend-not-configured',
  'google-auth-failed',
  'google-play-permission-denied',
  'google-verify-failed',
  'billing-database-error',
  'purchase-account-mismatch',
  'purchase-token-already-claimed',
  'purchase-token-sku-mismatch',
  'billing-sku-not-allowed',
  'purchase-pending',
  'purchase-not-active',
  'invalid-purchase-token',
  'invalid-purchase-mode',
  'missing-sku-or-token',
  'not-authenticated',
  'billing-internal-error',
  'billing-network-error',
  'billing-store-unavailable',
  'billing-product-unavailable',
  'billing-invalid-purchase-data',
  'billing-unsupported-platform',
  'purchase-canceled',
  'purchase-sku-mismatch',
  'invalid-google-purchase-state',
  'unsupported-purchase-quantity',
};

/// Extrait un code erreur billing depuis n'importe quelle erreur.
/// Ordre : 1) details Map avec `error`, 2) details imbriqués,
/// 3) tokens discrets dans toString(), 4) billing-network-error.
String billingErrorCode(Object error) {
  try {
    final dynamic d = error;
    dynamic details;
    try {
      details = d.details;
    } catch (_) {
      details = null;
    }
    if (details != null) {
      final fromDetails = _codeFromDetails(details);
      if (fromDetails != null) return fromDetails;
    }
  } catch (_) {
    // Fall through to toString inspection.
  }
  final text = error.toString();
  for (final token in _knownBillingTokens) {
    if (text.contains(token)) return token;
  }
  return 'billing-network-error';
}

String? _codeFromDetails(dynamic details) {
  if (details is Map) {
    final direct = details['error'];
    if (direct is String && direct.isNotEmpty) return direct;
    for (final value in details.values) {
      if (value is Map) {
        final nested = _codeFromDetails(value);
        if (nested != null) return nested;
      } else if (value is String) {
        for (final token in _knownBillingTokens) {
          if (value.contains(token)) return token;
        }
      }
    }
  } else if (details is String) {
    for (final token in _knownBillingTokens) {
      if (details.contains(token)) return token;
    }
  }
  return null;
}

/// Message convivial FR/EN/AR pour un code billing (ou une erreur brute).
String friendlyBillingError(Object error, [String languageCode = 'fr']) {
  final text = '$error';
  String? found;
  for (final token in _knownBillingTokens) {
    if (text.contains(token)) {
      found = token;
      break;
    }
  }
  // Si l'appelant passe déjà un code exact, le garder tel quel.
  if (found == null && _knownBillingTokens.contains(text.trim())) {
    found = text.trim();
  }
  return _localizedBillingError(found, languageCode);
}

String _localizedBillingError(String? code, String languageCode) {
  final en = languageCode == 'en';
  final ar = languageCode == 'ar';
  String t(String f, String e, String a) => en
      ? e
      : ar
      ? a
      : f;
  switch (code) {
    case 'billing-not-configured':
    case 'billing-backend-not-configured':
      return t(
        'Achats temporairement indisponibles (backend non configuré).',
        'Purchases temporarily unavailable (backend not configured).',
        'المشتريات غير متاحة مؤقتًا (الخادم غير مهيأ).',
      );
    case 'google-auth-failed':
      return t(
        'Achats temporairement indisponibles (auth Google).',
        'Purchases temporarily unavailable (Google auth).',
        'المشتريات غير متاحة مؤقتًا (تعذر مصادقة Google).',
      );
    case 'google-play-permission-denied':
      return t(
        'Achats temporairement indisponibles (permission Play).',
        'Purchases temporarily unavailable (Play permission).',
        'المشتريات غير متاحة مؤقتًا (صلاحيات Play).',
      );
    case 'google-verify-failed':
      return t(
        'Vérification Play impossible pour l’instant.',
        'Play verification unavailable right now.',
        'تعذر التحقق من Play حاليًا.',
      );
    case 'billing-database-error':
      return t(
        'Erreur serveur : réessaie plus tard.',
        'Server error: try again later.',
        'خطأ في الخادم: حاول لاحقًا.',
      );
    case 'purchase-account-mismatch':
      return t(
        'Cet achat appartient à un autre compte.',
        'This purchase belongs to another account.',
        'هذا الشراء يخص حسابًا آخر.',
      );
    case 'purchase-token-already-claimed':
      return t(
        'Ce reçu est déjà lié à un autre profil.',
        'This receipt is already linked to another profile.',
        'هذا الإيصال مرتبط بملف آخر.',
      );
    case 'purchase-token-sku-mismatch':
    case 'purchase-sku-mismatch':
      return t(
        'Reçu invalide pour ce produit.',
        'Invalid receipt for this product.',
        'إيصال غير صالح لهذا المنتج.',
      );
    case 'billing-sku-not-allowed':
      return t(
        'Produit non disponible à la vente.',
        'Product not available for sale.',
        'المنتج غير متاح للبيع.',
      );
    case 'purchase-pending':
      return t(
        'Paiement en attente côté Play.',
        'Payment pending on Play.',
        'الدفع قيد الانتظار في Play.',
      );
    case 'purchase-not-active':
      return t(
        'Achat non actif (remboursé ou annulé).',
        'Purchase not active (refunded or cancelled).',
        'الشراء غير نشط (مسترد أو ملغى).',
      );
    case 'invalid-purchase-token':
      return t(
        'Reçu Play invalide.',
        'Invalid Play receipt.',
        'إيصال Play غير صالح.',
      );
    case 'missing-sku-or-token':
    case 'billing-invalid-purchase-data':
      return t(
        'Données d’achat invalides.',
        'Invalid purchase data.',
        'بيانات الشراء غير صالحة.',
      );
    case 'not-authenticated':
      return t(
        'Session perdue : reconnecte-toi.',
        'Session lost: please sign in again.',
        'فُقدت الجلسة: سجل الدخول مجددًا.',
      );
    case 'billing-store-unavailable':
      return t(
        'Boutique Play indisponible.',
        'Play Store unavailable.',
        'متجر Play غير متاح.',
      );
    case 'billing-product-unavailable':
      return t(
        'Produit non configuré côté Play.',
        'Product not configured on Play.',
        'المنتج غير مهيأ في Play.',
      );
    case 'billing-unsupported-platform':
      return t(
        'Achats disponibles uniquement sur Android.',
        'Purchases available on Android only.',
        'المشتريات متاحة على Android فقط.',
      );
    case 'purchase-canceled':
      return t('Achat annulé.', 'Purchase canceled.', 'تم إلغاء الشراء.');
    case 'billing-internal-error':
      return t(
        'Erreur interne : réessaie.',
        'Internal error: try again.',
        'خطأ داخلي: حاول مجددًا.',
      );
    default:
      return t(
        'Erreur réseau ou serveur. Réessaie.',
        'Network or server error. Try again.',
        'خطأ في الشبكة أو الخادم. حاول مجددًا.',
      );
  }
}

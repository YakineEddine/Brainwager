// Partage de pack Phase 3D (pur Dart) : modèle SharedPack distinct de
// PackSummary (le RPC get_pack_by_share_code ne renvoie pas owner_id),
// normalisation/validation du code PK-XXXX, parse défensif.
// Sémantique produit : AUCUNE bibliothèque importée. Résoudre un code =
// lire via RPC + créer une partie avec (p_share_code transmis au serveur).
// Jamais de copie, changement de propriétaire ou persistance locale.
import 'pack_preview.dart';

/// Normalise un code saisi/collé : rogné + majuscules. Ne génère rien.
String normalizePackShareCode(String raw) => raw.trim().toUpperCase();

/// Format exact accepté côté client (le serveur reste l'autorité).
bool isValidShareCode(String normalized) =>
    RegExp(r'^PK-[A-Z0-9]{4}$').hasMatch(normalized);

/// Code de jeu (rejoindre) : 4..6 caractères sans ambiguïté visible.
bool isValidGameCode(String normalized) =>
    RegExp(r'^[A-Z0-9]{4,6}$').hasMatch(normalized);

class SharedPack {
  final String id;
  final String titleFr;
  final String titleEn;
  final String titleAr;
  final String descFr;
  final String descEn;
  final String descAr;
  final bool isOfficial;
  final bool isPremium;
  final String? priceSku;
  final String shareCode;
  final bool isOwned;
  final int questionCount;
  final List<PackPreviewQuestion> questions;

  const SharedPack({
    required this.id,
    required this.titleFr,
    required this.titleEn,
    required this.titleAr,
    required this.descFr,
    required this.descEn,
    required this.descAr,
    required this.isOfficial,
    required this.isPremium,
    required this.priceSku,
    required this.shareCode,
    required this.isOwned,
    required this.questionCount,
    required this.questions,
  });

  /// Parse défensif du RPC : clés inconnues ignorées, jamais de
  /// answer_main_*/aliases_* lus ou attendus (anti-triche).
  factory SharedPack.fromRpc(Map<String, dynamic> doc) {
    final rawQuestions = doc['questions'];
    final questions = rawQuestions is List
        ? parsePackPreview(rawQuestions)
        : <PackPreviewQuestion>[];
    return SharedPack(
      id: (doc['id'] as String?) ?? '',
      titleFr: (doc['title_fr'] as String?) ?? '',
      titleEn: (doc['title_en'] as String?) ?? '',
      titleAr: (doc['title_ar'] as String?) ?? '',
      descFr: (doc['desc_fr'] as String?) ?? '',
      descEn: (doc['desc_en'] as String?) ?? '',
      descAr: (doc['desc_ar'] as String?) ?? '',
      isOfficial: (doc['is_official'] as bool?) ?? false,
      isPremium: (doc['is_premium'] as bool?) ?? false,
      priceSku: doc['price_sku'] as String?,
      shareCode: (doc['share_code'] as String?) ?? '',
      isOwned: (doc['is_owned'] as bool?) ?? false,
      questionCount: (doc['question_count'] as int?) ?? questions.length,
      questions: questions,
    );
  }

  String localizedTitle(String languageCode) {
    final localized = languageCode == 'en'
        ? titleEn
        : languageCode == 'ar'
            ? titleAr
            : titleFr;
    if (localized.trim().isNotEmpty) return localized;
    return titleFr;
  }

  String localizedDescription(String languageCode) {
    final localized = languageCode == 'en'
        ? descEn
        : languageCode == 'ar'
            ? descAr
            : descFr;
    if (localized.trim().isNotEmpty) return localized;
    return descFr;
  }

  bool isAccessible(Set<String> activeEntitlements) {
    if (!isPremium) return true;
    final sku = priceSku;
    if (sku == null || sku.isEmpty) return false;
    return activeEntitlements.contains(sku);
  }
}

/// URI de partage : le CODE vient toujours du serveur, le client ne fait
/// que formater l'URI autour (jamais de génération).
String shareLinkFor(String shareCode) => 'brainwager://pack/$shareCode';

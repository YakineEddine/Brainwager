// Modèle pack Phase 3A (pur Dart) : résumé catalogue + décision d'accès.
// Aucun objet Supabase/Map dans les widgets : le repository convertit
// les lignes via PackSummary.fromRow, les écrans ne voient que ce modèle.
class PackSummary {
  final String id;
  final String titleFr;
  final String titleEn;
  final String descFr;
  final String descEn;
  final bool isOfficial;
  final bool isPremium;
  final String? priceSku;
  final String shareCode;
  final String? ownerId;
  final bool isHidden;

  const PackSummary({
    required this.id,
    required this.titleFr,
    required this.titleEn,
    required this.descFr,
    required this.descEn,
    required this.isOfficial,
    required this.isPremium,
    required this.priceSku,
    required this.shareCode,
    required this.ownerId,
    required this.isHidden,
  });

  factory PackSummary.fromRow(Map<String, dynamic> row) {
    return PackSummary(
      id: row['id'] as String,
      titleFr: (row['title_fr'] as String?) ?? '',
      titleEn: (row['title_en'] as String?) ?? '',
      descFr: (row['desc_fr'] as String?) ?? '',
      descEn: (row['desc_en'] as String?) ?? '',
      isOfficial: (row['is_official'] as bool?) ?? false,
      isPremium: (row['is_premium'] as bool?) ?? false,
      priceSku: row['price_sku'] as String?,
      shareCode: (row['share_code'] as String?) ?? '',
      ownerId: row['owner_id'] as String?,
      isHidden: (row['is_hidden'] as bool?) ?? false,
    );
  }

  String localizedTitle(String languageCode) =>
      languageCode == 'en' ? titleEn : titleFr;

  String localizedDescription(String languageCode) =>
      languageCode == 'en' ? descEn : descFr;

  /// Pack personnel (UGC) : visible uniquement à son propriétaire via RLS,
  /// donc tout pack non officiel affiché ici est "Mon pack".
  bool get isOwned => ownerId != null && ownerId!.isNotEmpty;

  /// Règle premium actuelle : gratuit => accessible ; premium => droit actif
  /// requis pour priceSku. Premium sans SKU => verrouillé (fail-closed).
  /// Aucun achat dans ce ticket ; aucun flag premium côté client.
  bool isAccessible(Set<String> activeEntitlements) {
    if (!isPremium) return true;
    final sku = priceSku;
    if (sku == null || sku.isEmpty) return false;
    return activeEntitlements.contains(sku);
  }
}

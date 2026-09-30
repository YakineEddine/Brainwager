// Sélection pack pure (Phase 3A) : catalogue -> choix de création.
// Utilisée par /packs (affichage) et CreateScreen (sélection).
// Les packs masqués sont exclus défensivement côté client (RLS filtre déjà).
import 'pack.dart';

/// Packs affichables/sélectionnables : non masqués et accessibles
/// (gratuits ou premium débloqué par entitlement).
List<PackSummary> selectablePacks(
  List<PackSummary> packs,
  Set<String> activeEntitlements,
) {
  return packs
      .where((p) => !p.isHidden && p.isAccessible(activeEntitlements))
      .toList();
}

/// Pack sélectionné par défaut : premier accessible, sinon null
/// (Create désactivé avec message clair).
String? defaultSelectedPackId(
  List<PackSummary> packs,
  Set<String> activeEntitlements,
) {
  final selectable = selectablePacks(packs, activeEntitlements);
  if (selectable.isEmpty) return null;
  return selectable.first.id;
}

// État catalogue Phase 3A (Riverpod, sans code-gen) : packs visibles +
// entitlements actifs, chargés en parallèle. Partagé par /packs et Create.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pack.dart';
import 'pack_preview.dart';
import 'pack_repository.dart';

class PackCatalog {
  final List<PackSummary> packs;
  final Set<String> activeEntitlements;
  const PackCatalog({
    required this.packs,
    required this.activeEntitlements,
  });
}

final packCatalogProvider = FutureProvider<PackCatalog>((ref) async {
  final repo = PackRepository();
  final results = await Future.wait([
    repo.listPacks(),
    repo.activeEntitlements(),
  ]);
  return PackCatalog(
    packs: results[0] as List<PackSummary>,
    activeEntitlements: results[1] as Set<String>,
  );
});

final packPreviewProvider =
    FutureProvider.family<List<PackPreviewQuestion>, String>(
        (ref, packId) => PackRepository().packPreview(packId));

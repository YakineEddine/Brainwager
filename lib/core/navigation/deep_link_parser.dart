// Parser de deep links Brainwager (pur Dart, sans navigation) :
//   brainwager://pack/PK-AB12 -> /packs/shared/PK-AB12
//   brainwager://join/ABCDE   -> /join?code=ABCDE
// Règles : scheme exact `brainwager`, hôte connu, exactement un segment
// valide, normalisation majuscules. Tout le reste est ignoré (null).
// Le parseur ne navigue jamais ; seul le code transite par le lien.
import '../../features/packs/shared_pack.dart';

String? parseBrainwagerLink(Uri uri) {
  if (uri.scheme != 'brainwager') return null;
  final segments =
      uri.pathSegments.where((s) => s.isNotEmpty).toList(growable: false);
  switch (uri.host) {
    case 'pack':
      if (segments.length != 1) return null;
      final code = normalizePackShareCode(segments[0]);
      if (!isValidShareCode(code)) return null;
      return '/packs/shared/$code';
    case 'join':
      if (segments.length != 1) return null;
      final code = segments[0].trim().toUpperCase();
      if (!isValidGameCode(code)) return null;
      return '/join?code=$code';
    default:
      return null;
  }
}

// Modèles profil/avatar Phase social (purs, testables).
// Autorité = RPC 0014 (get_my_profile / list_my_avatars / update_my_profile).
// Aucun calcul de score, aucun matching local, aucune écriture directe.
import '../../core/utils/profanity_filter.dart';

/// Callback OAuth Brainwager (appelé par linkIdentity/signInWithOAuth).
const brainwagerAuthCallback = 'brainwager://auth-callback';

/// Clés d'avatar live (migration 0014, seed).
const liveAvatarKeys = <String>{
  'brain',
  'rocket',
  'star',
  'bolt',
  'planet',
  'trophy',
  'football',
  'basketball',
};

class BrainProfile {
  final String id;
  final String displayName;
  final String locale;
  final String avatarKey;
  final bool onboardingComplete;
  final String? createdAt;
  final String? updatedAt;
  const BrainProfile({
    required this.id,
    required this.displayName,
    required this.locale,
    required this.avatarKey,
    required this.onboardingComplete,
    this.createdAt,
    this.updatedAt,
  });

  factory BrainProfile.fromRpc(Map<String, dynamic> doc) {
    return BrainProfile(
      id: (doc['id'] as String?) ?? '',
      displayName: (doc['display_name'] as String?) ?? '',
      locale: (doc['locale'] as String?) ?? 'fr',
      avatarKey: (doc['avatar_key'] as String?) ?? 'brain',
      onboardingComplete: (doc['onboarding_complete'] as bool?) ?? false,
      createdAt: doc['created_at'] as String?,
      updatedAt: doc['updated_at'] as String?,
    );
  }
}

class BrainAvatar {
  final String avatarKey;
  final int sortOrder;
  final bool isFree;
  final bool unlocked;
  final bool selected;
  const BrainAvatar({
    required this.avatarKey,
    required this.sortOrder,
    required this.isFree,
    required this.unlocked,
    required this.selected,
  });

  factory BrainAvatar.fromRpc(Map<String, dynamic> doc) {
    return BrainAvatar(
      avatarKey: (doc['avatar_key'] as String?) ?? '',
      sortOrder: (doc['sort_order'] as num?)?.toInt() ?? 999,
      isFree: (doc['is_free'] as bool?) ?? false,
      unlocked: (doc['unlocked'] as bool?) ?? false,
      selected: (doc['selected'] as bool?) ?? false,
    );
  }
}

/// Liste d'avatars triée (serveur déjà trié ; repli défensif local).
List<BrainAvatar> parseAvatarList(dynamic data) {
  if (data is! List) return const [];
  final avatars = data
      .whereType<Map>()
      .map((m) => BrainAvatar.fromRpc(Map<String, dynamic>.from(m)))
      .where((a) => a.avatarKey.isNotEmpty)
      .toList();
  avatars.sort((a, b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    if (byOrder != 0) return byOrder;
    return a.avatarKey.compareTo(b.avatarKey);
  });
  return avatars;
}

/// Pseudo d'affichage valide côté client (2..20 + filtre existant).
/// Le serveur tranche en dernier ressort (invalid-display-name).
bool isDisplayNameValid(String name) {
  final n = name.trim();
  if (n.length < 2 || n.length > 20) return false;
  return isNicknameClean(n);
}

/// Pré-remplissage best-effort depuis les métadonnées OAuth
/// (display_name / full_name / name), uniquement si utilisable.
String? prefillDisplayName(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;
  for (final key in ['display_name', 'full_name', 'name']) {
    final raw = metadata[key];
    if (raw is String && isDisplayNameValid(raw)) return raw.trim();
  }
  return null;
}

/// Locale supportée ou repli fr (update_my_profile n'accepte que fr/en/ar).
String supportedLocaleOrFr(String? code) {
  if (code == 'en' || code == 'ar') return code!;
  return 'fr';
}

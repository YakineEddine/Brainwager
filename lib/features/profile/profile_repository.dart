// Repository profil 0014 : RPC UNIQUEMENT (get_my_profile,
// list_my_avatars, update_my_profile). Aucune lecture/écriture directe
// (profiles/avatar_catalog/user_avatar_unlocks jamais touchés en client).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';
import 'profile.dart';

class ProfileRepository {
  final SupabaseClient Function() _client;
  ProfileRepository({SupabaseClient Function()? client})
    : _client = client ?? supa;

  Future<BrainProfile> loadProfile() async {
    final res = await _client().rpc('get_my_profile');
    return BrainProfile.fromRpc(Map<String, dynamic>.from(res as Map));
  }

  Future<List<BrainAvatar>> loadAvatars() async {
    final res = await _client().rpc('list_my_avatars');
    return parseAvatarList(res);
  }

  Future<BrainProfile> saveProfile({
    required String displayName,
    required String avatarKey,
    required String locale,
  }) async {
    final res = await _client().rpc(
      'update_my_profile',
      params: {
        'p_display_name': displayName,
        'p_avatar_key': avatarKey,
        'p_locale': locale,
      },
    );
    return BrainProfile.fromRpc(Map<String, dynamic>.from(res as Map));
  }
}

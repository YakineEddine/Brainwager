// Accès Supabase packs Phase 3A : catalogue (métadonnées seules),
// entitlements actifs, aperçu via RPC. Anti-triche : jamais de SELECT
// direct sur questions officielles, question_answers_private ou
// game_questions — l'aperçu passe par get_pack_preview uniquement.
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client.dart';
import 'pack.dart';
import 'pack_preview.dart';

const _packColumns =
    'id,title_fr,title_en,desc_fr,desc_en,is_official,is_premium,'
    'price_sku,share_code,owner_id,is_hidden';

class PackRepository {
  final SupabaseClient _client;
  PackRepository({SupabaseClient? client}) : _client = client ?? supa();

  /// Catalogue visible (RLS : officiels visibles + packs du user).
  /// Les packs masqués sont exclus défensivement côté client aussi.
  Future<List<PackSummary>> listPacks() async {
    final rows = await _client.from('packs').select(_packColumns);
    return (rows as List)
        .map((r) => PackSummary.fromRow(Map<String, dynamic>.from(r as Map)))
        .where((p) => !p.isHidden)
        .toList();
  }

  /// SKU des droits actifs de l'utilisateur courant (lecture seule).
  Future<Set<String>> activeEntitlements() async {
    final rows = await _client
        .from('entitlements')
        .select('sku')
        .eq('is_active', true);
    return (rows as List)
        .map((r) => (Map<String, dynamic>.from(r as Map))['sku'] as String?)
        .whereType<String>()
        .toSet();
  }

  /// Aperçu anti-triche : 3 lignes max pour un officiel, jamais de réponses.
  Future<List<PackPreviewQuestion>> packPreview(String packId) async {
    final res =
        await _client.rpc('get_pack_preview', params: {'p_pack': packId});
    return parsePackPreview((res as List?) ?? []);
  }
}

// Accès Supabase packs Phase 3A : catalogue (métadonnées seules),
// entitlements actifs, aperçu via RPC. Anti-triche : jamais de SELECT
// direct sur questions officielles, question_answers_private ou
// game_questions — l'aperçu passe par get_pack_preview uniquement.
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client.dart';
import 'pack.dart';
import 'pack_preview.dart';
import 'shared_pack.dart';

const _packColumns =
    'id,title_fr,title_en,title_ar,desc_fr,desc_en,desc_ar,is_official,is_premium,'
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

  /// Résolution d'un pack partagé : UNIQUEMENT get_pack_by_share_code.
  /// Pas de repli table, pas de SELECT direct, pas de réponses/alias.
  /// Le code est normalisé ici (le serveur revalide de toute façon).
  Future<SharedPack> lookupSharedPack(String code) async {
    final normalized = normalizePackShareCode(code);
    final res = await _client.rpc(
      'get_pack_by_share_code',
      params: {'p_code': normalized},
    );
    return SharedPack.fromRpc(Map<String, dynamic>.from(res as Map));
  }

  /// Signalement : UNIQUEMENT report_pack. Raison 3..500 rognée, validée
  /// côté client comme serveur (le serveur tranche en dernier ressort).
  Future<ReportResult> reportPack(String packId, String reason) async {
    final r = reason.trim();
    if (r.length < 3 || r.length > 500) {
      throw Exception('invalid-report-reason');
    }
    final res = await _client.rpc('report_pack', params: {
      'p_pack': packId,
      'p_reason': r,
    });
    return ReportResult.fromRpc(Map<String, dynamic>.from(res as Map));
  }
}

/// Résultat pur de report_pack : premier signalement ou mise à jour.
/// Aucun compteur incrémenté côté client, aucun masquage local.
class ReportResult {
  final bool reported;
  final bool alreadyReported;
  const ReportResult({required this.reported, required this.alreadyReported});

  factory ReportResult.fromRpc(Map<String, dynamic> doc) {
    return ReportResult(
      reported: (doc['reported'] as bool?) ?? false,
      alreadyReported: (doc['already_reported'] as bool?) ?? false,
    );
  }
}

// Repository UGC Phase 3C : uniquement les RPC 0011 déployées.
// Aucune écriture directe (packs/questions/answers) : les policies et
// droits l'interdisent de toute façon. Lecture réponses/alias seulement
// via get_ugc_pack_for_edit (propriétaire éditeur).
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client.dart';
import 'ugc_draft.dart';

class UgcSaveResult {
  final String id;
  final String shareCode;
  const UgcSaveResult({required this.id, required this.shareCode});
}

/// Paramètres create_ugc_pack (purs) : CGU explicites + payload exact.
Map<String, dynamic> buildCreateUgcParams(
  UgcPackDraft draft, {
  required bool acceptTerms,
}) {
  return {
    'p_title_fr': draft.titleFr,
    'p_title_en': draft.titleEn,
    'p_desc_fr': draft.descFr,
    'p_desc_en': draft.descEn,
    'p_questions': [for (final q in draft.questions) q.toRpcJson()],
    'p_accept_terms': acceptTerms,
  };
}

/// Paramètres update_ugc_pack (purs) : jamais de p_accept_terms.
Map<String, dynamic> buildUpdateUgcParams(
  String packId,
  UgcPackDraft draft,
) {
  return {
    'p_pack': packId,
    'p_title_fr': draft.titleFr,
    'p_title_en': draft.titleEn,
    'p_desc_fr': draft.descFr,
    'p_desc_en': draft.descEn,
    'p_questions': [for (final q in draft.questions) q.toRpcJson()],
  };
}

class UgcPackRepository {
  final SupabaseClient _client;
  UgcPackRepository({SupabaseClient? client}) : _client = client ?? supa();

  /// Charge un pack pour édition (réponses + alias inclus, propriétaire).
  Future<UgcPackDraft> loadForEdit(String packId) async {
    final res = await _client
        .rpc('get_ugc_pack_for_edit', params: {'p_pack': packId});
    return parseUgcPackForEdit(Map<String, dynamic>.from(res as Map));
  }

  /// Crée un pack UGC (CGU acceptées exigées, jamais silencieuses).
  Future<UgcSaveResult> createPack(
    UgcPackDraft draft, {
    required bool acceptTerms,
  }) async {
    final res = await _client.rpc(
      'create_ugc_pack',
      params: buildCreateUgcParams(draft, acceptTerms: acceptTerms),
    );
    final m = Map<String, dynamic>.from(res as Map);
    return UgcSaveResult(
      id: m['id'] as String,
      shareCode: (m['share_code'] as String?) ?? '',
    );
  }

  /// Met à jour un pack UGC (pas de p_accept_terms : déjà acceptées).
  Future<UgcSaveResult> updatePack(String packId, UgcPackDraft draft) async {
    final res = await _client.rpc(
      'update_ugc_pack',
      params: buildUpdateUgcParams(packId, draft),
    );
    final m = Map<String, dynamic>.from(res as Map);
    return UgcSaveResult(
      id: (m['id'] as String?) ?? packId,
      shareCode: (m['share_code'] as String?) ?? '',
    );
  }
}

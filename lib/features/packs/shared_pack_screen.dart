// Détail partagé Phase 3D (/packs/shared/:code) : résolu EXCLUSIVEMENT
// via get_pack_by_share_code (même chemin manuel et deep links).
// Affiche métadonnées + prompts RPC, jamais réponses/alias.
// Actions : créer (avec p_share_code serveur), signaler (non possédé),
// éditer (possédé via son propre code).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/game_errors.dart';
import '../../l10n/app_localizations.dart';
import 'pack_repository.dart';
import 'report_pack_dialog.dart';
import 'shared_pack.dart';

class SharedPackScreen extends ConsumerStatefulWidget {
  final String code;
  const SharedPackScreen({super.key, required this.code});

  @override
  ConsumerState<SharedPackScreen> createState() => _SharedPackScreenState();
}

class _SharedPackScreenState extends ConsumerState<SharedPackScreen> {
  Future<({SharedPack pack, Set<String> entitlements})>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(SharedPackScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      setState(() => _future = _load());
    }
  }

  Future<({SharedPack pack, Set<String> entitlements})> _load() async {
    final repo = PackRepository();
    final results = await Future.wait([
      repo.lookupSharedPack(widget.code),
      repo.activeEntitlements(),
    ]);
    return (
      pack: results[0] as SharedPack,
      entitlements: results[1] as Set<String>,
    );
  }

  String _lang() => Localizations.localeOf(context).languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = _lang();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sharedPack)),
      body: FutureBuilder<({SharedPack pack, Set<String> entitlements})>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(friendlyUgcError(
                      snap.error ?? Exception('pack-not-found'), lang)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: Text(l10n.packRetry),
                  ),
                ],
              ),
            );
          }
          final pack = snap.data!.pack;
          final locked =
              !pack.isAccessible(snap.data!.entitlements);
          final badge = pack.isOwned
              ? l10n.packMine
              : pack.isOfficial
                  ? l10n.packOfficial
                  : l10n.sharedPack;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                pack.localizedTitle(lang),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(badge),
              if (pack.localizedDescription(lang).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(pack.localizedDescription(lang)),
                ),
              const SizedBox(height: 8),
              Text('${pack.questionCount}'),
              if (pack.isPremium) ...[
                const SizedBox(height: 8),
                Text(locked
                    ? '${l10n.packPremium} · ${l10n.packLocked}'
                    : l10n.packPremium),
              ],
              const SizedBox(height: 16),
              Text(l10n.packPreview,
                  style: Theme.of(context).textTheme.titleMedium),
              for (final q in pack.questions)
                _PromptTile(
                  prompt: q.localizedPrompt(lang),
                  rtl: lang == 'ar' &&
                      q.promptAr.trim().isNotEmpty,
                  category: q.category,
                  difficulty: q.difficulty,
                  index: q.idx,
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: locked
                    ? null
                    : () => context.go(
                        '/create?share=${pack.shareCode}'),
                child: Text(l10n.packCreateWith),
              ),
              if (locked)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.packComingSoon),
                ),
              if (pack.isOwned)
                OutlinedButton(
                  onPressed: () =>
                      context.push('/packs/edit/${pack.id}'),
                  child: Text(l10n.packEdit),
                )
              else
                OutlinedButton(
                  onPressed: () =>
                      showReportPackDialog(context, pack.id),
                  child: Text(l10n.packReport),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Énoncé seul : jamais de réponse/alias dans ce widget.
class _PromptTile extends StatelessWidget {
  final String prompt;
  final bool rtl;
  final String category;
  final int difficulty;
  final int index;
  const _PromptTile({
    required this.prompt,
    required this.rtl,
    required this.category,
    required this.difficulty,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text('#${index + 1}'),
      title: Text(
        prompt,
        textDirection:
            rtl ? TextDirection.rtl : TextDirection.ltr,
        textAlign: rtl ? TextAlign.right : TextAlign.left,
      ),
      subtitle: Text('$category · $difficulty/3'),
    );
  }
}

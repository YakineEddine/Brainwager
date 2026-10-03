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
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/brain_buttons.dart';
import '../../shared/widgets/brain_card.dart';
import '../../shared/widgets/brain_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/state_views.dart';
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
    return BrainScaffold(
      appBar: AppBar(title: Text(l10n.sharedPack)),
      body: FutureBuilder<({SharedPack pack, Set<String> entitlements})>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const BrainLoading();
          }
          if (snap.hasError || !snap.hasData) {
            return BrainError(
              message: friendlyUgcError(
                snap.error ?? Exception('pack-not-found'),
                lang,
              ),
              onRetry: () => setState(() => _future = _load()),
              retryLabel: l10n.packRetry,
            );
          }
          final pack = snap.data!.pack;
          final locked = !pack.isAccessible(snap.data!.entitlements);
          final textTheme = Theme.of(context).textTheme;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BrainHeroPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.localizedTitle(lang),
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    BrainBadgeRow(
                      badges: [
                        BrainBadge(
                          label: pack.isOwned
                              ? l10n.packMine
                              : pack.isOfficial
                              ? l10n.packOfficial
                              : l10n.sharedPack,
                          kind: pack.isOwned
                              ? BrainBadgeKind.mine
                              : BrainBadgeKind.official,
                        ),
                        if (pack.isPremium)
                          BrainBadge(
                            label: locked
                                ? '${l10n.packPremium} · ${l10n.packLocked}'
                                : l10n.packPremium,
                            kind: locked
                                ? BrainBadgeKind.locked
                                : BrainBadgeKind.premium,
                          ),
                      ],
                    ),
                    if (pack.localizedDescription(lang).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(pack.localizedDescription(lang)),
                      ),
                    const SizedBox(height: 8),
                    Text('${pack.questionCount}', style: textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(title: l10n.packPreview),
              BrainCard(
                child: Column(
                  children: [
                    for (var i = 0; i < pack.questions.length; i++) ...[
                      _PromptTile(
                        prompt: pack.questions[i].localizedPrompt(lang),
                        rtl:
                            lang == 'ar' &&
                            pack.questions[i].promptAr.trim().isNotEmpty,
                        category: pack.questions[i].category,
                        difficulty: pack.questions[i].difficulty,
                        index: pack.questions[i].idx,
                      ),
                      if (i != pack.questions.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BrainPrimaryButton(
                onPressed: locked
                    ? null
                    : () => context.go('/create?share=${pack.shareCode}'),
                child: Text(l10n.packCreateWith),
              ),
              if (locked)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.packComingSoon),
                ),
              const SizedBox(height: 8),
              if (pack.isOwned)
                BrainSecondaryButton(
                  onPressed: () => context.push('/packs/edit/${pack.id}'),
                  expanded: true,
                  child: Text(l10n.packEdit),
                )
              else
                BrainSecondaryButton(
                  onPressed: () => showReportPackDialog(context, pack.id),
                  expanded: true,
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
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        textAlign: rtl ? TextAlign.right : TextAlign.left,
      ),
      subtitle: Text('$category · $difficulty/3'),
    );
  }
}

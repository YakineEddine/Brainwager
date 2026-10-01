// Écrans lobby Phase 3A : create (pack du catalogue) / join via RPC.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/game_errors.dart';
import '../../l10n/app_localizations.dart';
import '../packs/pack_providers.dart';
import '../packs/pack_repository.dart';
import '../packs/pack_selection.dart';
import '../packs/shared_pack.dart';
import 'lobby_viewmodel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.tagline),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/create'),
              child: Text(l10n.createGame),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go('/join'),
              child: Text(l10n.joinGame),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go('/packs'),
              child: Text(l10n.packs),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateScreen extends ConsumerStatefulWidget {
  /// Code partagé optionnel (?share=PK-XXXX) : résolu via le RPC
  /// get_pack_by_share_code (jamais via le catalogue RLS, qui ne le
  /// contient pas forcément). L'URL porte le code (refresh/deep-link OK).
  final String? sharedCode;
  const CreateScreen({super.key, this.sharedCode});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _pseudo = TextEditingController();
  String? _selectedPackId;
  String? _gameLang;
  Future<({SharedPack pack, Set<String> entitlements})>? _sharedFuture;

  @override
  void initState() {
    super.initState();
    _sharedFuture = _sharedFutureFor(widget.sharedCode);
  }

  @override
  void didUpdateWidget(CreateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sharedCode != widget.sharedCode) {
      setState(() => _sharedFuture = _sharedFutureFor(widget.sharedCode));
    }
  }

  Future<({SharedPack pack, Set<String> entitlements})>? _sharedFutureFor(
    String? code,
  ) {
    if (code == null || code.isEmpty) return null;
    // Repo créé DANS la zone async : sans Supabase, l'erreur part en
    // Future (branche erreur UI), jamais en throw synchrone d'initState.
    return (() async {
      final repo = PackRepository();
      final results = await Future.wait([
        repo.lookupSharedPack(code),
        repo.activeEntitlements(),
      ]);
      return (
        pack: results[0] as SharedPack,
        entitlements: results[1] as Set<String>,
      );
    })();
  }

  @override
  void dispose() {
    _pseudo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(packCatalogProvider);
    final l10n = AppLocalizations.of(context)!;
    final appLang = Localizations.localeOf(context).languageCode;
    // Langue du CONTENU (sélecteur, indépendante de l'UI) vs langue UI
    // (messages d'erreur uniquement) : UI FR + partie AR reste AR.
    final gameLanguage = _gameLang ?? defaultGameLanguage(appLang);
    final uiLanguage = appLang;
    // Pack effectif : choix utilisateur s'il reste accessible, sinon défaut.
    // Même logique que le sélecteur ci-dessous.
    String? selectedPackId;
    final repoCatalog = catalog.valueOrNull;
    if (repoCatalog != null) {
      selectedPackId = _selectedPackId;
      final selectable = selectablePacks(
        repoCatalog.packs,
        repoCatalog.activeEntitlements,
      );
      if (selectedPackId == null ||
          !selectable.any((p) => p.id == selectedPackId)) {
        selectedPackId = defaultSelectedPackId(
          repoCatalog.packs,
          repoCatalog.activeEntitlements,
        );
      }
    }
    final shared = widget.sharedCode != null && widget.sharedCode!.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createGame)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _pseudo,
              decoration: InputDecoration(labelText: l10n.nickname),
            ),
            const SizedBox(height: 12),
            // Langue du CONTENU de partie (indépendante de la langue UI) :
            // une UI FR peut créer une partie AR.
            Text(l10n.gameLanguage),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fr', label: Text('Français')),
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'ar', label: Text('العربية')),
              ],
              selected: {gameLanguage},
              onSelectionChanged: (s) => setState(() => _gameLang = s.first),
            ),
            const SizedBox(height: 12),
            // Mode partagé : SEULE la branche partagée (jamais le dropdown
            // catalogue). Mode normal : dropdown + bouton. Le pack partagé
            // ne dépend pas du catalogue RLS.
            if (shared) ...[
              _sharedBranch(gameLanguage),
            ] else ...[
              catalog.when(
                loading: () => Text(l10n.packChoosePack),
                error: (_, _) => Row(
                  children: [
                    Expanded(child: Text(l10n.packLoadError)),
                    TextButton(
                      onPressed: () => ref.invalidate(packCatalogProvider),
                      child: Text(l10n.packRetry),
                    ),
                  ],
                ),
                data: (c) {
                  final selectable = selectablePacks(
                    c.packs,
                    c.activeEntitlements,
                  );
                  if (selectable.isEmpty) {
                    return Text(l10n.packNoAccessiblePack);
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: selectedPackId,
                    decoration: InputDecoration(labelText: l10n.packChoosePack),
                    items: [
                      for (final p in c.packs)
                        if (!p.isHidden)
                          DropdownMenuItem<String>(
                            value: p.id,
                            enabled: p.isAccessible(c.activeEntitlements),
                            child: Text(
                              '${p.localizedTitle(gameLanguage)}'
                              '${p.isAccessible(c.activeEntitlements) ? '' : ' · ${l10n.packLocked}'}',
                            ),
                          ),
                    ],
                    onChanged: (id) => setState(() => _selectedPackId = id),
                  );
                },
              ),
              const SizedBox(height: 12),
              _createButton(
                busy:
                    catalog.isLoading ||
                    catalog.hasError ||
                    selectedPackId == null,
                packId: selectedPackId,
                gameLanguage: gameLanguage,
                uiLanguage: uiLanguage,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Bouton Créer partagé : catalogue normal OU pack partagé résolu.
  /// gameLanguage (contenu) et uiLanguage (messages) restent explicites :
  /// UI FR + العربية sélectionné envoie toujours p_language = ar.
  Widget _createButton({
    required bool busy,
    required String? packId,
    required String gameLanguage,
    required String uiLanguage,
    String? shareCode,
  }) {
    final lobby = ref.watch(lobbyViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    return ElevatedButton(
      onPressed: lobby.isLoading || busy || packId == null
          ? null
          : () async {
              try {
                final s = await ref
                    .read(lobbyViewModelProvider.notifier)
                    .createGame(
                      nickname: _pseudo.text,
                      packId: packId,
                      language: gameLanguage,
                      shareCode: shareCode,
                    );
                if (!mounted) return;
                context.go('/game/${s.gameId}');
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(friendlyGameError(e, uiLanguage))),
                );
              }
            },
      child: Text(l10n.create),
    );
  }

  /// Branche pack partagé (?share=PK-XXXX) : résolu via RPC, jamais via
  /// le catalogue RLS (qui ne le contient pas forcément). Sélecteur
  /// normal masqué ; sortie possible vers /create.
  Widget _sharedBranch(String gameLanguage) {
    final l10n = AppLocalizations.of(context)!;
    final future = _sharedFuture;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<({SharedPack pack, Set<String> entitlements})>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Text(l10n.packChoosePack);
        }
        if (snap.hasError || !snap.hasData) {
          return Row(
            children: [
              Expanded(
                child: Text(
                  friendlyUgcError(
                    snap.error ?? Exception('pack-not-found'),
                    Localizations.localeOf(context).languageCode,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _sharedFuture = _sharedFutureFor(widget.sharedCode),
                ),
                child: Text(l10n.packRetry),
              ),
            ],
          );
        }
        final pack = snap.data!.pack;
        final locked = !pack.isAccessible(snap.data!.entitlements);
        final uiLanguage = Localizations.localeOf(context).languageCode;
        return Column(
          children: [
            ListTile(
              title: Text(pack.localizedTitle(gameLanguage)),
              subtitle: Text(
                '${pack.questionCount} · ${pack.isOfficial ? l10n.packOfficial : l10n.sharedPack}',
              ),
              trailing: locked ? Text(l10n.packLocked) : null,
            ),
            TextButton(
              onPressed: () => context.go('/create'),
              child: Text(l10n.packChoosePack),
            ),
            const SizedBox(height: 12),
            _createButton(
              busy: locked,
              packId: locked ? null : pack.id,
              gameLanguage: gameLanguage,
              uiLanguage: uiLanguage,
              shareCode: locked ? null : pack.shareCode,
            ),
          ],
        );
      },
    );
  }
}

class JoinScreen extends ConsumerStatefulWidget {
  /// Code pré-rempli (?code=, deep link). Appliqué une fois à l'init,
  /// jamais réécrit par-dessus la frappe utilisateur.
  final String? initialCode;
  const JoinScreen({super.key, this.initialCode});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _code = TextEditingController();
  final _pseudo = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCode;
    if (initial != null && initial.isNotEmpty) {
      _code.text = initial;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _pseudo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lobby = ref.watch(lobbyViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinGame)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _code,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: l10n.joinCodeHint),
            ),
            TextField(
              controller: _pseudo,
              decoration: InputDecoration(labelText: l10n.nickname),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: lobby.isLoading
                  ? null
                  : () async {
                      try {
                        final s = await ref
                            .read(lobbyViewModelProvider.notifier)
                            .joinGame(code: _code.text, nickname: _pseudo.text);
                        if (context.mounted) context.go('/game/${s.gameId}');
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(friendlyGameError(e, lang))),
                          );
                        }
                      }
                    },
              child: Text(l10n.joinGame),
            ),
          ],
        ),
      ),
    );
  }
}

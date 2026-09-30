// Écrans lobby Phase 3A : create (pack du catalogue) / join via RPC.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/game_errors.dart';
import '../../l10n/app_localizations.dart';
import '../packs/pack_providers.dart';
import '../packs/pack_selection.dart';
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
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _pseudo = TextEditingController();
  String? _selectedPackId;
  String? _gameLang;

  @override
  void dispose() {
    _pseudo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lobby = ref.watch(lobbyViewModelProvider);
    final catalog = ref.watch(packCatalogProvider);
    final l10n = AppLocalizations.of(context)!;
    final appLang = Localizations.localeOf(context).languageCode;
    final lang = _gameLang ?? defaultGameLanguage(appLang);
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
              selected: {lang},
              onSelectionChanged: (s) =>
                  setState(() => _gameLang = s.first),
            ),
            const SizedBox(height: 12),
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
                final selectable =
                    selectablePacks(c.packs, c.activeEntitlements);
                if (selectable.isEmpty) {
                  return Text(l10n.packNoAccessiblePack);
                }
                return DropdownButtonFormField<String>(
                  initialValue: selectedPackId,
                  decoration:
                      InputDecoration(labelText: l10n.packChoosePack),
                  items: [
                    for (final p in c.packs)
                      if (!p.isHidden)
                        DropdownMenuItem<String>(
                          value: p.id,
                          enabled: p.isAccessible(c.activeEntitlements),
                          child: Text(
                            '${p.localizedTitle(lang)}'
                            '${p.isAccessible(c.activeEntitlements) ? '' : ' · ${l10n.packLocked}'}',
                          ),
                        ),
                  ],
                  onChanged: (id) => setState(() => _selectedPackId = id),
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: lobby.isLoading ||
                      catalog.isLoading ||
                      catalog.hasError ||
                      selectedPackId == null
                  ? null
                  : () async {
                      try {
                        final s = await ref
                            .read(lobbyViewModelProvider.notifier)
                            .createGame(
                              nickname: _pseudo.text,
                              packId: selectedPackId!,
                              language: lang,
                            );
                        if (context.mounted) context.go('/game/${s.gameId}');
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(friendlyGameError(
                                    e,
                                    Localizations.localeOf(context)
                                        .languageCode))),
                          );
                        }
                      }
                    },
              child: Text(l10n.create),
            ),
          ],
        ),
      ),
    );
  }
}

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _code = TextEditingController();
  final _pseudo = TextEditingController();

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
                            .joinGame(
                              code: _code.text,
                              nickname: _pseudo.text,
                            );
                        if (context.mounted) context.go('/game/${s.gameId}');
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text(friendlyGameError(e, lang))),
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

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
    return Scaffold(
      appBar: AppBar(title: const Text('Brainwager')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Parie sur ce que tu sais'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/create'),
              child: const Text('Créer une partie'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go('/join'),
              child: const Text('Rejoindre'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go('/packs'),
              child: Text(AppLocalizations.of(context)!.packs),
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
    final lang = Localizations.localeOf(context).languageCode;
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
      appBar: AppBar(title: const Text('Créer une partie')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _pseudo,
              decoration: const InputDecoration(labelText: 'Pseudo'),
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
                            );
                        if (context.mounted) context.go('/game/${s.gameId}');
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(friendlyGameError(e))),
                          );
                        }
                      }
                    },
              child: const Text('Créer'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Rejoindre')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Code (4-6)'),
            ),
            TextField(
              controller: _pseudo,
              decoration: const InputDecoration(labelText: 'Pseudo'),
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
                                content: Text(friendlyGameError(e))),
                          );
                        }
                      }
                    },
              child: const Text('Rejoindre'),
            ),
          ],
        ),
      ),
    );
  }
}

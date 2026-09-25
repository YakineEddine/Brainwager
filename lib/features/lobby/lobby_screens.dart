// Écrans lobby Phase 2 : create/join réels via RPC (pack démo DEMO01).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void dispose() {
    _pseudo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lobby = ref.watch(lobbyViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Créer une partie')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Pack démo DEMO01 (choix du pack en Phase 3)'),
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
                            .createGame(nickname: _pseudo.text);
                        if (context.mounted) context.go('/game/${s.gameId}');
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
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
                            SnackBar(content: Text('$e')),
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

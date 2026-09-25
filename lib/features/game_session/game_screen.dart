// Écran de partie minimal Phase 2 : question courante, réponse + mise,
// contrôles hôte (suivante, verrouiller, révéler). Le polish arrive Phase 4.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/supabase_client.dart';
import '../../core/network/realtime_service.dart';
import '../../core/utils/clock.dart';
import '../../shared/widgets/countdown_ring.dart';
import '../lobby/lobby_viewmodel.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String gameId;
  const GameScreen({super.key, required this.gameId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  Map<String, dynamic>? _question;
  String? _revealed;
  String _status = '';
  final _answerCtrl = TextEditingController();
  int _wager = 5;
  GameRealtime? _rt;
  final _clock = BrainClock();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _clock.calibrate();
    await _loadQuestion();
    final session = ref.read(lobbyViewModelProvider).value;
    _rt = GameRealtime(widget.gameId);
    _rt!.subscribeChanges(
      onGames: (_) => _loadQuestion(),
      onPlayers: (_) {},
      onScores: (_) => _loadQuestion(),
    );
    if (session != null) {
      await _rt!.subscribePresence(session.playerId, 'moi', (_) {});
    }
  }

  Future<void> _loadQuestion() async {
    try {
      final res =
          await supa().rpc('get_current_question', params: {'p_game': widget.gameId});
      if (!mounted) return;
      setState(() {
        _question = Map<String, dynamic>.from(res as Map);
        _status = _question!['status'] as String? ?? '';
      });
    } catch (_) {
      // Partie pas encore démarrée ou erreur réseau : on garde l'état.
    }
  }

  Future<void> _submit() async {
    final q = _question;
    if (q == null) return;
    try {
      await supa().rpc('submit_answer', params: {
        'p_game': widget.gameId,
        'p_idx': q['position'],
        'p_text': _answerCtrl.text,
        'p_wager': _wager,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réponse envoyée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _startOrNext() async {
    final q = _question;
    try {
      if (_status == 'lobby' || q == null) {
        await supa().rpc('start_game', params: {'p_game': widget.gameId});
      } else {
        final next = ((q['position'] as int?) ?? 0) + 1;
        await supa().rpc('open_question', params: {
          'p_game': widget.gameId,
          'p_idx': next,
        });
      }
      await _rt?.broadcastEvent({'type': 'opened'});
      setState(() => _revealed = null);
      await _loadQuestion();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _lock() async {
    try {
      await supa().rpc('lock_question', params: {'p_game': widget.gameId});
      await _rt?.broadcastEvent({'type': 'locked'});
      await _loadQuestion();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _reveal() async {
    try {
      final res =
          await supa().rpc('reveal_answer', params: {'p_game': widget.gameId});
      await _rt?.broadcastEvent({'type': 'revealed'});
      if (mounted) setState(() => _revealed = res as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void dispose() {
    _rt?.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _question;
    final isFinal = (q?['position'] as int? ?? 0) == 10;
    final wagers = isFinal ? [0, 10, 20] : List.generate(10, (i) => i + 1);
    return Scaffold(
      appBar: AppBar(title: Text('Partie ${_status.isEmpty ? '' : '· $_status'}')),
      body: q == null
          ? const Center(child: Text('En attente du lancement par l’hôte…'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(q['prompt'] as String? ?? '',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                CountdownRing(remainingSec: 30, durationSec: 30),
                const SizedBox(height: 12),
                TextField(
                  controller: _answerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ta réponse',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final w in wagers)
                      ChoiceChip(
                        label: Text('$w'),
                        selected: _wager == w,
                        onSelected: (_) => setState(() => _wager = w),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Valider (réponse + mise)'),
                ),
                const Divider(height: 32),
                ElevatedButton(
                  onPressed: _startOrNext,
                  child: const Text('Démarrer / Question suivante (hôte)'),
                ),
                ElevatedButton(
                  onPressed: _lock,
                  child: const Text('Verrouiller (hôte, ou tous après timer)'),
                ),
                ElevatedButton(
                  onPressed: _reveal,
                  child: const Text('Révéler la réponse'),
                ),
                if (_revealed != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Bonne réponse : $_revealed',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
              ],
            ),
    );
  }
}

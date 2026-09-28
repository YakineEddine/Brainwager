// Écran de partie minimal Phase 2B : question courante, réponse + mise,
// contrôles hôte, countdown serveur, heartbeat, auto-lock, reconnect.
// Broadcast = hints (recharge l'état autoritaire). Aucun tick réseau.
// Le polish arrive Phase 4.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/game_config.dart';
import '../../core/network/heartbeat.dart';
import '../../core/network/supabase_client.dart';
import '../../core/network/realtime_service.dart';
import '../../core/utils/clock.dart';
import '../../shared/widgets/countdown_ring.dart';
import '../game_engine/auto_lock.dart';
import '../game_engine/timing.dart';
import '../lobby/lobby_viewmodel.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String gameId;
  const GameScreen({super.key, required this.gameId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  static const _config = GameConfig();

  Map<String, dynamic>? _question;
  String? _revealed;
  String _status = '';
  bool _isHost = false;
  int _remainingSec = 0;
  int _lastPosition = -1;
  final _answerCtrl = TextEditingController();
  int _wager = 5;
  GameRealtime? _rt;
  GameHeartbeat? _heartbeat;
  Timer? _ticker;
  final _clock = BrainClock();
  final _autoLock = AutoLockTracker();
  bool _booting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  /// Boot/reconnect : recalibre, recharge l'état autoritaire, réabonne
  /// (sans doublons : ancien GameRealtime toujours disposé avant).
  Future<void> _boot() async {
    if (_booting || !mounted) return;
    _booting = true;
    try {
      await _clock.calibrate();
      await _loadQuestion();
      await _fetchOwnHostFlag();
      final session = ref.read(lobbyViewModelProvider).value;
      final rt = GameRealtime(widget.gameId);
      _rt = rt;
      rt.subscribeChanges(
        onGames: (_) => _reloadFromServer(),
        onPlayers: (rec) => _onPlayerRecord(rec, session?.playerId),
        onScores: (_) => _reloadFromServer(),
      );
      rt.subscribeEvents((_) => _reloadFromServer());
      if (session != null) {
        await rt.subscribePresence(
          playerId: session.playerId,
          nickname: session.nickname,
          onSync: (_) {},
        );
        _startHeartbeat();
      }
      _startTicker();
    } finally {
      _booting = false;
    }
  }

  /// Reconnect (resume/disconnect) : stoppe tout, dispose, reboot propre.
  /// Le countdown repart de opened_at absolu : aucun tick manqué ne compte.
  Future<void> _reconnect() async {
    if (!mounted || _booting) return;
    _ticker?.cancel();
    _ticker = null;
    _heartbeat?.dispose();
    _heartbeat = null;
    await _rt?.dispose();
    _rt = null;
    await _boot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconnect();
    }
  }

  Future<void> _reloadFromServer() async {
    await _loadQuestion();
    await _fetchOwnHostFlag();
  }

  Future<void> _loadQuestion() async {
    try {
      final res = await supa()
          .rpc('get_current_question', params: {'p_game': widget.gameId});
      if (!mounted) return;
      final q = Map<String, dynamic>.from(res as Map);
      final pos = (q['position'] as int?) ?? 0;
      setState(() {
        if (_lastPosition != -1 && pos != _lastPosition) {
          _revealed = null; // Nouvelle question : réponse précédente périmée.
        }
        _lastPosition = pos;
        _question = q;
        _status = q['status'] as String? ?? '';
        _remainingSec = _computeRemaining(q);
      });
      _maybeAutoLock();
    } catch (_) {
      // Partie pas encore démarrée ou erreur réseau : on garde l'état.
    }
  }

  /// Flag hôte depuis la ligne players (id stable, pas le pseudo).
  Future<void> _fetchOwnHostFlag() async {
    final session = ref.read(lobbyViewModelProvider).value;
    if (session == null || session.playerId.isEmpty || !mounted) return;
    try {
      final row = await supa()
          .from('players')
          .select('is_host')
          .eq('id', session.playerId)
          .limit(1)
          .single();
      final flag = (row as Map)['is_host'] == true;
      if (mounted && flag != _isHost) {
        setState(() => _isHost = flag);
      }
    } catch (_) {
      // RLS/réseau : on garde le flag de session.
    }
  }

  void _onPlayerRecord(Map<String, dynamic> rec, String? ownPlayerId) {
    if (ownPlayerId == null || ownPlayerId.isEmpty || !mounted) return;
    if (rec['id'] == ownPlayerId && rec.containsKey('is_host')) {
      final flag = rec['is_host'] == true;
      if (flag != _isHost) setState(() => _isHost = flag);
    }
  }

  int _computeRemaining(Map<String, dynamic> q) {
    final openedRaw = q['opened_at'] as String?;
    final duration = (q['duration_sec'] as int?) ?? _config.defaultDurationSec;
    if (openedRaw == null) return duration;
    final opened = DateTime.tryParse(openedRaw)?.toUtc();
    if (opened == null) return duration;
    return remainingSeconds(
      openedAtUtc: opened,
      durationSec: duration,
      nowUtc: _clock.nowUtc(),
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final q = _question;
      if (q == null) return;
      setState(() => _remainingSec = _computeRemaining(q));
      _maybeAutoLock();
    });
  }

  void _startHeartbeat() {
    _heartbeat?.dispose();
    final hb = GameHeartbeat(
      onBeat: () => supa().rpc('touch_presence', params: {
        'p_game': widget.gameId,
      }),
      interval: const Duration(seconds: 15),
    );
    _heartbeat = hb;
    hb.start(); // Beat immédiat + toutes les 15 s, sans chevauchement.
  }

  /// Auto-lock : une seule tentative par question et par client, au point
  /// opened_at + duration − lockGraceSec. Le serveur tranche (idempotent).
  /// Jamais de mutation locale avant confirmation serveur.
  Future<void> _maybeAutoLock() async {
    final q = _question;
    if (q == null || !mounted) return;
    if (_status != 'question_open' && _status != 'final_wager') return;
    final openedRaw = q['opened_at'] as String?;
    if (openedRaw == null) return;
    final opened = DateTime.tryParse(openedRaw)?.toUtc();
    if (opened == null) return;
    final duration = (q['duration_sec'] as int?) ?? _config.defaultDurationSec;
    if (!isLockDue(
      openedAtUtc: opened,
      durationSec: duration,
      lockGraceSec: _config.lockGraceSec,
      nowUtc: _clock.nowUtc(),
    )) {
      return;
    }
    final pos = (q['position'] as int?) ?? 0;
    if (!_autoLock.shouldAttempt(pos)) return;
    _autoLock.markAttempted(pos); // Avant l'appel : pas de retry infini.
    try {
      await supa().rpc('lock_question', params: {'p_game': widget.gameId});
      await _rt?.broadcastEvent({'type': 'locked'});
      await _loadQuestion();
    } catch (_) {
      // Serveur autoritaire (refus/idempotent) : on garde l'état rechargé.
      await _loadQuestion();
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

  Future<void> _showLeaderboard() async {
    try {
      await supa().rpc('show_leaderboard', params: {'p_game': widget.gameId});
      await _loadQuestion();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _finish() async {
    try {
      await supa().rpc('finish_game', params: {'p_game': widget.gameId});
      await _loadQuestion();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _heartbeat?.dispose();
    unawaited(_rt?.dispose());
    _answerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _question;
    final isFinal = (q?['position'] as int? ?? 0) == 10;
    final wagers = isFinal ? [0, 10, 20] : List.generate(10, (i) => i + 1);
    final duration =
        (q?['duration_sec'] as int?) ?? _config.defaultDurationSec;
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
                CountdownRing(
                  remainingSec: _remainingSec,
                  durationSec: duration,
                ),
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
                // Lock ouvert à tous (règles serveur) ; le reste est hôte.
                ElevatedButton(
                  onPressed: _lock,
                  child: const Text('Verrouiller (tous après timer)'),
                ),
                if (_isHost) ...[
                  ElevatedButton(
                    onPressed: _startOrNext,
                    child: const Text('Démarrer / Question suivante (hôte)'),
                  ),
                  ElevatedButton(
                    onPressed: _reveal,
                    child: const Text('Révéler la réponse (hôte)'),
                  ),
                  ElevatedButton(
                    onPressed: _showLeaderboard,
                    child: const Text('Classement (hôte, après reveal)'),
                  ),
                  ElevatedButton(
                    onPressed: _finish,
                    child: const Text('Terminer (hôte, après finale)'),
                  ),
                ],
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

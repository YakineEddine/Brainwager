// Écran de partie Phase 2B : question courante, réponse + mise, contrôles
// pilotés par le statut serveur, countdown serveur, heartbeat, auto-lock,
// reconnect, restauration de session. Broadcast = hints (recharge l'état
// autoritaire). Aucun tick réseau. Le polish arrive Phase 4.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/game_config.dart';
import '../../core/network/heartbeat.dart';
import '../../core/network/supabase_client.dart';
import '../../core/network/realtime_service.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/game_errors.dart';
import '../../shared/widgets/countdown_ring.dart';
import '../game_engine/auto_lock.dart';
import '../game_engine/reveal_policy.dart';
import '../game_engine/timing.dart';
import '../game_engine/wager_validator.dart';
import '../lobby/lobby_viewmodel.dart';

/// Vrai quand l'écran doit afficher l'attente lobby (question encore
/// illisible : get_current_question lève `not-started` en lobby).
bool selectsLobbyView({required bool hasQuestion}) => !hasQuestion;

/// Champ/mises/submit actifs uniquement sur question ouverte.
bool canAnswerIn(String status) =>
    status == 'question_open' || status == 'final_wager';

/// Révéler (transition) : hôte seul, en question_locked.
bool showRevealFor({required String status, required bool isHost}) =>
    isHost && status == 'question_locked';

/// Classement : hôte seul, en reveal.
bool showBoardFor({required String status, required bool isHost}) =>
    isHost && status == 'reveal';

/// Question suivante : hôte seul, en leaderboard, hors finale.
bool showNextFor({
  required String status,
  required bool isHost,
  required int position,
}) =>
    isHost && status == 'leaderboard' && position < 10;

/// Terminer : hôte seul, en final_reveal.
bool showFinishFor({required String status, required bool isHost}) =>
    isHost && status == 'final_reveal';

/// Démarrer : éligibilité membres (le serveur exige minPlayers).
bool startEnabledFor({required int memberCount, required int minPlayers}) =>
    memberCount >= minPlayers;

/// Soumission : question ouverte ET mises autoritaires chargées.
bool canSubmitAnswer({required String status, required bool wagersReady}) =>
    canAnswerIn(status) && wagersReady;

/// Verrou manuel : hôte sur question ouverte ; non-hôte seulement une fois
/// le seuil local de lock tardif atteint (même seuil que l'auto-lock,
/// calcul 100 % local, aucun réseau). Jamais hors question ouverte.
bool showLockFor({
  required String status,
  required bool isHost,
  required bool lockDue,
}) {
  if (status != 'question_open' && status != 'final_wager') return false;
  if (isHost) return true;
  return lockDue;
}

/// État des mises résolu depuis les lignes wagers (pur, testable) :
/// - previousUsed : mises 1..10 des questions normales PRÉCÉDENTES
///   (la mise de la question courante en est exclue : elle reste modifiable) ;
/// - saved : mise enregistrée pour la question courante (restauration) ;
/// - wager : sélection sûre (finale jamais périmée, sinon valeur libre).
({Set<int> previousUsed, int? saved, int wager}) resolveWagerSelection({
  required int position,
  required int current,
  required List<({int idx, int amount})> rows,
}) {
  const finals = [0, 10, 20];
  final prev = <int>{};
  int? saved;
  for (final r in rows) {
    if (position == 10) {
      if (r.idx == 10) saved = r.amount;
    } else {
      if (r.idx == position) {
        saved = r.amount;
      } else if (r.idx >= 0 && r.idx < 10) {
        prev.add(r.amount);
      }
    }
  }
  int wager;
  if (position == 10) {
    if (finals.contains(current)) {
      wager = current;
    } else if (saved != null && finals.contains(saved)) {
      wager = saved;
    } else {
      wager = 0;
    }
  } else {
    if (current >= 1 && current <= 10 && !prev.contains(current)) {
      wager = current;
    } else if (saved != null && saved >= 1 && saved <= 10) {
      wager = saved;
    } else {
      wager = fixWagerForQuestion(
        current: current,
        position: position,
        usedNormal: prev,
      );
    }
  }
  return (previousUsed: prev, saved: saved, wager: wager);
}

/// Remet la mise sur une valeur valide à l'ouverture d'une question :
/// finale -> 0/10/20 (jamais le défaut 5 périmé), normale -> sélection
/// conservée si libre, sinon première mise 1..10 inutilisée.
int fixWagerForQuestion({
  required int current,
  required int position,
  required Set<int> usedNormal,
}) {
  const finals = [0, 10, 20];
  if (position == 10) return finals.contains(current) ? current : 0;
  if (current >= 1 && current <= 10 && !usedNormal.contains(current)) {
    return current;
  }
  final validator = WagerValidator();
  final rest = validator.remainingWagers(usedNormal.toList());
  return rest.isEmpty ? current : rest.first;
}

/// Attente lobby minimale : texte + code de partie + membres + Presence.
/// Bouton Démarrer réservé à l'hôte (players.is_host, jamais le pseudo),
/// grisé tant que le minimum de joueurs n'est pas atteint.
/// Aucun énoncé affiché ici : l'anti-triche reste intacte.
class LobbyWaitingView extends StatelessWidget {
  final bool isHost;
  final int presenceCount;
  final int memberCount;
  final int maxMembers;
  final String? joinCode;
  final bool startEnabled;
  final String? startHint;
  final VoidCallback onStart;
  final Future<void> Function(String code) onCopyCode;
  const LobbyWaitingView({
    super.key,
    required this.isHost,
    required this.presenceCount,
    required this.memberCount,
    required this.maxMembers,
    required this.joinCode,
    required this.startEnabled,
    required this.startHint,
    required this.onStart,
    required this.onCopyCode,
  });

  @override
  Widget build(BuildContext context) {
    final code = joinCode;
    final hint = startHint;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('En attente du lancement par l’hôte…'),
          const SizedBox(height: 8),
          const Text('Code de partie'),
          Text(
            code == null || code.isEmpty ? '…' : code,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (code != null && code.isNotEmpty)
            TextButton(
              onPressed: () => onCopyCode(code),
              child: const Text('Copier le code'),
            ),
          const SizedBox(height: 8),
          Text('Joueurs : $memberCount / $maxMembers'),
          Text('En ligne : $presenceCount'),
          if (isHost) ...[
            const SizedBox(height: 16),
            if (hint != null) Text(hint),
            ElevatedButton(
              onPressed: startEnabled ? onStart : null,
              child: const Text('Démarrer la partie'),
            ),
          ],
        ],
      ),
    );
  }
}

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
  String? _joinCode;
  bool _isHost = false;
  int _memberCount = 0;
  Set<int> _prevUsedWagers = {};
  bool _wagersReady = false;
  int _remainingSec = 0;
  int _presenceCount = 0;
  int _lastPosition = -1;
  String? _sessionError;
  final _answerCtrl = TextEditingController();
  int _wager = 5;
  GameRealtime? _rt;
  GameHeartbeat? _heartbeat;
  Timer? _ticker;
  final _clock = BrainClock();
  final _autoLock = AutoLockTracker();
  bool _autoLockCheckInFlight = false;
  bool _booting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  /// Boot/reconnect : restaure la session (refresh/deep link), recalibre,
  /// recharge l'état autoritaire, réabonne sans doublons.
  Future<void> _boot() async {
    if (_booting || !mounted) return;
    _booting = true;
    try {
      GameSession? session = ref.read(lobbyViewModelProvider).value;
      if (session == null || session.gameId != widget.gameId) {
        try {
          session = await ref
              .read(lobbyViewModelProvider.notifier)
              .restoreGameSession(widget.gameId);
        } catch (e) {
          if (mounted) setState(() => _sessionError = friendlyGameError(e));
          return;
        }
      }
      // Snapshot final : prouvé non-nul ici (déjà valide ou restauré),
      // stable pour les closures ci-dessous (transfert impossible).
      final GameSession s = session;
      if (!mounted) return;
      await _clock.calibrate();
      await _loadQuestion();
      if (mounted) {
        setState(() {
          // Hint initial (+ code mémoire) ; les lignes autoritaires
          // confirment ensuite (players.is_host, games.join_code).
          _isHost = s.isHost;
          if (s.joinCode.isNotEmpty) _joinCode = s.joinCode;
        });
      }
      await _fetchOwnHostFlag();
      await _loadLobbyMeta();
      await _loadMembers();
      await _loadOwnWagers();
      final rt = GameRealtime(widget.gameId);
      _rt = rt;
      rt.subscribeChanges(
        onGames: (_) => _reloadFromServer(),
        onPlayers: (rec) {
          _onPlayerRecord(rec, s.playerId);
          _loadMembers();
        },
        onScores: (_) => _reloadFromServer(),
        onSubscribed: ({required bool isReconnect}) {
          if (isReconnect) _catchUpAfterReconnect();
        },
      );
      rt.subscribeEvents((_) => _reloadFromServer());
      await rt.subscribePresence(
        playerId: s.playerId,
        nickname: s.nickname,
        onSync: (state) {
          if (mounted) setState(() => _presenceCount = state.length);
        },
      );
      _startHeartbeat();
      _startTicker();
    } finally {
      _booting = false;
    }
  }

  /// Reconnect foreground : stoppe tout, dispose, reboot propre.
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
    await _loadLobbyMeta();
    await _loadMembers();
  }

  /// Rattrapage après reconnect : recalibre, recharge tout, restaure la
  /// réponse révélée si permise, garantit le heartbeat.
  Future<void> _catchUpAfterReconnect() async {
    if (!mounted) return;
    await _clock.calibrate();
    await _reloadFromServer();
    await _loadOwnWagers();
    final session = ref.read(lobbyViewModelProvider).value;
    final hb = _heartbeat;
    if (session != null && (hb == null || !hb.isRunning)) {
      _startHeartbeat();
    }
  }

  /// Installe un snapshot autoritaire en un seul setState. N'appelle ni
  /// auto-lock ni sync (pas de récursion : les appelants enchaînent).
  void _installAuthoritativeQuestion(Map<String, dynamic> fresh) {
    if (!mounted) return;
    final pos = (fresh['position'] as int?) ?? 0;
    setState(() {
      if (_lastPosition != -1 && pos != _lastPosition) {
        _revealed = null;
      }
      _lastPosition = pos;
      _question = fresh;
      _status = fresh['status'] as String? ?? '';
      _remainingSec = _computeRemaining(fresh);
    });
  }

  Future<void> _loadQuestion() async {
    try {
      final res = await supa()
          .rpc('get_current_question', params: {'p_game': widget.gameId});
      if (!mounted) return;
      final fresh = Map<String, dynamic>.from(res as Map);
      final pos = (fresh['position'] as int?) ?? 0;
      final isNew = _lastPosition != -1 && pos != _lastPosition;
      _installAuthoritativeQuestion(fresh);
      if (isNew && mounted) {
        // Nouvelle question : purge l'état local de l'ancienne, mise sûre
        // immédiate (finale jamais à 5), puis chargement autoritaire.
        _answerCtrl.clear();
        setState(() {
          _wagersReady = false;
          if (pos == _config.finalQuestionIndex &&
              ![0, 10, 20].contains(_wager)) {
            _wager = 0;
          }
        });
        _loadOwnWagers();
      }
      _maybeAutoLock();
      await _syncRevealedAnswer();
    } catch (_) {
      // Pas encore démarrée / réseau : on garde l'état, lobby méta suit.
      await _loadLobbyMeta();
    }
  }

  /// Réponse officiellement révélée pour TOUS (l'hôte via _reveal, les
  /// autres ici dès reveal/leaderboard/final_reveal/finished).
  Future<void> _syncRevealedAnswer() async {
    if (!mounted || _revealed != null) return;
    if (!maySyncReadRevealed(_status)) return;
    final pos = _lastPosition;
    try {
      final res =
          await supa().rpc('reveal_answer', params: {'p_game': widget.gameId});
      if (!mounted || pos != _lastPosition) return;
      setState(() => _revealed = res as String);
    } catch (_) {
      // Lock entre-temps / réseau : le prochain load réessaiera.
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

  /// Métadonnées lobby (join_code via RLS) : affichées pendant l'attente,
  /// y compris sans session mémoire (refresh/deep link). Jamais inventées.
  Future<void> _loadLobbyMeta() async {
    if (!mounted || _question != null) return;
    try {
      final row = await supa()
          .from('games')
          .select('join_code')
          .eq('id', widget.gameId)
          .limit(1)
          .single();
      final code = (row as Map)['join_code'] as String?;
      if (!mounted || code == null || code.isEmpty || code == _joinCode) {
        return;
      }
      setState(() => _joinCode = code);
    } catch (_) {
      // Placeholder conservé, rechargé au prochain reload autoritaire.
    }
  }

  /// Compte membres autoritaire (players) : éligibilité Start (min 2).
  /// Presence ("En ligne") n'est PAS une autorité d'appartenance.
  Future<void> _loadMembers() async {
    if (!mounted) return;
    try {
      final rows = await supa()
          .from('players')
          .select('id')
          .eq('game_id', widget.gameId);
      final n = (rows as List).length;
      if (mounted && n != _memberCount) setState(() => _memberCount = n);
    } catch (_) {
      // RLS/réseau : on garde le dernier compte connu.
    }
  }

  /// Mises autoritaires du joueur courant (RLS : ses lignes) :
  /// distingue les mises des questions PRÉCÉDENTES de la mise éventuellement
  /// déjà enregistrée pour la question courante (restaurée telle quelle,
  /// modifiable avant lock). _wagersReady ne passe à vrai qu'après succès :
  /// en cas d'échec, la soumission reste bloquée (safe) jusqu'au retry.
  Future<void> _loadOwnWagers() async {
    final session = ref.read(lobbyViewModelProvider).value;
    final pid = session?.playerId;
    if (pid == null || pid.isEmpty || !mounted) return;
    try {
      final rows = await supa()
          .from('wagers')
          .select('amount,question_idx')
          .eq('game_id', widget.gameId)
          .eq('player_id', pid);
      final parsed = <({int idx, int amount})>[];
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final idx = m['question_idx'] as int?;
        final amt = m['amount'] as int?;
        if (idx != null && amt != null) parsed.add((idx: idx, amount: amt));
      }
      if (!mounted) return;
      final pos = _lastPosition < 0 ? 0 : _lastPosition;
      final resolved = resolveWagerSelection(
        position: pos,
        current: _wager,
        rows: parsed,
      );
      setState(() {
        _prevUsedWagers = resolved.previousUsed;
        _wager = resolved.wager;
        _wagersReady = true;
      });
    } catch (_) {
      // Échec : soumission bloquée, retry au prochain reload/reconnect.
    }
  }

  /// Seuil de lock tardif évalué en pur local (aucun réseau) : pilote
  /// l'affichage du bouton Lock non-hôte (même seuil que l'auto-lock).
  bool _lockDueLocal() {
    final q = _question;
    final openedRaw = q?['opened_at'] as String?;
    final opened =
        openedRaw == null ? null : DateTime.tryParse(openedRaw)?.toUtc();
    if (opened == null) return false;
    final duration =
        (q?['duration_sec'] as int?) ?? _config.defaultDurationSec;
    return isLockDue(
      openedAtUtc: opened,
      durationSec: duration,
      lockGraceSec: _config.lockGraceSec,
      nowUtc: _clock.nowUtc(),
    );
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
    hb.start();
  }

  /// Auto-lock : ZÉRO réseau avant le seuil local, une seule validation
  /// fraîche à la fois, tentative réclamée par identité AVANT tout réseau,
  /// verrouillage seulement si le frais est la MÊME question encore ouverte.
  /// Serveur autoritaire. Jamais de mutation locale avant confirmation.
  Future<void> _maybeAutoLock() async {
    final q = _question;
    if (q == null || !mounted) return;
    if (_status != 'question_open' && _status != 'final_wager') return;
    final localPos = (q['position'] as int?) ?? 0;
    final localOpenedAt = q['opened_at'] as String?;
    final duration = (q['duration_sec'] as int?) ?? _config.defaultDurationSec;
    if (!isFreshnessProbeEligible(
      localOpenedAt: localOpenedAt,
      durationSec: duration,
      lockGraceSec: _config.lockGraceSec,
      nowUtc: _clock.nowUtc(),
    )) {
      return;
    }
    if (_autoLockCheckInFlight) return;
    if (!_autoLock.shouldAttempt(
      position: localPos,
      openedAt: localOpenedAt,
    )) {
      return;
    }
    _autoLock.markAttempted(position: localPos, openedAt: localOpenedAt);
    _autoLockCheckInFlight = true;
    try {
      Map<String, dynamic> fresh;
      try {
        final res = await supa().rpc(
          'get_current_question',
          params: {'p_game': widget.gameId},
        );
        fresh = Map<String, dynamic>.from(res as Map);
      } catch (_) {
        return;
      }
      if (!mounted) return;
      final freshOpenedAt = fresh['opened_at'] as String?;
      final freshOpened = freshOpenedAt == null
          ? null
          : DateTime.tryParse(freshOpenedAt)?.toUtc();
      final freshDuration =
          (fresh['duration_sec'] as int?) ?? _config.defaultDurationSec;
      final due = freshOpened != null &&
          isLockDue(
            openedAtUtc: freshOpened,
            durationSec: freshDuration,
            lockGraceSec: _config.lockGraceSec,
            nowUtc: _clock.nowUtc(),
          );
      if (!mayAttemptAutoLock(
        localPosition: localPos,
        localOpenedAt: localOpenedAt,
        freshPosition: (fresh['position'] as int?) ?? 0,
        freshOpenedAt: freshOpenedAt,
        freshStatus: fresh['status'] as String? ?? '',
        lockDue: due,
        notYetAttempted: true,
      )) {
        _installAuthoritativeQuestion(fresh);
        await _syncRevealedAnswer();
        return;
      }
      try {
        await supa().rpc('lock_question', params: {'p_game': widget.gameId});
        await _rt?.broadcastEvent({'type': 'locked'});
        await _loadQuestion();
      } catch (_) {
        await _loadQuestion();
      }
    } finally {
      _autoLockCheckInFlight = false;
    }
  }

  void _snack(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyGameError(e))));
    }
  }

  Future<void> _copyJoinCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Code copié')),
      );
    }
  }

  Future<void> _submit() async {
    final q = _question;
    if (q == null || !_wagersReady) return;
    try {
      await supa().rpc('submit_answer', params: {
        'p_game': widget.gameId,
        'p_idx': q['position'],
        'p_text': _answerCtrl.text,
        'p_wager': _wager,
      });
      await _loadOwnWagers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réponse envoyée')),
        );
      }
    } catch (e) {
      _snack(e);
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
      _snack(e);
    }
  }

  Future<void> _lock() async {
    try {
      await supa().rpc('lock_question', params: {'p_game': widget.gameId});
      await _rt?.broadcastEvent({'type': 'locked'});
      await _loadQuestion();
    } catch (e) {
      _snack(e);
    }
  }

  Future<void> _reveal() async {
    try {
      final res =
          await supa().rpc('reveal_answer', params: {'p_game': widget.gameId});
      await _rt?.broadcastEvent({'type': 'revealed'});
      if (mounted) setState(() => _revealed = res as String);
    } catch (e) {
      _snack(e);
    }
  }

  Future<void> _showLeaderboard() async {
    try {
      await supa().rpc('show_leaderboard', params: {'p_game': widget.gameId});
      await _loadQuestion();
    } catch (e) {
      _snack(e);
    }
  }

  Future<void> _finish() async {
    try {
      await supa().rpc('finish_game', params: {'p_game': widget.gameId});
      await _loadQuestion();
    } catch (e) {
      _snack(e);
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
    final err = _sessionError;
    if (err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Partie')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(err),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }
    final q = _question;
    if (selectsLobbyView(hasQuestion: q != null)) {
      final canStart = startEnabledFor(
        memberCount: _memberCount,
        minPlayers: _config.minPlayers,
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Partie')),
        body: LobbyWaitingView(
          isHost: _isHost,
          presenceCount: _presenceCount,
          memberCount: _memberCount,
          maxMembers: _config.maxPlayers,
          joinCode: _joinCode,
          startEnabled: _isHost && canStart,
          startHint: _isHost && !canStart
              ? 'Joueurs : $_memberCount / ${_config.maxPlayers} — minimum ${_config.minPlayers}'
              : null,
          onStart: _startOrNext,
          onCopyCode: _copyJoinCode,
        ),
      );
    }
    final pos = (q?['position'] as int?) ?? 0;
    final isFinal = pos == _config.finalQuestionIndex;
    final answering = canAnswerIn(_status);
    final submittable = canSubmitAnswer(
      status: _status,
      wagersReady: _wagersReady,
    );
    final lockDue = _lockDueLocal();
    final wagers =
        isFinal ? _config.finalWagers : List.generate(10, (i) => i + 1);
    final duration = (q?['duration_sec'] as int?) ?? _config.defaultDurationSec;
    return Scaffold(
      appBar: AppBar(title: Text('Partie ${_status.isEmpty ? '' : '· $_status'}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(q?['prompt'] as String? ?? '',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          CountdownRing(
            remainingSec: _remainingSec,
            durationSec: duration,
          ),
          const SizedBox(height: 4),
          // Debug Phase 2 : Presence observable (pas une autorité).
          Text('En ligne : $_presenceCount'),
          const SizedBox(height: 12),
          TextField(
            controller: _answerCtrl,
            enabled: answering,
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
                  onSelected: !answering ||
                          !_wagersReady ||
                          (!isFinal && _prevUsedWagers.contains(w))
                      ? null
                      : (_) => setState(() => _wager = w),
                ),
            ],
          ),
          if (answering && !_wagersReady)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Chargement des mises…'),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: submittable ? _submit : null,
            child: const Text('Valider (réponse + mise)'),
          ),
          const Divider(height: 32),
          // Lock piloté par le statut (+ seuil local pour les non-hôtes) ;
          // le reste est strictement piloté par le statut (serveur requis).
          if (showLockFor(
            status: _status,
            isHost: _isHost,
            lockDue: lockDue,
          ))
            ElevatedButton(
              onPressed: _lock,
              child: Text(
                _isHost ? 'Verrouiller' : 'Verrouiller (après timer)',
              ),
            ),
          if (showRevealFor(status: _status, isHost: _isHost))
            ElevatedButton(
              onPressed: _reveal,
              child: const Text('Révéler la réponse (hôte)'),
            ),
          if (showBoardFor(status: _status, isHost: _isHost))
            ElevatedButton(
              onPressed: _showLeaderboard,
              child: const Text('Classement (hôte, après reveal)'),
            ),
          if (showNextFor(status: _status, isHost: _isHost, position: pos))
            ElevatedButton(
              onPressed: _startOrNext,
              child: const Text('Question suivante (hôte)'),
            ),
          if (showFinishFor(status: _status, isHost: _isHost))
            ElevatedButton(
              onPressed: _finish,
              child: const Text('Terminer (hôte, après finale)'),
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

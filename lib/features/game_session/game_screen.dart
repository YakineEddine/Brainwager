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
import '../../core/utils/content_direction.dart';
import '../../core/utils/game_errors.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/brain_buttons.dart';
import '../../shared/widgets/brain_card.dart';
import '../../shared/widgets/brain_scaffold.dart';
import '../../shared/widgets/countdown_ring.dart';
import '../game_engine/auto_lock.dart';
import '../game_engine/reveal_policy.dart';
import '../game_engine/timing.dart';
import '../game_engine/wager_validator.dart';
import '../lobby/lobby_viewmodel.dart';

/// Libellé localisé d'un statut serveur (le brut ne s'affiche jamais seul).
String gameStatusLabel(AppLocalizations l10n, String status) {
  switch (status) {
    case 'lobby':
      return l10n.statusLobby;
    case 'question_open':
      return l10n.statusQuestionOpen;
    case 'question_locked':
      return l10n.statusQuestionLocked;
    case 'reveal':
      return l10n.statusReveal;
    case 'leaderboard':
      return l10n.statusLeaderboard;
    case 'final_wager':
      return l10n.statusFinalWager;
    case 'final_reveal':
      return l10n.statusFinalReveal;
    case 'finished':
      return l10n.statusFinished;
    default:
      return status;
  }
}

/// Réponse officiellement révélée : libellé UI + réponse affichés
/// séparément. La réponse suit la direction du CONTENU de jeu (serveur),
/// pas celle de la locale UI (UI FR + partie AR => réponse RTL).
class RevealedAnswerView extends StatelessWidget {
  final String label;
  final String answer;
  final String languageCode;
  const RevealedAnswerView({
    super.key,
    required this.label,
    required this.answer,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = contentDirection(languageCode) == TextDirection.rtl;
    return Column(
      crossAxisAlignment: rtl
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        Text(
          answer,
          style: Theme.of(context).textTheme.titleLarge,
          textDirection: contentDirection(languageCode),
          textAlign: rtl ? TextAlign.right : TextAlign.left,
        ),
      ],
    );
  }
}

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
}) => isHost && status == 'leaderboard' && position < 10;

/// Terminer : hôte seul, en final_reveal.
bool showFinishFor({required String status, required bool isHost}) =>
    isHost && status == 'final_reveal';

/// Démarrer : éligibilité membres (le serveur exige minPlayers).
bool startEnabledFor({required int memberCount, required int minPlayers}) =>
    memberCount >= minPlayers;

/// Soumission : question ouverte ET mises autoritaires chargées.
bool canSubmitAnswer({required String status, required bool wagersReady}) =>
    canAnswerIn(status) && wagersReady;

/// Bouton Valider : comme ci-dessus, plus jamais pendant un submit en cours
/// (un second clic ne doit pas démarrer une seconde requête).
bool isSubmitAllowed({
  required String status,
  required bool wagersReady,
  required bool submitInFlight,
}) =>
    canSubmitAnswer(status: status, wagersReady: wagersReady) &&
    !submitInFlight;

/// Snapshot exact capturé au démarrage d'un submit (pur) : identité question
/// (jeu + joueur + position + opened_at) + texte + mise soumis. La décision
/// "sauvé" se prend contre ce snapshot, jamais contre l'état UI mutable
/// post-await (frappe ou changement de question entre-temps).
class SubmissionSnapshot {
  final String gameId;
  final String playerId;
  final int position;
  final String? openedAt;
  final String answerText;
  final int wager;
  const SubmissionSnapshot({
    required this.gameId,
    required this.playerId,
    required this.position,
    required this.openedAt,
    required this.answerText,
    required this.wager,
  });

  /// Vrai si l'état actuel correspond encore exactement au snapshot.
  bool matchesCurrent({
    required String gameId,
    required String playerId,
    required int position,
    required String? openedAt,
    required String answerText,
    required int wager,
  }) {
    return gameId == this.gameId &&
        playerId == this.playerId &&
        position == this.position &&
        (openedAt ?? '') == (this.openedAt ?? '') &&
        answerText == this.answerText &&
        wager == this.wager;
  }
}

/// Décision post-submit (pure) : marquer sauvé SSI la requête a réussi ET
/// l'état actuel correspond encore au snapshot soumis. Sinon la frappe
/// locale plus récente est conservée telle quelle (dirty).
bool shouldMarkSubmitted({
  required bool succeeded,
  required SubmissionSnapshot snapshot,
  required String gameId,
  required String playerId,
  required int position,
  required String? openedAt,
  required String answerText,
  required int wager,
}) {
  if (!succeeded) return false;
  return snapshot.matchesCurrent(
    gameId: gameId,
    playerId: playerId,
    position: position,
    openedAt: openedAt,
    answerText: answerText,
    wager: wager,
  );
}

/// Garde de fraîcheur des mises (pure, testable) : un chargement démarré
/// pour une identité question (jeu + joueur + position + opened_at) ne peut
/// valider que cette identité. Boot/resume/reconnect/nouvelle question →
/// beginLoad (ready=false) ; seul un finishLoad correspondant ET toujours
/// actuel passe ready=true. Un résultat périmé est jeté sans toucher l'état.
class WagerLoadGuard {
  String? _pending;
  bool ready = false;

  static String identity({
    required String gameId,
    required String playerId,
    required int position,
    required String? openedAt,
  }) => '$gameId|$playerId|$position|${openedAt ?? ''}';

  void beginLoad(String id) {
    ready = false;
    _pending = id;
  }

  bool finishLoad(String id, {required String currentId}) {
    if (id != _pending || id != currentId) return false;
    ready = true;
    return true;
  }

  void reset() {
    _pending = null;
    ready = false;
  }
}

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

/// Soumission courante (pur, testable) : le serveur détient-il déjà une
/// réponse pour la question affichée ?
class SubmissionState {
  bool hasSavedAnswer = false;

  /// Submit réussi (ou ligne serveur restaurée) : l'état affiché est sauvé.
  void markSubmitted() => hasSavedAnswer = true;

  /// Frappe locale après sauvegarde : modifiée, resoumettable.
  void markEdited() => hasSavedAnswer = false;

  /// Nouvelle question : rien de sauvé pour elle.
  void resetForNewQuestion() => hasSavedAnswer = false;
}

/// Texte serveur à installer après un chargement autoritaire (pur) :
/// la ligne de la question courante, sinon null (ne jamais installer
/// le texte d'une autre question ni inventer une réponse).
String? restoredAnswerText({
  required Map<String, dynamic>? row,
  required int currentPosition,
}) {
  if (row == null) return null;
  if ((row['question_idx'] as int?) != currentPosition) return null;
  final text = row['answer_text'] as String?;
  if (text == null || text.isEmpty) return null;
  return text;
}

/// Garde anti-périmé des chargements de réponse (pure, testable) : même
/// discipline d'identité que WagerLoadGuard (jeu + joueur + position +
/// opened_at). Une réponse Q3 arrivée après l'ouverture Q4 est jetée.
class AnswerLoadGuard {
  String? _pending;

  static String identity({
    required String gameId,
    required String playerId,
    required int position,
    required String? openedAt,
  }) => '$gameId|$playerId|$position|${openedAt ?? ''}';

  void beginLoad(String id) {
    _pending = id;
  }

  bool finishLoad(String id, {required String currentId}) =>
      id == _pending && id == currentId;

  void reset() {
    _pending = null;
  }
}

/// État des mises résolu depuis les lignes wagers (pur, testable).
/// Priorité STRICTE (chargement autoritaire) :
/// 1. mise sauvegardée de la question courante (restauration serveur) ;
/// 2. choix local courant s'il est valide et libre ;
/// 3. première valeur libre (0 en finale).
/// - previousUsed : mises 1..10 des questions normales PRÉCÉDENTES
///   (la mise courante en est exclue : elle reste modifiable) ;
/// - saved : mise enregistrée pour la question courante.
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
    if (saved != null && finals.contains(saved)) {
      wager = saved;
    } else if (finals.contains(current)) {
      wager = current;
    } else {
      wager = 0;
    }
  } else {
    if (saved != null && saved >= 1 && saved <= 10) {
      wager = saved;
    } else if (current >= 1 && current <= 10 && !prev.contains(current)) {
      wager = current;
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
  final int minPlayers;
  final String? joinCode;
  final bool startEnabled;
  final VoidCallback onStart;
  final Future<void> Function(String code) onCopyCode;
  const LobbyWaitingView({
    super.key,
    required this.isHost,
    required this.presenceCount,
    required this.memberCount,
    required this.maxMembers,
    required this.minPlayers,
    required this.joinCode,
    required this.startEnabled,
    required this.onStart,
    required this.onCopyCode,
  });

  @override
  Widget build(BuildContext context) {
    final code = joinCode;
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.waitingForHost,
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          BrainHeroPanel(
            child: Column(
              children: [
                Text(l10n.joinCode, style: textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  code == null || code.isEmpty ? '…' : code,
                  style: textTheme.displaySmall,
                  textDirection: TextDirection.ltr,
                ),
                if (code != null && code.isNotEmpty)
                  BrainGhostButton(
                    onPressed: () => onCopyCode(code),
                    child: Text(l10n.copyCode),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BrainCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$memberCount / $maxMembers',
                      style: textTheme.titleLarge,
                    ),
                    Text(
                      l10n.playersCount(memberCount, maxMembers),
                      style: textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$presenceCount', style: textTheme.titleLarge),
                    Text(
                      l10n.onlineCount(presenceCount),
                      style: textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isHost) ...[
            const SizedBox(height: 16),
            if (!startEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.minPlayersHint(memberCount, maxMembers, minPlayers),
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            BrainPrimaryButton(
              onPressed: startEnabled ? onStart : null,
              child: Text(l10n.gameStart),
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
  String _gameLang = 'fr';
  String? _joinCode;
  bool _isHost = false;
  int _memberCount = 0;
  Set<int> _prevUsedWagers = {};
  final _wagerGuard = WagerLoadGuard();
  bool get _wagersReady => _wagerGuard.ready;
  final _answerGuard = AnswerLoadGuard();
  final _submission = SubmissionState();
  bool _submitInFlight = false;
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
          if (mounted) {
            setState(() => _sessionError = friendlyGameError(e, _lang()));
          }
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
      await _loadOwnAnswer();
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
    await _loadOwnAnswer();
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
      _gameLang = (fresh['language'] as String?) ?? 'fr';
      _remainingSec = _computeRemaining(fresh);
    });
  }

  Future<void> _loadQuestion() async {
    try {
      final res = await supa().rpc(
        'get_current_question',
        params: {'p_game': widget.gameId},
      );
      if (!mounted) return;
      final fresh = Map<String, dynamic>.from(res as Map);
      final pos = (fresh['position'] as int?) ?? 0;
      final isNew = _lastPosition != -1 && pos != _lastPosition;
      _installAuthoritativeQuestion(fresh);
      if (isNew && mounted) {
        // Nouvelle question : purge l'état local de l'ancienne (texte,
        // soumission, mise sûre immédiate) ; les chargements autoritaires
        // suivent (mises + réponse, gardes anti-périmé).
        _answerCtrl.clear();
        setState(() {
          _submission.resetForNewQuestion();
          if (pos == _config.finalQuestionIndex &&
              ![0, 10, 20].contains(_wager)) {
            _wager = 0;
          }
        });
        _loadOwnWagers();
        _loadOwnAnswer();
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
      final res = await supa().rpc(
        'reveal_answer',
        params: {'p_game': widget.gameId},
      );
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

  /// Mises autoritaires du joueur courant (RLS : ses lignes), protégées
  /// contre les réponses périmées : l'identité (jeu + joueur + position +
  /// opened_at) capturée au départ doit encore être l'identité courante à
  /// l'arrivée, sinon le résultat est jeté (ni état ni ready modifiés).
  /// Échec → ready reste false (soumission bloquée, retry au reload).
  Future<void> _loadOwnWagers() async {
    if (!mounted) return;
    final session = ref.read(lobbyViewModelProvider).value;
    final pid = session?.playerId;
    if (pid == null || pid.isEmpty) return;
    final id = WagerLoadGuard.identity(
      gameId: widget.gameId,
      playerId: pid,
      position: _lastPosition,
      openedAt: _question?['opened_at'] as String?,
    );
    setState(() => _wagerGuard.beginLoad(id));
    try {
      final rows = await supa()
          .from('wagers')
          .select('amount,question_idx')
          .eq('game_id', widget.gameId)
          .eq('player_id', pid);
      if (!mounted) return;
      final parsed = <({int idx, int amount})>[];
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final idx = m['question_idx'] as int?;
        final amt = m['amount'] as int?;
        if (idx != null && amt != null) parsed.add((idx: idx, amount: amt));
      }
      final pos = _lastPosition < 0 ? 0 : _lastPosition;
      final resolved = resolveWagerSelection(
        position: pos,
        current: _wager,
        rows: parsed,
      );
      final nowPid = ref.read(lobbyViewModelProvider).value?.playerId ?? '';
      final currentId = WagerLoadGuard.identity(
        gameId: widget.gameId,
        playerId: nowPid,
        position: _lastPosition,
        openedAt: _question?['opened_at'] as String?,
      );
      final fresh = _wagerGuard.finishLoad(id, currentId: currentId);
      if (!fresh || !mounted) return; // Périmé : on jette.
      setState(() {
        _prevUsedWagers = resolved.previousUsed;
        _wager = resolved.wager;
      });
    } catch (_) {
      // Échec : ready reste false, retry au prochain reload/reconnect.
    }
  }

  /// Réponse propre du joueur courant pour la question affichée (RLS : sa
  /// ligne uniquement, jamais celle d'un autre joueur). Appelée sur les
  /// chargements autoritaires (boot, reconnect, nouvelle question) :
  /// jamais sur un simple rebuild/tick (la frappe locale vit sa vie).
  /// Ligne présente → texte installé + soumission marquée sauvée ;
  /// absente → champ vidé. Garde anti-périmé identique aux mises.
  Future<void> _loadOwnAnswer() async {
    if (!mounted) return;
    final session = ref.read(lobbyViewModelProvider).value;
    final pid = session?.playerId;
    if (pid == null || pid.isEmpty) return;
    final pos = _lastPosition;
    if (pos < 0) return; // Pas de question : rien à restaurer.
    final id = AnswerLoadGuard.identity(
      gameId: widget.gameId,
      playerId: pid,
      position: pos,
      openedAt: _question?['opened_at'] as String?,
    );
    _answerGuard.beginLoad(id);
    try {
      final row = await supa()
          .from('player_answers')
          .select('answer_text,question_idx')
          .eq('game_id', widget.gameId)
          .eq('player_id', pid)
          .eq('question_idx', pos)
          .limit(1)
          .maybeSingle();
      if (!mounted) return;
      final nowPid = ref.read(lobbyViewModelProvider).value?.playerId ?? '';
      final currentId = AnswerLoadGuard.identity(
        gameId: widget.gameId,
        playerId: nowPid,
        position: _lastPosition,
        openedAt: _question?['opened_at'] as String?,
      );
      if (!_answerGuard.finishLoad(id, currentId: currentId)) {
        return; // Périmé : on jette.
      }
      final text = restoredAnswerText(
        row: row == null ? null : Map<String, dynamic>.from(row as Map),
        currentPosition: _lastPosition,
      );
      setState(() {
        if (text == null) {
          _answerCtrl.clear();
          _submission.resetForNewQuestion();
        } else {
          if (_answerCtrl.text != text) _answerCtrl.text = text;
          _submission.markSubmitted();
        }
      });
    } catch (_) {
      // Réseau : on garde la frappe locale, retry au prochain reload.
    }
  }

  /// Seuil de lock tardif évalué en pur local (aucun réseau) : pilote
  /// l'affichage du bouton Lock non-hôte (même seuil que l'auto-lock).
  bool _lockDueLocal() {
    final q = _question;
    final openedRaw = q?['opened_at'] as String?;
    final opened = openedRaw == null
        ? null
        : DateTime.tryParse(openedRaw)?.toUtc();
    if (opened == null) return false;
    final duration = (q?['duration_sec'] as int?) ?? _config.defaultDurationSec;
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
      onBeat: () =>
          supa().rpc('touch_presence', params: {'p_game': widget.gameId}),
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
    if (!_autoLock.shouldAttempt(position: localPos, openedAt: localOpenedAt)) {
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
      final due =
          freshOpened != null &&
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

  String _lang() => Localizations.localeOf(context).languageCode;

  void _snack(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyGameError(e, _lang()))));
    }
  }

  Future<void> _copyJoinCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.codeCopied)),
      );
    }
  }

  Future<void> _submit() async {
    final q = _question;
    if (q == null || !_wagersReady || _submitInFlight) return;
    // Snapshot exact : tout le verdict post-await se joue contre lui,
    // jamais contre l'état UI mutable (frappe ou Q suivante entre-temps).
    final snap = SubmissionSnapshot(
      gameId: widget.gameId,
      playerId: ref.read(lobbyViewModelProvider).value?.playerId ?? '',
      position: (q['position'] as int?) ?? 0,
      openedAt: q['opened_at'] as String?,
      answerText: _answerCtrl.text,
      wager: _wager,
    );
    setState(() => _submitInFlight = true);
    var succeeded = false;
    try {
      await supa().rpc(
        'submit_answer',
        params: {
          'p_game': snap.gameId,
          'p_idx': snap.position,
          'p_text': snap.answerText,
          'p_wager': snap.wager,
        },
      );
      await _loadOwnWagers();
      succeeded = true;
    } catch (e) {
      _snack(e);
    } finally {
      // Toujours réinitialisé, succès comme échec ; jamais de markSaved
      // sur un état plus récent que le snapshot (frappe ou Q4 entre-temps).
      if (!mounted) {
        _submitInFlight = false;
      } else {
        final mark = shouldMarkSubmitted(
          succeeded: succeeded,
          snapshot: snap,
          gameId: widget.gameId,
          playerId: ref.read(lobbyViewModelProvider).value?.playerId ?? '',
          position: _lastPosition,
          openedAt: _question?['opened_at'] as String?,
          answerText: _answerCtrl.text,
          wager: _wager,
        );
        setState(() {
          _submitInFlight = false;
          if (mark) _submission.markSubmitted();
        });
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
        await supa().rpc(
          'open_question',
          params: {'p_game': widget.gameId, 'p_idx': next},
        );
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
      final res = await supa().rpc(
        'reveal_answer',
        params: {'p_game': widget.gameId},
      );
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
    final l10n = AppLocalizations.of(context)!;
    if (err != null) {
      return BrainScaffold(
        appBar: AppBar(title: Text(l10n.gameTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(err),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: Text(l10n.back),
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
      return BrainScaffold(
        appBar: AppBar(title: Text(l10n.gameTitle)),
        body: LobbyWaitingView(
          isHost: _isHost,
          presenceCount: _presenceCount,
          memberCount: _memberCount,
          maxMembers: _config.maxPlayers,
          minPlayers: _config.minPlayers,
          joinCode: _joinCode,
          startEnabled: _isHost && canStart,
          onStart: _startOrNext,
          onCopyCode: _copyJoinCode,
        ),
      );
    }
    final pos = (q?['position'] as int?) ?? 0;
    final isFinal = pos == _config.finalQuestionIndex;
    final answering = canAnswerIn(_status);
    final lockDue = _lockDueLocal();
    final wagers = isFinal
        ? _config.finalWagers
        : List.generate(10, (i) => i + 1);
    final duration = (q?['duration_sec'] as int?) ?? _config.defaultDurationSec;
    return BrainScaffold(
      appBar: AppBar(
        title: Text(
          _status.isEmpty
              ? l10n.gameTitle
              : '${l10n.gameTitle} · ${gameStatusLabel(l10n, _status)}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BrainHeroPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  q?['prompt'] as String? ?? '',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textDirection: contentDirection(_gameLang),
                  textAlign: _gameLang == 'ar'
                      ? TextAlign.right
                      : TextAlign.left,
                ),
                const SizedBox(height: 12),
                CountdownRing(
                  remainingSec: _remainingSec,
                  durationSec: duration,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Debug Phase 2 : Presence observable (pas une autorité).
          Text(l10n.onlineCount(_presenceCount)),
          const SizedBox(height: 12),
          TextField(
            controller: _answerCtrl,
            enabled: answering,
            textDirection: contentDirection(_gameLang),
            onChanged: (_) {
              // Frappe après sauvegarde : modifiée localement, resoumettable.
              if (_submission.hasSavedAnswer && mounted) {
                setState(() => _submission.markEdited());
              }
            },
            decoration: InputDecoration(
              labelText: l10n.answerHint,
              border: const OutlineInputBorder(),
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
                  // Réponse + mise = une seule soumission : changer de mise
                  // après sauvegarde rend l'état dirty (resoumission requise).
                  onSelected:
                      !answering ||
                          !_wagersReady ||
                          _submitInFlight ||
                          (!isFinal && _prevUsedWagers.contains(w))
                      ? null
                      : (_) => setState(() {
                          _wager = w;
                          _submission.markEdited();
                        }),
                ),
            ],
          ),
          if (answering && !_wagersReady)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l10n.loadingWagers),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed:
                isSubmitAllowed(
                  status: _status,
                  wagersReady: _wagersReady,
                  submitInFlight: _submitInFlight,
                )
                ? _submit
                : null,
            child: Text(l10n.submitAnswer),
          ),
          if (_submission.hasSavedAnswer && answering)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l10n.answerSaved),
            ),
          const Divider(height: 32),
          // Lock piloté par le statut (+ seuil local pour les non-hôtes) ;
          // le reste est strictement piloté par le statut (serveur requis).
          if (showLockFor(status: _status, isHost: _isHost, lockDue: lockDue))
            ElevatedButton(
              onPressed: _lock,
              child: Text(_isHost ? l10n.hostLock : l10n.hostLockLate),
            ),
          if (showRevealFor(status: _status, isHost: _isHost))
            ElevatedButton(onPressed: _reveal, child: Text(l10n.revealAnswer)),
          if (showBoardFor(status: _status, isHost: _isHost))
            ElevatedButton(
              onPressed: _showLeaderboard,
              child: Text(l10n.hostBoard),
            ),
          if (showNextFor(status: _status, isHost: _isHost, position: pos))
            ElevatedButton(onPressed: _startOrNext, child: Text(l10n.hostNext)),
          if (showFinishFor(status: _status, isHost: _isHost))
            ElevatedButton(onPressed: _finish, child: Text(l10n.hostFinish)),
          if (_revealed case final String revealed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RevealedAnswerView(
                label: l10n.correctAnswer,
                answer: revealed,
                languageCode: _gameLang,
              ),
            ),
        ],
      ),
    );
  }
}

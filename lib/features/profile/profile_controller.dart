// Contrôleur profil/onboarding (Riverpod, sans code-gen).
// Autorité = RPC 0014 + Supabase Auth. Fakes injectables en tests.
// Un seul abonnement onAuthStateChange ; dispose sûr ; jamais de poll.
// Recharges sérialisées par génération, pilotées par les events :
// un vol à la fois, un event pertinent pendant un vol demande UN suivi,
// aucun vol ne s'auto-planifie. Résultats périmés jetés, changement de
// compte / sign-out => fail-closed immédiat. Save et refresh avatars
// identity-safe (résultat périmé jamais installé).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_gateway.dart';
import 'profile.dart';
import 'profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(),
);

final socialAuthGatewayProvider = Provider<SocialAuthGateway>(
  (ref) => SupabaseSocialAuthGateway(),
);

class ProfileUiState {
  /// Vrai jusqu'à la première détermination (fail-closed : la gate
  /// n'expose jamais le contenu avant).
  final bool profileLoading;
  final BrainProfile? profile;
  final String? profileError;
  final List<BrainAvatar> avatars;
  final bool avatarsLoading;
  final bool saving;
  final String? saveError;
  final bool oauthPending;
  final String? oauthError;
  final List<String> providers;

  /// État compte autoritaire (gateway), rafraîchi aux events auth/reloads.
  final bool isAnonymous;
  const ProfileUiState({
    this.profileLoading = false,
    this.profile,
    this.profileError,
    this.avatars = const [],
    this.avatarsLoading = false,
    this.saving = false,
    this.saveError,
    this.oauthPending = false,
    this.oauthError,
    this.providers = const [],
    this.isAnonymous = true,
  });

  /// Gate : profil chargé ET onboarding terminé.
  bool get gateOpen => profile != null && profile!.onboardingComplete;

  ProfileUiState copyWith({
    bool? profileLoading,
    BrainProfile? Function()? profile,
    String? Function()? profileError,
    List<BrainAvatar>? avatars,
    bool? avatarsLoading,
    bool? saving,
    String? Function()? saveError,
    bool? oauthPending,
    String? Function()? oauthError,
    List<String>? providers,
    bool? isAnonymous,
  }) {
    return ProfileUiState(
      profileLoading: profileLoading ?? this.profileLoading,
      profile: profile == null ? this.profile : profile(),
      profileError: profileError == null ? this.profileError : profileError(),
      avatars: avatars ?? this.avatars,
      avatarsLoading: avatarsLoading ?? this.avatarsLoading,
      saving: saving ?? this.saving,
      saveError: saveError == null ? this.saveError : saveError(),
      oauthPending: oauthPending ?? this.oauthPending,
      oauthError: oauthError == null ? this.oauthError : oauthError(),
      providers: providers ?? this.providers,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }
}

class ProfileController extends Notifier<ProfileUiState> {
  StreamSubscription<AuthEvent>? _sub;
  bool _started = false;

  /// Sérialisation pilotée par events : un seul vol réseau à la fois,
  /// génération monotone, UN suivi coalescé. Les tours supplémentaires
  /// exigent une demande externe (event pertinent / retry) ; aucun vol
  /// ne s'auto-planifie en boucle.
  bool _flight = false;
  bool _reloadPending = false;
  int _generation = 0;

  @override
  ProfileUiState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
      _started = false;
    });
    return const ProfileUiState();
  }

  ProfileRepository get _repo => ref.read(profileRepositoryProvider);
  SocialAuthGateway get _auth => ref.read(socialAuthGatewayProvider);

  String? _safeUid() {
    try {
      return _auth.currentUserId;
    } catch (_) {
      return null;
    }
  }

  bool _safeAnon() {
    try {
      return _auth.isAnonymous;
    } catch (_) {
      return true;
    }
  }

  /// Démarrage unique : abonnement auth + chargement initial.
  Future<void> ensureStarted() async {
    if (_started) return;
    _started = true;
    try {
      _sub = _auth.authStateChanges.listen(
        (e) => reloadFromAuthEvent(e),
        onError: (_) {},
      );
    } catch (_) {}
    await reloadAll();
  }

  /// Recharge profil + avatars + providers (retry manuel / démarrage).
  /// Sérialisée : si un vol est en cours, invalide et coalesce UN suivi.
  Future<void> reloadAll() => _enqueueReload();

  /// Event auth pertinent : recharge autoritative. Token refresh / session
  /// initiale : ignorés. Sign-out : fail-closed immédiat, SANS rpc
  /// (jamais un succès OAuth) ; le reload attendra le prochain
  /// signedIn/userUpdated. Jamais de poll, jamais de double abonnement.
  Future<void> reloadFromAuthEvent(AuthEvent event) async {
    if (!event.shouldReload) return;
    if (event.kind == AuthEventKind.signedOut) {
      _failClosedSignedOut();
      return;
    }
    state = state.copyWith(oauthPending: false);
    _failClosedOnAccountSwitch();
    await _enqueueReload();
  }

  /// Sign-out : l'ancien compte disparaît aussitôt. Invalide les vols,
  /// efface tout, referme la gate. Aucun RPC sans utilisateur.
  void _failClosedSignedOut() {
    _generation++;
    state = state.copyWith(
      profileLoading: false,
      profile: () => null,
      avatars: const [],
      providers: const [],
      profileError: () => null,
      saveError: () => null,
      oauthPending: false,
      isAnonymous: _safeAnon(),
    );
  }

  /// Changement de compte : l'ancien profil ne doit jamais s'afficher
  /// sous la nouvelle session. Efface tout et referme la gate.
  /// Link (UUID inchangé) => simple refresh autoritaire, sans clear.
  void _failClosedOnAccountSwitch() {
    final currentId = _safeUid();
    state = state.copyWith(isAnonymous: _safeAnon());
    final oldId = state.profile?.id;
    if (currentId != null &&
        oldId != null &&
        oldId.isNotEmpty &&
        currentId != oldId) {
      _generation++;
      state = state.copyWith(
        profileLoading: true,
        profile: () => null,
        avatars: const [],
        providers: const [],
        profileError: () => null,
        saveError: () => null,
      );
    }
  }

  /// File sérialisée : un vol, puis UN suivi seulement si un event
  /// externe l'a demandé pendant le vol.Bornée par construction.
  Future<void> _enqueueReload() async {
    if (_flight) {
      // Un vol est en cours : l'invalider et coalescer UN suivi unique.
      _generation++;
      _reloadPending = true;
      return;
    }
    _flight = true;
    try {
      do {
        _reloadPending = false;
        await _runSingleFlight();
        // Seul un event externe (ou un UID changé en vol, une fois)
        // peut avoir reposé le drapeau : sinon on termine.
      } while (_reloadPending);
    } finally {
      _flight = false;
      _reloadPending = false;
    }
  }

  /// Un seul vol réseau. Ne planifie JAMAIS lui-même un nouveau tour,
  /// sauf UID changé observé en vol (un seul suivi autoritaire).
  /// Profil chargé d'un autre id que la session => données invalides :
  /// jetées, fail-closed `profile-load-error`, SANS retry.
  Future<void> _runSingleFlight() async {
    final gen = ++_generation;
    final uidAtStart = _safeUid();
    final anonAtStart = _safeAnon();
    // Aucun utilisateur : fail-closed immédiat, AUCUN rpc.
    if (uidAtStart == null || uidAtStart.isEmpty) {
      state = state.copyWith(
        profileLoading: false,
        profile: () => null,
        avatars: const [],
        providers: const [],
        profileError: () => null,
        saveError: () => null,
        isAnonymous: anonAtStart,
      );
      return;
    }
    // Switch détecté au démarrage du vol : efface avant tout réseau.
    final oldId = state.profile?.id;
    if (oldId != null && oldId.isNotEmpty && oldId != uidAtStart) {
      state = state.copyWith(
        profileLoading: true,
        profile: () => null,
        avatars: const [],
        providers: const [],
        profileError: () => null,
        saveError: () => null,
        isAnonymous: anonAtStart,
      );
    } else {
      state = state.copyWith(
        profileLoading: true,
        profileError: () => null,
        isAnonymous: anonAtStart,
      );
    }
    Object? error;
    BrainProfile? loadedProfile;
    List<BrainAvatar>? loadedAvatars;
    List<String>? loadedProviders;
    try {
      final results = await Future.wait([
        _repo.loadProfile(),
        _repo.loadAvatars(),
        _auth.connectedProviders(),
      ]);
      loadedProfile = results[0] as BrainProfile;
      loadedAvatars = results[1] as List<BrainAvatar>;
      loadedProviders = (results[2] as List<String>);
    } catch (e) {
      error = e;
    }
    // Vol périmé (event plus récent) : résultats jetés, sans rejouer.
    // Le suivi éventuel, déjà coalescé, sera drainé par l'appelant.
    if (gen != _generation) return;
    final uidNow = _safeUid();
    final anonNow = _safeAnon();
    // UID changé pendant le vol : un seul suivi autoritaire.
    if (uidNow != uidAtStart) {
      _reloadPending = true;
      return;
    }
    if (error != null) {
      state = state.copyWith(
        profileLoading: false,
        profileError: () => _loadCodeOf(error!),
        isAnonymous: anonNow,
      );
      return;
    }
    final p = loadedProfile!;
    // Garde-fou : le profil chargé doit appartenir à la session.
    // Sinon données invalides => fail-closed, JAMAIS de retry.
    if (p.id.isNotEmpty && p.id != uidNow) {
      state = state.copyWith(
        profileLoading: false,
        profile: () => null,
        avatars: const [],
        providers: const [],
        profileError: () => 'profile-load-error',
        isAnonymous: anonNow,
      );
      return;
    }
    state = state.copyWith(
      profileLoading: false,
      profile: () => p,
      avatars: loadedAvatars ?? const [],
      providers: loadedProviders ?? const [],
      isAnonymous: anonNow,
    );
  }

  /// Sauvegarde identity-safe via update_my_profile (jamais optimiste).
  /// Le résultat ne s'installe que si l'identité est inchangée et que le
  /// profil sauvé appartient à la session. Sinon : jeté (sans erreur
  /// parasite pour le nouveau compte), reload autoritaire, false.
  Future<bool> save({
    required String displayName,
    required String avatarKey,
    required String locale,
  }) async {
    if (!isDisplayNameValid(displayName)) {
      state = state.copyWith(saveError: () => 'invalid-display-name');
      return false;
    }
    final uidBefore = _safeUid();
    state = state.copyWith(saving: true, saveError: () => null);
    BrainProfile saved;
    try {
      saved = await _repo.saveProfile(
        displayName: displayName.trim(),
        avatarKey: avatarKey,
        locale: supportedLocaleOrFr(locale),
      );
    } catch (e) {
      if (_safeUid() != uidBefore) {
        state = state.copyWith(saving: false, saveError: () => null);
        await _enqueueReload();
        return false;
      }
      state = state.copyWith(saving: false, saveError: () => _saveCodeOf(e));
      return false;
    }
    final uidAfter = _safeUid();
    if (uidAfter != uidBefore ||
        (uidAfter != null && saved.id.isNotEmpty && saved.id != uidAfter)) {
      state = state.copyWith(saving: false, saveError: () => null);
      await _enqueueReload();
      return false;
    }
    state = state.copyWith(saving: false, profile: () => saved);
    await _reloadAvatarsIdentitySafe(uidAfter);
    return true;
  }

  /// Refresh avatars post-save : installe seulement si l'identité est
  /// inchangée, sinon jette (jamais d'avatars périmés sous un nouveau
  /// compte). Intégré au save, pas de fire-and-forget aveugle.
  Future<void> _reloadAvatarsIdentitySafe(String? uid) async {
    state = state.copyWith(avatarsLoading: true);
    List<BrainAvatar> fresh;
    try {
      fresh = await _repo.loadAvatars();
    } catch (_) {
      state = state.copyWith(avatarsLoading: false);
      return;
    }
    if (_safeUid() != uid) {
      state = state.copyWith(avatarsLoading: false);
      return;
    }
    state = state.copyWith(avatars: fresh, avatarsLoading: false);
  }

  /// Sécurise l'invité courant (UUID préservé) : linkIdentity.
  /// true = navigateur ouvert (PAS authentifié) ; l'event auth tranche.
  Future<void> secureWithGoogle() => _link(_auth.linkGoogle);

  /// Idem Facebook.
  Future<void> secureWithFacebook() => _link(_auth.linkFacebook);

  /// Compte existant (autre appareil) : signInWithOAuth.
  /// Jamais choisi silencieusement à la place du link.
  Future<void> signInExistingGoogle() => _link(_auth.signInGoogle);

  /// Idem Facebook.
  Future<void> signInExistingFacebook() => _link(_auth.signInFacebook);

  Future<void> _link(Future<bool> Function() call) async {
    state = state.copyWith(oauthPending: true, oauthError: () => null);
    bool launched = false;
    try {
      launched = await call();
    } catch (_) {
      launched = false;
    }
    if (!launched) {
      // Navigateur indisponible : session invité intacte, UI réutilisable.
      state = state.copyWith(
        oauthPending: false,
        oauthError: () => 'oauth-unavailable',
      );
    }
    // Sinon : en attente de l'event auth (reloadFromAuthEvent).
  }

  String _loadCodeOf(Object e) {
    final text = '$e';
    const known = {
      'not-authenticated',
      'profile-not-found',
      'invalid-display-name',
      'invalid-locale',
      'avatar-locked-or-invalid',
    };
    for (final token in RegExp(r'[a-z]+(?:-[a-z]+)+').allMatches(text)) {
      if (known.contains(token.group(0))) return token.group(0)!;
    }
    return 'profile-load-error';
  }

  String _saveCodeOf(Object e) {
    final text = '$e';
    const known = {
      'not-authenticated',
      'profile-not-found',
      'invalid-display-name',
      'invalid-locale',
      'avatar-locked-or-invalid',
    };
    for (final token in RegExp(r'[a-z]+(?:-[a-z]+)+').allMatches(text)) {
      if (known.contains(token.group(0))) return token.group(0)!;
    }
    return 'profile-save-error';
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileUiState>(ProfileController.new);

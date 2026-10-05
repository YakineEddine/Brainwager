// Contrôleur profil/onboarding (Riverpod, sans code-gen).
// Autorité = RPC 0014 + Supabase Auth. Fakes injectables en tests.
// Un seul abonnement onAuthStateChange ; dispose sûr ; jamais de poll.
// Recharges sérialisées par génération : un vol à la fois, l'event auth
// invalide les vols périmés, un seul suivi en attente, résultats périmés
// jetés, changement de compte => fail-closed immédiat.
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

  /// Sérialisation : un seul vol réseau à la fois, génération monotone,
  /// un seul suivi en attente. Jamais de `_loading = false` forcé.
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
  /// Sérialisée : si un vol est en cours, marque un suivi et revient.
  Future<void> reloadAll() => _enqueueReload();

  /// Event auth pertinent (SIGNED_IN / USER_UPDATED / identité / sign-out) :
  /// recharge autoritative. Token refresh / session initiale : ignorés
  /// (pas de reload inutile). Jamais de poll, jamais de double abonnement.
  Future<void> reloadFromAuthEvent(AuthEvent event) async {
    if (!event.shouldReload) return;
    state = state.copyWith(oauthPending: false);
    _failClosedOnAccountSwitch();
    await _enqueueReload();
  }

  /// Changement de compte : l'ancien profil ne doit jamais s'afficher
  /// sous la nouvelle session. Efface tout et referme la gate.
  /// Link (UUID inchangé) => simple refresh autoritaire, sans clear.
  void _failClosedOnAccountSwitch() {
    String? currentId;
    bool anon = true;
    try {
      currentId = _auth.currentUserId;
      anon = _auth.isAnonymous;
    } catch (_) {}
    state = state.copyWith(isAnonymous: anon);
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

  Future<void> _enqueueReload() async {
    if (_flight) {
      // Un vol est en cours : l'invalider et prévoir UN suivi unique.
      _generation++;
      _reloadPending = true;
      return;
    }
    _flight = true;
    try {
      // Boucle bornée : chaque tour consomme le suivi en attente.
      // ignore: literal_only_boolean_expressions
      while (true) {
        _reloadPending = false;
        final gen = ++_generation;
        String? uidAtStart;
        bool anonAtStart = true;
        try {
          uidAtStart = _auth.currentUserId;
          anonAtStart = _auth.isAnonymous;
        } catch (_) {}
        // Re-vérifie le switch au démarrage du vol (fail-closed).
        final oldId = state.profile?.id;
        if (uidAtStart != null &&
            oldId != null &&
            oldId.isNotEmpty &&
            uidAtStart != oldId) {
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
        // Vol périmé (event plus récent) : résultats jetés.
        if (gen != _generation) {
          if (_reloadPending) continue;
          return;
        }
        // Utilisateur changé pendant le vol : jeter, refaire un tour.
        String? uidNow;
        bool anonNow = true;
        try {
          uidNow = _auth.currentUserId;
          anonNow = _auth.isAnonymous;
        } catch (_) {}
        if (uidAtStart != uidNow) {
          _reloadPending = true;
          continue;
        }
        if (error != null) {
          state = state.copyWith(
            profileLoading: false,
            profileError: () => _loadCodeOf(error!),
            isAnonymous: anonNow,
          );
        } else {
          final p = loadedProfile!;
          // Garde-fou : le profil chargé doit appartenir à la session.
          if (uidNow != null && p.id.isNotEmpty && p.id != uidNow) {
            _reloadPending = true;
            continue;
          }
          state = state.copyWith(
            profileLoading: false,
            profile: () => p,
            avatars: loadedAvatars ?? const [],
            providers: loadedProviders ?? const [],
            isAnonymous: anonNow,
          );
        }
        if (_reloadPending) continue;
        return;
      }
    } finally {
      _flight = false;
    }
  }

  /// Sauvegarde via update_my_profile UNIQUEMENT (jamais optimiste).
  /// Échec => gate fermée, erreur localisée.
  Future<bool> save({
    required String displayName,
    required String avatarKey,
    required String locale,
  }) async {
    if (!isDisplayNameValid(displayName)) {
      state = state.copyWith(saveError: () => 'invalid-display-name');
      return false;
    }
    state = state.copyWith(saving: true, saveError: () => null);
    try {
      final saved = await _repo.saveProfile(
        displayName: displayName.trim(),
        avatarKey: avatarKey,
        locale: supportedLocaleOrFr(locale),
      );
      state = state.copyWith(saving: false, profile: () => saved);
      unawaitedReloadAvatars();
      return true;
    } catch (e) {
      state = state.copyWith(saving: false, saveError: () => _saveCodeOf(e));
      return false;
    }
  }

  Future<void> unawaitedReloadAvatars() async {
    state = state.copyWith(avatarsLoading: true);
    try {
      state = state.copyWith(avatars: await _repo.loadAvatars());
    } catch (_) {
    } finally {
      state = state.copyWith(avatarsLoading: false);
    }
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

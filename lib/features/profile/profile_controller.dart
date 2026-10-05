// Contrôleur profil/onboarding (Riverpod, sans code-gen).
// Autorité = RPC 0014 + Supabase Auth. Fakes injectables en tests.
// Un seul abonnement onAuthStateChange ; dispose sûr ; jamais de poll.
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
    );
  }
}

class ProfileController extends Notifier<ProfileUiState> {
  StreamSubscription<AuthEvent>? _sub;
  bool _started = false;
  bool _loading = false;

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
        (_) => reloadFromAuthEvent(),
        onError: (_) {},
      );
    } catch (_) {}
    await reloadAll();
  }

  /// Recharge profil + avatars + providers (après event auth / retry).
  Future<void> reloadAll() async {
    if (_loading) return;
    _loading = true;
    state = state.copyWith(profileLoading: true, profileError: () => null);
    try {
      final results = await Future.wait([
        _repo.loadProfile(),
        _repo.loadAvatars(),
        _auth.connectedProviders(),
      ]);
      state = state.copyWith(
        profileLoading: false,
        profile: () => results[0] as BrainProfile,
        avatars: results[1] as List<BrainAvatar>,
        providers: (results[2] as List<String>),
      );
    } catch (e) {
      state = state.copyWith(
        profileLoading: false,
        profileError: () => _codeOf(e),
      );
    } finally {
      _loading = false;
    }
  }

  /// Event auth (SIGNED_IN / USER_UPDATED / identité) : recharge
  /// autoritative. Jamais de poll, jamais de double abonnement.
  Future<void> reloadFromAuthEvent() async {
    _loading = false;
    state = state.copyWith(oauthPending: false);
    await reloadAll();
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
      state = state.copyWith(saving: false, saveError: () => _codeOf(e));
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

  String _codeOf(Object e) {
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
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileUiState>(ProfileController.new);

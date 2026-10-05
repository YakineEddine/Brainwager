// Passerelle auth sociale injectable (tests = fake, prod = Supabase).
// Browser-OAuth uniquement : aucun SDK natif, aucun secret côté Flutter.
// linkIdentity = sécurise l'invité courant (UUID préservé).
// signInWithOAuth = ouvre un compte existant (autre appareil).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';
import 'profile.dart';

/// Nature d'un changement auth. Seuls les changements d'identité/session
/// (sign-in, mise à jour user, sign-out) justifient une recharge profil.
/// Les rafraîchissements de token de routine sont ignorés.
/// L'initiale est déjà couverte par ensureStarted().
enum AuthEventKind {
  signedIn,
  userUpdated,
  signedOut,
  tokenRefreshed,
  initialSession,
  other,
}

/// Event auth minimal (neutre SDK, testable). Par défaut signé pertinent
/// (compat : `const AuthEvent()` == signedIn).
class AuthEvent {
  final AuthEventKind kind;
  const AuthEvent([this.kind = AuthEventKind.signedIn]);

  /// Vrai si le contrôleur doit recharger le profil autoritaire.
  bool get shouldReload =>
      kind == AuthEventKind.signedIn ||
      kind == AuthEventKind.userUpdated ||
      kind == AuthEventKind.signedOut ||
      kind == AuthEventKind.other;
}

/// Opérations auth nécessaires au profil/onboarding (interface fine).
abstract interface class SocialAuthGateway {
  String? get currentUserId;
  bool get isAnonymous;
  Map<String, dynamic>? get userMetadata;
  Stream<AuthEvent> get authStateChanges;
  Future<bool> linkGoogle();
  Future<bool> linkFacebook();
  Future<bool> signInGoogle();
  Future<bool> signInFacebook();
  Future<List<String>> connectedProviders();
}

AuthEventKind _kindOf(AuthChangeEvent event) {
  switch (event) {
    case AuthChangeEvent.signedIn:
      return AuthEventKind.signedIn;
    case AuthChangeEvent.userUpdated:
      return AuthEventKind.userUpdated;
    case AuthChangeEvent.signedOut:
      return AuthEventKind.signedOut;
    case AuthChangeEvent.tokenRefreshed:
      return AuthEventKind.tokenRefreshed;
    case AuthChangeEvent.initialSession:
      return AuthEventKind.initialSession;
    default:
      return AuthEventKind.other;
  }
}

class SupabaseSocialAuthGateway implements SocialAuthGateway {
  final SupabaseClient Function() _client;
  SupabaseSocialAuthGateway({SupabaseClient Function()? client})
    : _client = client ?? supa;

  User? get _user {
    try {
      return _client().auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  String? get currentUserId => _user?.id;

  @override
  bool get isAnonymous => _user?.isAnonymous ?? true;

  @override
  Map<String, dynamic>? get userMetadata => _user?.userMetadata;

  @override
  Stream<AuthEvent> get authStateChanges {
    try {
      return _client().auth.onAuthStateChange.map(
        (s) => AuthEvent(_kindOf(s.event)),
      );
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Future<bool> linkGoogle() => _launch(
    () => _client().auth.linkIdentity(
      OAuthProvider.google,
      redirectTo: brainwagerAuthCallback,
    ),
  );

  @override
  Future<bool> linkFacebook() => _launch(
    () => _client().auth.linkIdentity(
      OAuthProvider.facebook,
      redirectTo: brainwagerAuthCallback,
    ),
  );

  @override
  Future<bool> signInGoogle() => _launch(
    () => _client().auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: brainwagerAuthCallback,
    ),
  );

  @override
  Future<bool> signInFacebook() => _launch(
    () => _client().auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: brainwagerAuthCallback,
    ),
  );

  /// Lancement navigateur best-effort : false/échec => UI réutilisable,
  /// session invité intacte, jamais de texte brut vers l'UI.
  Future<bool> _launch(Future<bool> Function() call) async {
    try {
      return await call();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> connectedProviders() async {
    try {
      final identities = await _client().auth.getUserIdentities();
      return identities.map((i) => i.provider).toSet().toList();
    } catch (_) {
      return const [];
    }
  }
}

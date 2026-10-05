// Passerelle auth sociale injectable (tests = fake, prod = Supabase).
// Browser-OAuth uniquement : aucun SDK natif, aucun secret côté Flutter.
// linkIdentity = sécurise l'invité courant (UUID préservé).
// signInWithOAuth = ouvre un compte existant (autre appareil).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';
import 'profile.dart';

/// Event auth minimal (neutre SDK, testable) : tout changement de session
/// ou d'identité déclenche une recharge autoritative côté contrôleur.
class AuthEvent {
  const AuthEvent();
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
      return _client().auth.onAuthStateChange.map((_) => const AuthEvent());
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

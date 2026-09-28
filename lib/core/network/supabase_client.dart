// Config Supabase Phase 2B : URL + clé via --dart-define (jamais en dur).
// Lancement : flutter run --dart-define SUPABASE_URL=... --dart-define SUPABASE_PUBLISHABLE_KEY=...
// Note SDK supabase_flutter 2.17 : le paramètre s'appelle désormais publishableKey
// (l'ancienne anonKey du dashboard = la publishable key, même valeur).
// SUPABASE_ANON_KEY reste acceptée en repli (anciens scripts).
import 'package:supabase_flutter/supabase_flutter.dart';

class SupaConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Nom actuel en priorité, ancien nom en repli.
  static String get effectiveKey =>
      publishableKey.isNotEmpty ? publishableKey : anonKey;

  static bool get isConfigured => url.isNotEmpty && effectiveKey.isNotEmpty;
}

bool _ready = false;

/// Vrai uniquement après un initSupabase() réussi. Ne JAMAIS toucher à
/// Supabase.instance avant : l'assertion interne du SDK ne doit pas fuiter.
bool get isSupaReady => _ready;

/// Décision pure/testable : un sign-in anonyme est-il nécessaire ?
/// Non si le SDK a déjà restauré une session utilisable (restart/refresh :
/// on préserve l'identité anonyme existante au lieu d'en créer une autre).
bool needsAnonymousSignIn({required bool hasSession}) => !hasSession;

Future<void> initSupabase() async {
  if (!SupaConfig.isConfigured) {
    throw StateError(
      'Supabase non configuré : SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY '
      'manquants (--dart-define).',
    );
  }
  await Supabase.initialize(
    url: SupaConfig.url,
    publishableKey: SupaConfig.effectiveKey,
  );
  final session = Supabase.instance.client.auth.currentSession;
  if (needsAnonymousSignIn(hasSession: session != null)) {
    await Supabase.instance.client.auth.signInAnonymously();
  }
  _ready = true;
}

/// Accès client. Lève une erreur claire si l'init n'a pas réussi.
SupabaseClient supa() {
  if (!_ready) {
    throw StateError(
      'Supabase non initialisé : initSupabase() doit réussir avant tout accès.',
    );
  }
  return Supabase.instance.client;
}

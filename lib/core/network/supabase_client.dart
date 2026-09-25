// Config Supabase Phase 2 : URL + clé via --dart-define (jamais en dur).
// Lancement : flutter run --dart-define SUPABASE_URL=... --dart-define SUPABASE_ANON_KEY=...
// Note SDK supabase_flutter 2.17 : le paramètre s'appelle désormais publishableKey
// (l'ancienne anonKey du dashboard = la publishable key, même valeur).
import 'package:supabase_flutter/supabase_flutter.dart';

class SupaConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

Future<void> initSupabase() async {
  if (!SupaConfig.isConfigured) return; // Mode hors-ligne Phase 1 (UI seule).
  await Supabase.initialize(
    url: SupaConfig.url,
    publishableKey: SupaConfig.anonKey,
  );
  await Supabase.instance.client.auth.signInAnonymously();
}

SupabaseClient supa() => Supabase.instance.client;

// Bootstrap Phase 2 : Riverpod + thème + i18n + Supabase (anon).
// Lancement : --dart-define SUPABASE_URL=... --dart-define SUPABASE_ANON_KEY=...
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brainwager/app/router.dart';
import 'package:brainwager/app/theme.dart';
import 'package:brainwager/core/network/supabase_client.dart';
import 'package:brainwager/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initSupabase();
  } catch (_) {
    // Mode hors-ligne : l'UI reste navigable, les écrans jeu affichent l'erreur.
  }
  runApp(const ProviderScope(child: BrainwagerApp()));
}

class BrainwagerApp extends StatelessWidget {
  const BrainwagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Brainwager',
      theme: buildBrainTheme(),
      routerConfig: brainRouter,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr'), Locale('en')],
    );
  }
}

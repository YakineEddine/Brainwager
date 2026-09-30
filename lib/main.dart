// Bootstrap Phase 2B : Riverpod + thème + i18n + Supabase (anon).
// Lancement : --dart-define SUPABASE_URL=... --dart-define SUPABASE_PUBLISHABLE_KEY=...
// Un échec d'init affiche un écran d'erreur explicite : jamais de démarrage
// silencieux avec un client Supabase inutilisable.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brainwager/app/router.dart';
import 'package:brainwager/app/theme.dart';
import 'package:brainwager/core/network/supabase_client.dart';
import 'package:brainwager/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initError;
  try {
    await initSupabase();
  } catch (e) {
    initError = e;
  }
  runApp(ProviderScope(child: BrainwagerApp(initError: initError)));
}

class BrainwagerApp extends StatelessWidget {
  final Object? initError;
  const BrainwagerApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    if (initError != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Brainwager ne peut pas démarrer.'),
                  const SizedBox(height: 12),
                  Text('$initError'),
                ],
              ),
            ),
          ),
        ),
      );
    }
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
      supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
    );
  }
}

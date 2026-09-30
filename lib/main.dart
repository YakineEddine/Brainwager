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

  /// Forçage de locale optionnel (tests/screenshots) : null = locale device.
  final Locale? locale;
  const BrainwagerApp({super.key, this.initError, this.locale});

  @override
  Widget build(BuildContext context) {
    if (initError != null) {
      // Coquille localisée : même en échec d'init, l'arabe device donne
      // une UI RTL arabe (délégués + locales présents ici aussi).
      return MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr'),
          Locale('en'),
          Locale('ar'),
        ],
        home: Builder(builder: (context) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppLocalizations.of(context)!.bootstrapErrorTitle),
                    const SizedBox(height: 12),
                    Text('$initError'),
                  ],
                ),
              ),
            ),
          );
        }),
      );
    }
    return MaterialApp.router(
      title: 'Brainwager',
      locale: locale,
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

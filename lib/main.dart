// Bootstrap : Riverpod + thème + i18n + Supabase (anon) + deep links.
// Lancement : --dart-define SUPABASE_URL=... --dart-define SUPABASE_PUBLISHABLE_KEY=...
// Un échec d'init affiche un écran d'erreur explicite : jamais de démarrage
// silencieux avec un client Supabase inutilisable.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brainwager/app/router.dart';
import 'package:brainwager/app/theme.dart';
import 'package:brainwager/core/navigation/deep_link_service.dart';
import 'package:brainwager/core/network/supabase_client.dart';
import 'package:brainwager/features/profile/onboarding_gate.dart';
import 'package:brainwager/l10n/app_localizations.dart';

/// Instance deep links retenue pour toute la vie de l'app (un seul
/// abonnement, jamais recréée sur rebuild).
final deepLinkService = DeepLinkService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initError;
  try {
    await initSupabase();
  } catch (e) {
    initError = e;
  }
  runApp(ProviderScope(child: BrainwagerApp(initError: initError)));
  // Deep links custom scheme (instance unique retained, durée de vie app).
  // Seule source : uriLinkStream (inclut l'event initial, pas de double
  // via getInitialLink). Navigation via go_router global.
  unawaited(deepLinkService.start(brainRouter.go));
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
        supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
        home: Builder(
          builder: (context) {
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
          },
        ),
      );
    }
    return MaterialApp.router(
      title: 'Brainwager',
      locale: locale,
      theme: buildBrainTheme(),
      routerConfig: brainRouter,
      builder: (context, child) =>
          OnboardingGate(child: child ?? const SizedBox.shrink()),
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

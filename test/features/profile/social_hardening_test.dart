// Tests durcissement onboarding social (revue externe) : sélection visuelle
// immédiate, race account-switch, filtrage events, flash gate, vrai router,
// onboarding account-aware, sémantique localisée, mapping erreurs.
// Fakes uniquement, jamais de Supabase réel.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:brainwager/features/lobby/lobby_screens.dart';
import 'package:brainwager/features/profile/auth_gateway.dart';
import 'package:brainwager/features/profile/avatar_view.dart';
import 'package:brainwager/features/profile/onboarding_gate.dart';
import 'package:brainwager/features/profile/onboarding_screen.dart';
import 'package:brainwager/features/profile/profile.dart';
import 'package:brainwager/features/profile/profile_controller.dart';
import 'package:brainwager/features/profile/profile_errors.dart';
import 'package:brainwager/features/profile/profile_repository.dart';
import 'package:brainwager/features/profile/profile_screen.dart';
import 'package:brainwager/l10n/app_localizations.dart';
import 'package:brainwager/shared/widgets/brain_buttons.dart';

class FakeAuth2 implements SocialAuthGateway {
  String? userId = 'uuid-A';
  bool anon = true;
  Map<String, dynamic>? metadata;
  List<String> providers = const [];
  final _events = StreamController<AuthEvent>.broadcast();
  int linkGoogleCalls = 0;

  void emit(AuthEvent event) => _events.add(event);

  @override
  String? get currentUserId => userId;

  @override
  bool get isAnonymous => anon;

  @override
  Map<String, dynamic>? get userMetadata => metadata;

  @override
  Stream<AuthEvent> get authStateChanges => _events.stream;

  @override
  Future<bool> linkGoogle() async {
    linkGoogleCalls++;
    return true;
  }

  @override
  Future<bool> linkFacebook() async => true;

  @override
  Future<bool> signInGoogle() async => true;

  @override
  Future<bool> signInFacebook() async => true;

  @override
  Future<List<String>> connectedProviders() async => providers;
}

/// Repo à vols contrôlés : 1er loadProfile bloqué, suivants immédiats.
class BlockingRepo extends ProfileRepository {
  BlockingRepo() : super(client: _throwingClient);

  static Never _throwingClient() {
    throw StateError('no-supabase-in-tests');
  }

  Completer<BrainProfile> profileGate = Completer<BrainProfile>();
  Completer<BrainProfile>? secondGate;
  BrainProfile secondProfile = const BrainProfile(
    id: 'uuid-B',
    displayName: 'Bee',
    locale: 'fr',
    avatarKey: 'rocket',
    onboardingComplete: false,
  );
  List<BrainAvatar> avatarsToReturn = const [];
  int loadProfileCalls = 0;
  bool throwUnknownOnLoad = false;

  @override
  Future<BrainProfile> loadProfile() async {
    loadProfileCalls++;
    if (throwUnknownOnLoad) throw Exception('boom-socket');
    if (loadProfileCalls == 1) return profileGate.future;
    if (secondGate != null) return secondGate!.future;
    return secondProfile;
  }

  @override
  Future<List<BrainAvatar>> loadAvatars() async => avatarsToReturn;
}

/// Repo simple non-bloquant (même UUID / refresh / erreurs).
class SimpleRepo extends ProfileRepository {
  SimpleRepo(this.profileToReturn) : super(client: _throwingClient);

  static Never _throwingClient() {
    throw StateError('no-supabase-in-tests');
  }

  BrainProfile profileToReturn;
  List<BrainAvatar> avatarsToReturn = const [];
  bool throwUnknownOnSave = false;
  int loadProfileCalls = 0;
  int saveCalls = 0;

  /// Barrières déterministes pour les races : save bloqué puis résultat
  /// périmé imposé, prochain loadAvatars bloqué puis avatars périmés.
  Completer<void>? saveGate;
  BrainProfile? saveStaleResult;
  bool blockNextAvatars = false;
  Completer<void>? avatarGate;
  List<BrainAvatar>? staleAvatars;
  int avatarCalls = 0;

  @override
  Future<BrainProfile> loadProfile() async {
    loadProfileCalls++;
    return profileToReturn;
  }

  @override
  Future<List<BrainAvatar>> loadAvatars() async {
    avatarCalls++;
    if (blockNextAvatars) {
      blockNextAvatars = false;
      if (avatarGate != null) await avatarGate!.future;
      if (staleAvatars != null) return staleAvatars!;
    }
    return avatarsToReturn;
  }

  @override
  Future<BrainProfile> saveProfile({
    required String displayName,
    required String avatarKey,
    required String locale,
  }) async {
    saveCalls++;
    if (saveGate != null) await saveGate!.future;
    if (throwUnknownOnSave) throw Exception('boom-disk');
    if (saveStaleResult != null) return saveStaleResult!;
    return BrainProfile(
      id: profileToReturn.id,
      displayName: displayName,
      locale: locale,
      avatarKey: avatarKey,
      onboardingComplete: true,
    );
  }
}

const _raceAvatars = [
  BrainAvatar(
    avatarKey: 'brain',
    sortOrder: 10,
    isFree: true,
    unlocked: true,
    selected: true,
  ),
  BrainAvatar(
    avatarKey: 'rocket',
    sortOrder: 20,
    isFree: true,
    unlocked: true,
    selected: false,
  ),
  BrainAvatar(
    avatarKey: 'trophy',
    sortOrder: 60,
    isFree: false,
    unlocked: false,
    selected: false,
  ),
];

Widget _localizedApp(Widget home, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
    home: home,
  );
}

/// Harnais sélection : état local seul, aucun RPC/save.
class _SelectionHarness extends StatefulWidget {
  const _SelectionHarness();
  @override
  State<_SelectionHarness> createState() => _SelectionHarnessState();
}

class _SelectionHarnessState extends State<_SelectionHarness> {
  String? sel = 'brain';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: BrainAvatarChooser(
        avatars: _raceAvatars,
        selectedKey: sel,
        semanticLabelFor: (k) => avatarNameFor(k, l10n),
        onSelect: (k) => setState(() => sel = k),
      ),
    );
  }
}

/// Sélection effective : propriété Semantics de la vue + pastille check.
/// (Évite l'API interne des flags sémantiques du SDK.)
bool _isSelected(WidgetTester tester, String avatarKey) {
  final view = find.byKey(ValueKey('avatar-$avatarKey'));
  final semantics = tester
      .widgetList<Semantics>(
        find.descendant(of: view, matching: find.byType(Semantics)),
      )
      .first;
  final check = find.descendant(of: view, matching: find.byIcon(Icons.check));
  if (semantics.properties.selected == true) {
    return check.evaluate().isNotEmpty;
  }
  return false;
}

void main() {
  testWidgets('A-D) sélection visuelle immédiate sans serveur', (tester) async {
    await tester.pumpWidget(_localizedApp(const _SelectionHarness()));
    await tester.pumpAndSettle();
    // A. brain sélectionné au départ.
    expect(_isSelected(tester, 'brain'), isTrue);
    expect(_isSelected(tester, 'rocket'), isFalse);
    expect(find.byIcon(Icons.check), findsOneWidget);
    // B. tap rocket.
    await tester.tap(find.byIcon(Icons.rocket_launch));
    await tester.pump();
    // C. rocket aussitôt sélectionné (anneau + check).
    expect(_isSelected(tester, 'rocket'), isTrue);
    expect(find.byIcon(Icons.check), findsOneWidget);
    // D. brain aussitôt déselectionné.
    expect(_isSelected(tester, 'brain'), isFalse);
    // E. aucun save/RPC n'existe dans ce chemin (harnais sans contrôleur).
  });

  testWidgets('F) avatar verrouillé toujours bloqué', (tester) async {
    await tester.pumpWidget(_localizedApp(const _SelectionHarness()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.rocket_launch));
    await tester.pump();
    expect(_isSelected(tester, 'rocket'), isTrue);
    await tester.tap(find.byIcon(Icons.emoji_events));
    await tester.pump();
    expect(_isSelected(tester, 'rocket'), isTrue);
    expect(_isSelected(tester, 'trophy'), isFalse);
  });

  test('account-switch : le load périmé A ne s\u2019installe jamais', () async {
    final auth = FakeAuth2();
    final repo = BlockingRepo()..secondGate = Completer<BrainProfile>();
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(profileControllerProvider.notifier);
    // Vol invité A démarré et BLOQUÉ.
    final started = notifier.ensureStarted();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.loadProfileCalls, 1);
    // Sign-in compte existant B pendant le vol.
    auth.userId = 'uuid-B';
    auth.anon = false;
    auth.emit(const AuthEvent(AuthEventKind.signedIn));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // Fail-closed : l'ancien invité est effacé aussitôt, gate fermée.
    expect(container.read(profileControllerProvider).profile, isNull);
    expect(container.read(profileControllerProvider).gateOpen, isFalse);
    // L'ancien résultat A arrive tard : il doit être jeté.
    repo.profileGate.complete(
      const BrainProfile(
        id: 'uuid-A',
        displayName: 'Aye',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // Un seul suivi autoritaire pour B, jamais de profil A installé.
    expect(repo.loadProfileCalls, 2);
    expect(
      container.read(profileControllerProvider).profile?.id,
      isNot('uuid-A'),
    );
    expect(container.read(profileControllerProvider).profile, isNull);
    // Le suivi B aboutit.
    repo.secondGate!.complete(repo.secondProfile);
    await started;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.loadProfileCalls, 2);
    expect(container.read(profileControllerProvider).profile?.id, 'uuid-B');
    expect(container.read(profileControllerProvider).gateOpen, isFalse);
  });

  test('même UUID (link) : reload sans clear d\u2019identité', () async {
    final auth = FakeAuth2();
    final repo = SimpleRepo(
      const BrainProfile(
        id: 'uuid-A',
        displayName: 'Aye',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileControllerProvider.notifier).ensureStarted();
    expect(container.read(profileControllerProvider).profile?.id, 'uuid-A');
    // Link : UUID inchangé, event userUpdated => reload, pas de clear.
    auth.emit(const AuthEvent(AuthEventKind.userUpdated));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(repo.loadProfileCalls, 2);
    expect(container.read(profileControllerProvider).profile?.id, 'uuid-A');
  });

  test('token refresh : aucun reload inutile', () async {
    final auth = FakeAuth2();
    final repo = SimpleRepo(
      const BrainProfile(
        id: 'uuid-A',
        displayName: 'Aye',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileControllerProvider.notifier).ensureStarted();
    expect(repo.loadProfileCalls, 1);
    auth.emit(const AuthEvent(AuthEventKind.tokenRefreshed));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(repo.loadProfileCalls, 1);
    auth.emit(const AuthEvent(AuthEventKind.initialSession));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(repo.loadProfileCalls, 1);
  });

  testWidgets('gate : première frame sans navbar ni contenu', (tester) async {
    final auth = FakeAuth2();
    final repo = BlockingRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          socialAuthGatewayProvider.overrideWithValue(auth),
        ],
        child: _localizedApp(
          OnboardingGate(
            child: Scaffold(
              body: Text('CHILD-NEVER-EARLY'),
              bottomNavigationBar: NavigationBar(
                selectedIndex: 0,
                destinations: [
                  NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                  NavigationDestination(
                    icon: Icon(Icons.style),
                    label: 'Packs',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // Une seule frame, load toujours bloqué : compact uniquement.
    await tester.pump();
    expect(find.text('CHILD-NEVER-EARLY'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(OnboardingScreen), findsNothing);
    repo.profileGate.complete(
      const BrainProfile(
        id: 'uuid-A',
        displayName: '',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('vrai router : /join survit à l\u2019onboarding', (tester) async {
    final auth = FakeAuth2();
    final repo = SimpleRepo(
      const BrainProfile(
        id: 'uuid-A',
        displayName: '',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileControllerProvider.notifier).ensureStarted();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('HOME-PAGE')),
        GoRoute(
          path: '/join',
          builder: (_, s) =>
              JoinScreen(initialCode: s.uri.queryParameters['code']),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) =>
              OnboardingGate(child: child ?? const SizedBox.shrink()),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Gate fermée, puis deep-link pendant l'onboarding.
    router.go('/join?code=ABCDE');
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(JoinScreen), findsNothing);
    // Succès autoritaire : le vrai JoinScreen apparaît, code intact.
    repo.profileToReturn = const BrainProfile(
      id: 'uuid-A',
      displayName: 'Zed',
      locale: 'fr',
      avatarKey: 'brain',
      onboardingComplete: true,
    );
    await container.read(profileControllerProvider.notifier).reloadAll();
    await tester.pumpAndSettle();
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'ABCDE',
    );
  });

  testWidgets('onboarding lié : plus de CTA invité ni contrôles guest', (
    tester,
  ) async {
    final auth = FakeAuth2()
      ..anon = false
      ..providers = ['google'];
    final repo = SimpleRepo(
      const BrainProfile(
        id: 'uuid-A',
        displayName: '',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      ),
    )..avatarsToReturn = _raceAvatars;
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileControllerProvider.notifier).ensureStarted();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _localizedApp(const OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final l10n =
        // ignore: use_build_context_synchronously
        AppLocalizations.of(tester.element(find.byType(OnboardingScreen)))!;
    expect(find.text(l10n.continueGuest), findsNothing);
    expect(find.text(l10n.saveProfile), findsOneWidget);
    expect(find.text(l10n.secureAccount), findsNothing);
    expect(find.text(l10n.alreadyHaveAccount), findsNothing);
    expect(find.text(l10n.connectedWith('google')), findsOneWidget);
  });

  testWidgets('onboarding invité : CTA et contrôles présents', (tester) async {
    final auth = FakeAuth2();
    final repo = SimpleRepo(
      const BrainProfile(
        id: 'uuid-A',
        displayName: '',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      ),
    )..avatarsToReturn = _raceAvatars;
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileControllerProvider.notifier).ensureStarted();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _localizedApp(const OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final l10n =
        // ignore: use_build_context_synchronously
        AppLocalizations.of(tester.element(find.byType(OnboardingScreen)))!;
    expect(find.text(l10n.continueGuest), findsOneWidget);
    expect(find.text(l10n.secureAccount), findsOneWidget);
    expect(find.text(l10n.alreadyHaveAccount), findsOneWidget);
  });

  test('sémantique avatar localisée EN/FR/AR + repli générique', () async {
    final expectations = {
      const Locale('en'): {
        'brain': 'Brain',
        'rocket': 'Rocket',
        'star': 'Star',
        'bolt': 'Lightning',
        'planet': 'Planet',
        'trophy': 'Trophy',
        'football': 'Football',
        'basketball': 'Basketball',
      },
      const Locale('fr'): {
        'brain': 'Cerveau',
        'rocket': 'Fusée',
        'star': 'Étoile',
        'bolt': 'Éclair',
        'planet': 'Planète',
        'trophy': 'Trophée',
        'football': 'Football',
        'basketball': 'Basket-ball',
      },
      const Locale('ar'): {
        'brain': 'العقل',
        'rocket': 'الصاروخ',
        'star': 'النجمة',
        'bolt': 'البرق',
        'planet': 'الكوكب',
        'trophy': 'الكأس',
        'football': 'كرة القدم',
        'basketball': 'كرة السلة',
      },
    };
    for (final entry in expectations.entries) {
      final l10n = await AppLocalizations.delegate.load(entry.key);
      for (final kv in entry.value.entries) {
        expect(
          avatarNameFor(kv.key, l10n),
          kv.value,
          reason: '${entry.key} ${kv.key}',
        );
      }
      // Clé future inconnue => générique localisé, jamais la clé brute.
      expect(avatarNameFor('dragon', l10n), l10n.profileAvatar);
    }
  });

  testWidgets('sémantique chooser : labels localisés, pas de clés brutes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(const _SelectionHarness(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('الصاروخ'), findsOneWidget);
    expect(find.bySemanticsLabel('rocket'), findsNothing);
  });

  test('erreurs load vs save séparées et localisées', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final fr = await AppLocalizations.delegate.load(const Locale('fr'));
    final ar = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(friendlyProfileError('profile-load-error', en), en.profileLoadError);
    expect(friendlyProfileError('profile-save-error', en), en.profileSaveError);
    expect(friendlyProfileError('profile-load-error', fr), fr.profileLoadError);
    expect(friendlyProfileError('profile-save-error', ar), ar.profileSaveError);
  });

  test('reload inconnu => load-error, save inconnu => save-error', () async {
    final auth = FakeAuth2();
    final repo = BlockingRepo()..throwUnknownOnLoad = true;
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileControllerProvider.notifier).reloadAll();
    expect(
      container.read(profileControllerProvider).profileError,
      'profile-load-error',
    );
    final repo2 = SimpleRepo(
      const BrainProfile(
        id: 'uuid-A',
        displayName: '',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      ),
    )..throwUnknownOnSave = true;
    final container2 = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo2),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container2.dispose);
    final ok = await container2
        .read(profileControllerProvider.notifier)
        .save(displayName: 'Zed', avatarKey: 'brain', locale: 'fr');
    expect(ok, isFalse);
    expect(
      container2.read(profileControllerProvider).saveError,
      'profile-save-error',
    );
    expect(repo2.saveCalls, 1);
  });

  test('A-C) signedOut fail-closed sans RPC, puis signedIn B', () async {
    final auth = FakeAuth2();
    final repo = SimpleRepo(
      const BrainProfile(
        id: 'uuid-A',
        displayName: 'Aye',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(profileControllerProvider.notifier);
    await notifier.ensureStarted();
    expect(container.read(profileControllerProvider).profile?.id, 'uuid-A');
    expect(container.read(profileControllerProvider).gateOpen, isTrue);
    // Transition OAuth en cours : pending visible, pas un succès.
    await notifier.secureWithGoogle();
    expect(container.read(profileControllerProvider).oauthPending, isTrue);
    final callsBefore = repo.loadProfileCalls;
    // A. signedOut => clear immédiat, gate fermée, pas un succès.
    auth.userId = null;
    auth.emit(const AuthEvent(AuthEventKind.signedOut));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final cleared = container.read(profileControllerProvider);
    expect(cleared.profile, isNull);
    expect(cleared.avatars, isEmpty);
    expect(cleared.providers, isEmpty);
    expect(cleared.profileError, isNull);
    expect(cleared.saveError, isNull);
    expect(cleared.oauthPending, isFalse);
    expect(cleared.gateOpen, isFalse);
    // B. aucun RPC profil sans utilisateur authentifié.
    expect(repo.loadProfileCalls, callsBefore);
    // C. signedIn ultérieur => reload autoritaire du nouveau compte.
    auth.userId = 'uuid-B';
    auth.anon = false;
    repo.profileToReturn = const BrainProfile(
      id: 'uuid-B',
      displayName: 'Bee',
      locale: 'fr',
      avatarKey: 'rocket',
      onboardingComplete: false,
    );
    auth.emit(const AuthEvent(AuthEventKind.signedIn));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(profileControllerProvider).profile?.id, 'uuid-B');
    expect(container.read(profileControllerProvider).gateOpen, isFalse);
  });

  test('D/E) profil ID faux permanent : fini, jamais installé', () async {
    final auth = FakeAuth2()..userId = 'real-user';
    final repo = SimpleRepo(
      const BrainProfile(
        id: 'wrong-user',
        displayName: 'Intruder',
        locale: 'fr',
        avatarKey: 'brain',
        // Même "terminé" : la gate ne doit jamais s'ouvrir.
        onboardingComplete: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    // Termine (aucune boucle) : un seul vol, puis fail-closed.
    await container.read(profileControllerProvider.notifier).reloadAll();
    expect(repo.loadProfileCalls, 1);
    final s = container.read(profileControllerProvider);
    expect(s.profile, isNull);
    expect(s.avatars, isEmpty);
    expect(s.providers, isEmpty);
    expect(s.profileError, 'profile-load-error');
    expect(s.gateOpen, isFalse);
  });

  test('F) save A périmé jeté après switch vers B', () async {
    final auth = FakeAuth2();
    final repo =
        SimpleRepo(
            const BrainProfile(
              id: 'uuid-A',
              displayName: 'Aye',
              locale: 'fr',
              avatarKey: 'brain',
              onboardingComplete: false,
            ),
          )
          ..saveGate = Completer<void>()
          ..saveStaleResult = const BrainProfile(
            id: 'uuid-A',
            displayName: 'Stale-A',
            locale: 'fr',
            avatarKey: 'brain',
            onboardingComplete: true,
          );
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(profileControllerProvider.notifier);
    await notifier.ensureStarted();
    // Save A démarré et BLOQUÉ.
    final saveFuture = notifier.save(
      displayName: 'Aye',
      avatarKey: 'brain',
      locale: 'fr',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // Switch vers B + event pendant le save.
    auth.userId = 'uuid-B';
    auth.anon = false;
    repo.profileToReturn = const BrainProfile(
      id: 'uuid-B',
      displayName: 'Bee',
      locale: 'fr',
      avatarKey: 'rocket',
      onboardingComplete: false,
    );
    auth.emit(const AuthEvent(AuthEventKind.signedIn));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // Ancien invité effacé (null) ou déjà rechargé en B : jamais A.
    expect(
      container.read(profileControllerProvider).profile?.id,
      isNot('uuid-A'),
    );
    // Le résultat A arrive tard : jeté, jamais installé sous B.
    repo.saveGate!.complete();
    final saved = await saveFuture;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(saved, isFalse);
    // Pas d'erreur parasite du vieux compte pour le nouveau.
    expect(container.read(profileControllerProvider).saveError, isNull);
    expect(container.read(profileControllerProvider).profile?.id, 'uuid-B');
    expect(
      container.read(profileControllerProvider).profile?.displayName,
      isNot('Stale-A'),
    );
  });

  test('G) refresh avatars A périmé jeté après switch vers B', () async {
    const avatarsA = [
      BrainAvatar(
        avatarKey: 'brain',
        sortOrder: 10,
        isFree: true,
        unlocked: true,
        selected: true,
      ),
    ];
    const avatarsB = [
      BrainAvatar(
        avatarKey: 'rocket',
        sortOrder: 20,
        isFree: true,
        unlocked: true,
        selected: true,
      ),
    ];
    final auth = FakeAuth2();
    final repo = SimpleRepo(
      const BrainProfile(
        id: 'uuid-A',
        displayName: 'Aye',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      ),
    )..avatarsToReturn = avatarsA;
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(profileControllerProvider.notifier);
    await notifier.ensureStarted();
    // Prochain refresh avatars bloqué (retournera les avatars A périmés).
    repo
      ..blockNextAvatars = true
      ..avatarGate = Completer<void>()
      ..staleAvatars = avatarsA;
    // Save sous A : succès, refresh avatars démarré et BLOQUÉ.
    final saveFuture = notifier.save(
      displayName: 'Aye',
      avatarKey: 'brain',
      locale: 'fr',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // Switch vers B : reload autoritaire B (avatars B immédiats).
    auth.userId = 'uuid-B';
    auth.anon = false;
    repo.profileToReturn = const BrainProfile(
      id: 'uuid-B',
      displayName: 'Bee',
      locale: 'fr',
      avatarKey: 'rocket',
      onboardingComplete: false,
    );
    repo.avatarsToReturn = avatarsB;
    auth.emit(const AuthEvent(AuthEventKind.signedIn));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      container.read(profileControllerProvider).avatars.map((a) => a.avatarKey),
      ['rocket'],
    );
    // Le refresh A arrive tard : jeté, jamais installé sous B.
    repo.avatarGate!.complete();
    expect(await saveFuture, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      container.read(profileControllerProvider).avatars.map((a) => a.avatarKey),
      ['rocket'],
    );
    expect(container.read(profileControllerProvider).profile?.id, 'uuid-B');
  });

  testWidgets('H/I) vue directe sans label : sémantique sûre', (tester) async {
    const rocket = BrainAvatar(
      avatarKey: 'rocket',
      sortOrder: 20,
      isFree: true,
      unlocked: true,
      selected: false,
    );
    await tester.pumpWidget(
      _localizedApp(
        const Scaffold(body: BrainAvatarView(avatar: rocket)),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Rocket'), findsOneWidget);
    expect(find.bySemanticsLabel('rocket'), findsNothing);
    await tester.pumpWidget(
      _localizedApp(
        const Scaffold(body: BrainAvatarView(avatar: rocket)),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('الصاروخ'), findsOneWidget);
    expect(find.bySemanticsLabel('rocket'), findsNothing);
  });

  testWidgets('J) annuler restaure les valeurs serveur', (tester) async {
    final auth = FakeAuth2();
    final repo = SimpleRepo(
      const BrainProfile(
        id: 'uuid-A',
        displayName: 'Zed',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: true,
      ),
    )..avatarsToReturn = _raceAvatars;
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileControllerProvider.notifier).ensureStarted();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _localizedApp(const ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tapVisible(Finder finder) async {
      final target = finder.first;
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    // Édite : pseudo + avatar modifiés, sans sauver.
    await tapVisible(find.widgetWithText(BrainGhostButton, 'Edit profile'));
    await tapVisible(find.byIcon(Icons.rocket_launch));
    await tester.enterText(find.byType(TextField), 'Custom');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Custom',
    );
    // Annule : retour strict aux valeurs serveur, aucun RPC.
    final saveCallsBefore = repo.saveCalls;
    await tapVisible(find.widgetWithText(BrainGhostButton, 'Back'));
    expect(repo.saveCalls, saveCallsBefore);
    // Ré-édite : pseudo serveur + avatar serveur restaurés.
    await tapVisible(find.widgetWithText(BrainGhostButton, 'Edit profile'));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Zed',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('avatar-brain')),
        matching: find.byIcon(Icons.check),
      ),
      // Carte d'affichage + chooser : cerveau sélectionné partout.
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('avatar-rocket')),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
  });

  test('K) save en erreur sous autre identité : jetée sans trace', () async {
    final auth = FakeAuth2();
    final repo = SimpleRepo(
      const BrainProfile(
        id: 'uuid-A',
        displayName: 'Aye',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      ),
    )..saveGate = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(profileControllerProvider.notifier);
    await notifier.ensureStarted();
    final saveFuture = notifier.save(
      displayName: 'Aye',
      avatarKey: 'brain',
      locale: 'fr',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // Switch vers B, puis le save A échoue : erreur jetée aussi.
    auth.userId = 'uuid-B';
    auth.anon = false;
    repo.profileToReturn = const BrainProfile(
      id: 'uuid-B',
      displayName: 'Bee',
      locale: 'fr',
      avatarKey: 'rocket',
      onboardingComplete: false,
    );
    repo.throwUnknownOnSave = true;
    auth.emit(const AuthEvent(AuthEventKind.signedIn));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    repo.saveGate!.complete();
    final saved = await saveFuture;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(saved, isFalse);
    expect(container.read(profileControllerProvider).saveError, isNull);
    expect(container.read(profileControllerProvider).profile?.id, 'uuid-B');
  });

  test('L) double retry en vol : un seul suivi coalescé', () async {
    final auth = FakeAuth2();
    final repo = BlockingRepo()
      ..secondGate = Completer<BrainProfile>()
      ..secondProfile = const BrainProfile(
        id: 'uuid-A',
        displayName: 'Aye-2',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      );
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(profileControllerProvider.notifier);
    final started = notifier.ensureStarted();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.loadProfileCalls, 1);
    // Deux retries pendant le vol : un seul suivi, pas deux.
    await notifier.reloadAll();
    await notifier.reloadAll();
    repo.profileGate.complete(
      const BrainProfile(
        id: 'uuid-A',
        displayName: 'Aye',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.loadProfileCalls, 2);
    repo.secondGate!.complete(repo.secondProfile);
    await started;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.loadProfileCalls, 2);
    expect(
      container.read(profileControllerProvider).profile?.displayName,
      'Aye-2',
    );
  });

  testWidgets('M) gate après sign-out : fermée, sans fuite', (tester) async {
    final auth = FakeAuth2()
      ..anon = false
      ..providers = ['google'];
    final repo = SimpleRepo(
      const BrainProfile(
        id: 'uuid-A',
        displayName: 'Aye',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileControllerProvider.notifier).ensureStarted();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
          home: const OnboardingGate(child: Text('CHILD-AFTER-SIGNOUT')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CHILD-AFTER-SIGNOUT'), findsOneWidget);
    auth.userId = null;
    auth.emit(const AuthEvent(AuthEventKind.signedOut));
    // Loading compact (spinner infini) : pompes bornées, pas de settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('CHILD-AFTER-SIGNOUT'), findsNothing);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('N) chooser sans override : sûr par défaut', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        Scaffold(
          body: BrainAvatarChooser(avatars: _raceAvatars, onSelect: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Rocket'), findsOneWidget);
    expect(find.bySemanticsLabel('rocket'), findsNothing);
  });

  test('O) backend corrompu après installation : effacé, erreur', () async {
    final auth = FakeAuth2();
    final repo = SimpleRepo(
      const BrainProfile(
        id: 'uuid-A',
        displayName: 'Aye',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(profileControllerProvider.notifier);
    await notifier.ensureStarted();
    expect(container.read(profileControllerProvider).gateOpen, isTrue);
    // Le backend ment ensuite : profil d'un autre id => fail-closed.
    repo.profileToReturn = const BrainProfile(
      id: 'wrong-user',
      displayName: 'Intruder',
      locale: 'fr',
      avatarKey: 'brain',
      onboardingComplete: true,
    );
    auth.emit(const AuthEvent(AuthEventKind.userUpdated));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final s = container.read(profileControllerProvider);
    expect(s.profile, isNull);
    expect(s.avatars, isEmpty);
    expect(s.profileError, 'profile-load-error');
    expect(s.gateOpen, isFalse);
  });
}

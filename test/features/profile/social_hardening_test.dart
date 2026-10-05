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
import 'package:brainwager/l10n/app_localizations.dart';

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

  @override
  Future<BrainProfile> loadProfile() async {
    loadProfileCalls++;
    return profileToReturn;
  }

  @override
  Future<List<BrainAvatar>> loadAvatars() async => avatarsToReturn;

  @override
  Future<BrainProfile> saveProfile({
    required String displayName,
    required String avatarKey,
    required String locale,
  }) async {
    saveCalls++;
    if (throwUnknownOnSave) throw Exception('boom-disk');
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
}

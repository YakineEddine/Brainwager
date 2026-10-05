// Tests social/auth/avatar/onboarding (fakes, jamais de Supabase réel).
// UUID anon préservé, link vs sign-in, gate, prefill, RTL, manifest.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/core/navigation/deep_link_parser.dart';
import 'package:brainwager/features/lobby/lobby_screens.dart';
import 'package:brainwager/features/packs/pack_providers.dart';
import 'package:brainwager/features/profile/auth_gateway.dart';
import 'package:brainwager/features/profile/avatar_view.dart';
import 'package:brainwager/features/profile/onboarding_gate.dart';
import 'package:brainwager/features/profile/onboarding_screen.dart';
import 'package:brainwager/features/profile/profile.dart';
import 'package:brainwager/features/profile/profile_controller.dart';
import 'package:brainwager/features/profile/profile_repository.dart';
import 'package:brainwager/l10n/app_localizations.dart';

class FakeAuth implements SocialAuthGateway {
  String? userId = 'uuid-1';
  bool anon = true;
  Map<String, dynamic>? metadata;
  List<String> providers = const [];
  int linkGoogleCalls = 0;
  int linkFacebookCalls = 0;
  int signInGoogleCalls = 0;
  int signInFacebookCalls = 0;
  bool launchResult = true;
  final _events = StreamController<AuthEvent>.broadcast();

  void emitAuthEvent() => _events.add(const AuthEvent());

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
    return launchResult;
  }

  @override
  Future<bool> linkFacebook() async {
    linkFacebookCalls++;
    return launchResult;
  }

  @override
  Future<bool> signInGoogle() async {
    signInGoogleCalls++;
    return launchResult;
  }

  @override
  Future<bool> signInFacebook() async {
    signInFacebookCalls++;
    return launchResult;
  }

  @override
  Future<List<String>> connectedProviders() async => providers;
}

class FakeRepo extends ProfileRepository {
  BrainProfile profileToReturn = const BrainProfile(
    id: 'uuid-1',
    displayName: '',
    locale: 'fr',
    avatarKey: 'brain',
    onboardingComplete: false,
  );
  List<BrainAvatar> avatarsToReturn = const [];
  Map<String, String>? savedParams;
  bool throwOnSave = false;
  bool throwOnLoad = false;
  int saveCalls = 0;

  FakeRepo() : super(client: _throwingClient);

  static Never _throwingClient() {
    throw StateError('no-supabase-in-tests');
  }

  @override
  Future<BrainProfile> loadProfile() async {
    if (throwOnLoad) throw Exception('profile-load-error');
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
    savedParams = {
      'p_display_name': displayName,
      'p_avatar_key': avatarKey,
      'p_locale': locale,
    };
    if (throwOnSave) throw Exception('profile-save-error');
    return BrainProfile(
      id: profileToReturn.id,
      displayName: displayName,
      locale: locale,
      avatarKey: avatarKey,
      onboardingComplete: true,
    );
  }
}

const _avatars = [
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

ProviderContainer _container(FakeAuth auth, FakeRepo repo) {
  return ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
      socialAuthGatewayProvider.overrideWithValue(auth),
    ],
  );
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) {
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

void main() {
  test('A) link préserve l\u2019UUID anon existant', () async {
    final auth = FakeAuth();
    final repo = FakeRepo();
    final c = _container(auth, repo);
    addTearDown(c.dispose);
    await c.read(profileControllerProvider.notifier).secureWithGoogle();
    expect(auth.linkGoogleCalls, 1);
    expect(auth.signInGoogleCalls, 0);
    expect(auth.currentUserId, 'uuid-1');
  });

  test('B/C) secure Google/Facebook appellent linkIdentity', () async {
    final auth = FakeAuth();
    final repo = FakeRepo();
    final c = _container(auth, repo);
    addTearDown(c.dispose);
    final notifier = c.read(profileControllerProvider.notifier);
    await notifier.secureWithGoogle();
    await notifier.secureWithFacebook();
    expect(auth.linkGoogleCalls, 1);
    expect(auth.linkFacebookCalls, 1);
    expect(auth.signInGoogleCalls, 0);
    expect(auth.signInFacebookCalls, 0);
  });

  test('D/E) compte existant appelle signInWithOAuth', () async {
    final auth = FakeAuth();
    final repo = FakeRepo();
    final c = _container(auth, repo);
    addTearDown(c.dispose);
    final notifier = c.read(profileControllerProvider.notifier);
    await notifier.signInExistingGoogle();
    await notifier.signInExistingFacebook();
    expect(auth.signInGoogleCalls, 1);
    expect(auth.signInFacebookCalls, 1);
    expect(auth.linkGoogleCalls, 0);
    expect(auth.linkFacebookCalls, 0);
  });

  test('F) callback OAuth exact', () {
    expect(brainwagerAuthCallback, 'brainwager://auth-callback');
  });

  test('G) ouverture navigateur seule ne complète rien', () async {
    final auth = FakeAuth();
    final repo = FakeRepo();
    final c = _container(auth, repo);
    addTearDown(c.dispose);
    final notifier = c.read(profileControllerProvider.notifier);
    await notifier.secureWithGoogle();
    expect(c.read(profileControllerProvider).profile, isNull);
    expect(c.read(profileControllerProvider).gateOpen, isFalse);
  });

  test('H) event auth recharge le profil autoritaire', () async {
    final auth = FakeAuth();
    final repo = FakeRepo()
      ..profileToReturn = const BrainProfile(
        id: 'uuid-1',
        displayName: 'Zed',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      );
    final c = _container(auth, repo);
    addTearDown(c.dispose);
    final notifier = c.read(profileControllerProvider.notifier);
    await notifier.ensureStarted();
    auth.emitAuthEvent();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(profileControllerProvider).profile?.displayName, 'Zed');
  });

  test('I) continuer invité ne fait aucun OAuth', () async {
    final auth = FakeAuth();
    final repo = FakeRepo();
    final c = _container(auth, repo);
    addTearDown(c.dispose);
    final ok = await c
        .read(profileControllerProvider.notifier)
        .save(displayName: 'Zed', avatarKey: 'brain', locale: 'fr');
    expect(ok, isTrue);
    expect(auth.linkGoogleCalls, 0);
    expect(auth.linkFacebookCalls, 0);
    expect(auth.signInGoogleCalls, 0);
    expect(auth.signInFacebookCalls, 0);
  });

  test('J) parsing get_my_profile', () {
    final p = BrainProfile.fromRpc({
      'id': 'u1',
      'display_name': 'Zed',
      'locale': 'ar',
      'avatar_key': 'star',
      'onboarding_complete': true,
      'created_at': 't1',
      'updated_at': 't2',
    });
    expect(p.id, 'u1');
    expect(p.displayName, 'Zed');
    expect(p.locale, 'ar');
    expect(p.avatarKey, 'star');
    expect(p.onboardingComplete, isTrue);
  });

  test('K) parsing list_my_avatars trié par sort_order', () {
    final list = parseAvatarList([
      {'avatar_key': 'star', 'sort_order': 30, 'is_free': true},
      {'avatar_key': 'brain', 'sort_order': 10, 'is_free': true},
    ]);
    expect(list.map((a) => a.avatarKey), ['brain', 'star']);
  });

  testWidgets('L) les 8 clés live rendues', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: BrainAvatarChooser(
            avatars: [
              for (final k in liveAvatarKeys)
                BrainAvatar(
                  avatarKey: k,
                  sortOrder: 10,
                  isFree: true,
                  unlocked: true,
                  selected: false,
                ),
            ],
            onSelect: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(BrainAvatarView), findsNWidgets(8));
  });

  testWidgets('M) avatar verrouillé non sélectionnable', (tester) async {
    var picked = '';
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: BrainAvatarChooser(
            avatars: _avatars,
            onSelect: (k) => picked = k,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.emoji_events));
    await tester.pump();
    expect(picked, isNot('trophy'));
    await tester.tap(find.byIcon(Icons.rocket_launch));
    await tester.pump();
    expect(picked, 'rocket');
  });

  testWidgets('N) avatar sélectionné distinct', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: BrainAvatarChooser(avatars: _avatars, onSelect: (_) {}),
        ),
      ),
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  test('O) save passe par RPC avec params exacts', () async {
    final auth = FakeAuth();
    final repo = FakeRepo();
    final c = _container(auth, repo);
    addTearDown(c.dispose);
    await c
        .read(profileControllerProvider.notifier)
        .save(displayName: 'Zed', avatarKey: 'brain', locale: 'fr');
    expect(repo.saveCalls, 1);
    expect(repo.savedParams, {
      'p_display_name': 'Zed',
      'p_avatar_key': 'brain',
      'p_locale': 'fr',
    });
  });

  test('P) échec save : pas de gate optimiste', () async {
    final auth = FakeAuth();
    final repo = FakeRepo()..throwOnSave = true;
    final c = _container(auth, repo);
    addTearDown(c.dispose);
    final ok = await c
        .read(profileControllerProvider.notifier)
        .save(displayName: 'Zed', avatarKey: 'brain', locale: 'fr');
    expect(ok, isFalse);
    expect(c.read(profileControllerProvider).gateOpen, isFalse);
    expect(c.read(profileControllerProvider).saveError, isNotNull);
  });

  test('Q) succès save : gate ouverte', () async {
    final auth = FakeAuth();
    final repo = FakeRepo();
    final c = _container(auth, repo);
    addTearDown(c.dispose);
    final ok = await c
        .read(profileControllerProvider.notifier)
        .save(displayName: 'Zed', avatarKey: 'brain', locale: 'fr');
    expect(ok, isTrue);
    expect(c.read(profileControllerProvider).gateOpen, isTrue);
  });

  test('U) prefill metadata seulement si champ vierge et valide', () {
    expect(prefillDisplayName({'full_name': 'Zed'}), 'Zed');
    expect(prefillDisplayName({'name': 'x'}), isNull);
    expect(prefillDisplayName({}), isNull);
    expect(prefillDisplayName(null), isNull);
  });

  test('Y) manifest contient le filtre auth-callback', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('auth-callback'));
    expect(manifest, contains('android:scheme="brainwager"'));
    expect(manifest, contains('android:host="pack"'));
    expect(manifest, contains('android:host="join"'));
    // Aucun autoVerify actif (attribut) sur les filtres custom scheme.
    expect(manifest, isNot(contains('autoVerify="true"')));
  });

  test('Z/AA) parser pack/join intact, callback ignoré', () {
    expect(
      parseBrainwagerLink(Uri.parse('brainwager://auth-callback?code=x')),
      isNull,
    );
    expect(
      parseBrainwagerLink(Uri.parse('brainwager://auth-callback')),
      isNull,
    );
    expect(
      parseBrainwagerLink(Uri.parse('brainwager://join/ABCDE')),
      '/join?code=ABCDE',
    );
  });

  testWidgets('AB/AC) onboarding 320px + RTL sans overflow', (tester) async {
    for (final locale in [
      const Locale('en'),
      const Locale('fr'),
      const Locale('ar'),
    ]) {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(FakeRepo()),
            socialAuthGatewayProvider.overrideWithValue(FakeAuth()),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  test(
    'OAuth pending : lancement OK => en attente, pas d\u2019erreur',
    () async {
      final auth = FakeAuth()..launchResult = true;
      final repo = FakeRepo();
      final c = _container(auth, repo);
      addTearDown(c.dispose);
      await c.read(profileControllerProvider.notifier).secureWithGoogle();
      final s = c.read(profileControllerProvider);
      expect(s.oauthPending, isTrue);
      expect(s.oauthError, isNull);
      expect(s.gateOpen, isFalse);
    },
  );

  test('OAuth indisponible : pas de crash, session invité intacte', () async {
    final auth = FakeAuth()..launchResult = false;
    final repo = FakeRepo();
    final c = _container(auth, repo);
    addTearDown(c.dispose);
    await c.read(profileControllerProvider.notifier).secureWithFacebook();
    final s = c.read(profileControllerProvider);
    expect(s.oauthPending, isFalse);
    expect(s.oauthError, 'oauth-unavailable');
    expect(auth.currentUserId, 'uuid-1');
  });

  test('Nom invalide : save refusé, gate fermée', () async {
    final auth = FakeAuth();
    final repo = FakeRepo();
    final c = _container(auth, repo);
    addTearDown(c.dispose);
    final ok = await c
        .read(profileControllerProvider.notifier)
        .save(displayName: 'x', avatarKey: 'brain', locale: 'fr');
    expect(ok, isFalse);
    expect(repo.saveCalls, 0);
    expect(c.read(profileControllerProvider).saveError, 'invalid-display-name');
    expect(c.read(profileControllerProvider).gateOpen, isFalse);
  });

  testWidgets('R) gate masque la navbar pendant l\u2019onboarding', (
    tester,
  ) async {
    final auth = FakeAuth();
    final repo = FakeRepo()
      ..profileToReturn = const BrainProfile(
        id: 'uuid-1',
        displayName: '',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          socialAuthGatewayProvider.overrideWithValue(auth),
        ],
        child: _app(
          OnboardingGate(
            child: Scaffold(
              body: Text('CHILD'),
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
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('CHILD'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('S) la localisation router survit à l\u2019ouverture', (
    tester,
  ) async {
    final auth = FakeAuth();
    final repo = FakeRepo()
      ..profileToReturn = const BrainProfile(
        id: 'uuid-1',
        displayName: '',
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
    await container.read(profileControllerProvider.notifier).ensureStarted();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(
          const OnboardingGate(child: Text('ROUTE:/join?code=ABCDE')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Gate fermée : la route sous-jacente est masquée, pas détruite.
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('ROUTE:/join?code=ABCDE'), findsNothing);
    // Succès serveur => la même route réapparaît intacte.
    repo.profileToReturn = const BrainProfile(
      id: 'uuid-1',
      displayName: 'Zed',
      locale: 'fr',
      avatarKey: 'brain',
      onboardingComplete: true,
    );
    await container.read(profileControllerProvider.notifier).reloadAll();
    await tester.pumpAndSettle();
    expect(find.text('ROUTE:/join?code=ABCDE'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('T) profil terminé saute l\u2019onboarding', (tester) async {
    final auth = FakeAuth();
    final repo = FakeRepo()
      ..profileToReturn = const BrainProfile(
        id: 'uuid-1',
        displayName: 'Zed',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: true,
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          socialAuthGatewayProvider.overrideWithValue(auth),
        ],
        child: _app(const OnboardingGate(child: Text('CHILD-OK'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CHILD-OK'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('V) la frappe n\u2019est jamais écrasée par les métadonnées', (
    tester,
  ) async {
    final auth = FakeAuth()..metadata = {'full_name': 'Zed'};
    final repo = FakeRepo()
      ..profileToReturn = const BrainProfile(
        id: 'uuid-1',
        displayName: '',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: false,
      )
      ..avatarsToReturn = _avatars;
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
        child: _app(const OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    // Pré-remplissage best-effort depuis OAuth.
    expect(tester.widget<TextField>(field).controller!.text, 'Zed');
    await tester.enterText(field, 'Custom');
    await tester.pump();
    // Nouvelles métadonnées après frappe : jamais d\u2019écrasement.
    auth.metadata = {'full_name': 'Other'};
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.widget<TextField>(field).controller!.text, 'Custom');
  });

  testWidgets('W) Create pré-remplit le pseudo une fois', (tester) async {
    final auth = FakeAuth();
    final repo = FakeRepo()
      ..profileToReturn = const BrainProfile(
        id: 'uuid-1',
        displayName: 'Zed',
        locale: 'fr',
        avatarKey: 'brain',
        onboardingComplete: true,
      );
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        socialAuthGatewayProvider.overrideWithValue(auth),
        packCatalogProvider.overrideWith(
          (ref) async => const PackCatalog(packs: [], activeEntitlements: {}),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileControllerProvider.notifier).ensureStarted();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(const Scaffold(body: CreateScreen())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final field = find.byType(TextField).first;
    expect(tester.widget<TextField>(field).controller!.text, 'Zed');
    await tester.enterText(field, 'Custom');
    await tester.pump();
    await container.read(profileControllerProvider.notifier).reloadAll();
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, 'Custom');
  });

  testWidgets('X) Join pré-remplit le pseudo une fois', (tester) async {
    final auth = FakeAuth();
    final repo = FakeRepo()
      ..profileToReturn = const BrainProfile(
        id: 'uuid-1',
        displayName: 'Zed',
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
    await container.read(profileControllerProvider.notifier).ensureStarted();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(const Scaffold(body: JoinScreen())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Join : [0] = code, [1] = pseudo.
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    final pseudo = fields.at(1);
    expect(tester.widget<TextField>(pseudo).controller!.text, 'Zed');
    await tester.enterText(pseudo, 'Custom');
    await tester.pump();
    await container.read(profileControllerProvider.notifier).reloadAll();
    await tester.pump();
    expect(tester.widget<TextField>(pseudo).controller!.text, 'Custom');
  });
}

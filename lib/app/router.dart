// Navigation go_router : packs Phase 3A ; partage/deep links Phase 3D.
import 'package:go_router/go_router.dart';

import '../../features/lobby/lobby_screens.dart';
import '../../features/game_session/game_screen.dart';
import '../../features/packs/pack_screens.dart';
import '../../features/packs/pack_import_screen.dart';
import '../../features/packs/shared_pack_screen.dart';
import '../../features/packs/ugc_editor_screen.dart';
import '../../features/shop/shop_screen.dart';

final brainRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/home'),
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: '/create',
      builder: (_, state) =>
          CreateScreen(sharedCode: state.uri.queryParameters['share']),
    ),
    GoRoute(
      path: '/join',
      builder: (_, state) =>
          JoinScreen(initialCode: state.uri.queryParameters['code']),
    ),
    GoRoute(path: '/packs', builder: (_, _) => const PacksScreen()),
    GoRoute(path: '/shop', builder: (_, _) => const ShopScreen()),
    // Statiques AVANT les paramètres : /packs/edit, /packs/import et
    // /packs/shared/... ne doivent jamais matcher /packs/:id.
    GoRoute(path: '/packs/import', builder: (_, _) => const PackImportScreen()),
    GoRoute(
      path: '/packs/shared/:code',
      builder: (_, state) =>
          SharedPackScreen(code: state.pathParameters['code']!),
    ),
    GoRoute(path: '/packs/edit', builder: (_, _) => const UgcEditorScreen()),
    GoRoute(
      path: '/packs/edit/:id',
      builder: (_, state) =>
          UgcEditorScreen(packId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/packs/:id',
      builder: (_, state) =>
          PackDetailScreen(packId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/game/:id',
      builder: (_, state) => GameScreen(gameId: state.pathParameters['id']!),
    ),
  ],
);

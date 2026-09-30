// Navigation go_router : packs Phase 3A ; deep links join/pack Phase 3B+.
import 'package:go_router/go_router.dart';
import '../../features/lobby/lobby_screens.dart';
import '../../features/game_session/game_screen.dart';
import '../../features/packs/pack_screens.dart';

final brainRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/home'),
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/create', builder: (_, _) => const CreateScreen()),
    GoRoute(path: '/join', builder: (_, _) => const JoinScreen()),
    GoRoute(path: '/packs', builder: (_, _) => const PacksScreen()),
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

// Navigation go_router : deep links join/pack prévus Phase 3.
import 'package:go_router/go_router.dart';
import '../../features/lobby/lobby_screens.dart';
import '../../features/game_session/game_screen.dart';

final brainRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/home'),
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/create', builder: (_, _) => const CreateScreen()),
    GoRoute(path: '/join', builder: (_, _) => const JoinScreen()),
    GoRoute(
      path: '/game/:id',
      builder: (_, state) => GameScreen(gameId: state.pathParameters['id']!),
    ),
  ],
);

// Sélection pure : 10 normales + 1 finale, sans doublon, finale la plus difficile.
// Miroir de la logique SQL de create_game (doc 02).
import '../../core/config/game_config.dart';
import 'models.dart';

class PoolTooSmallException implements Exception {
  final String message;
  const PoolTooSmallException(this.message);
  @override
  String toString() => 'PoolTooSmallException: $message';
}

List<GameQuestion> selectGameQuestions(
  List<GameQuestion> pool, {
  GameConfig config = const GameConfig(),
}) {
  final needed = config.totalQuestions;
  if (pool.length < needed) {
    throw PoolTooSmallException(
      'need $needed questions, got ${pool.length}',
    );
  }
  final byId = <String, GameQuestion>{};
  for (final q in pool) {
    byId[q.id] = q;
  }
  if (byId.length < needed) {
    throw const PoolTooSmallException('duplicate ids in pool');
  }
  final maxDiff = pool.map((q) => q.difficulty).reduce((a, b) => a > b ? a : b);
  final hardest = pool.where((q) => q.difficulty == maxDiff).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final finale = hardest.first;
  final rest = pool.where((q) => q.id != finale.id).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  // Déterministe en test (tri par id) ; tirage aléatoire côté serveur en prod
  // avec la même contrainte : 10 premiers + finale difficile.
  final normals = rest.take(config.totalQuestions - 1).toList();
  return [...normals, finale];
}

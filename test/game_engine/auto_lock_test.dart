import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_engine/auto_lock.dart';

void main() {
  test('une seule tentative par question', () {
    final t = AutoLockTracker();
    expect(t.shouldAttempt(3), isTrue);
    t.markAttempted(3);
    expect(t.shouldAttempt(3), isFalse);
  });

  test('positions indépendantes', () {
    final t = AutoLockTracker();
    t.markAttempted(3);
    expect(t.shouldAttempt(4), isTrue);
  });

  test('reset réautorise tout (nouvelle partie)', () {
    final t = AutoLockTracker();
    t.markAttempted(3);
    t.reset();
    expect(t.shouldAttempt(3), isTrue);
  });
}

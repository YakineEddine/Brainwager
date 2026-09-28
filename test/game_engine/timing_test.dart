import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/game_engine/timing.dart';

void main() {
  group('remainingSeconds', () {
    test('compte depuis le timestamp serveur', () {
      final opened = DateTime.utc(2026, 9, 20, 12, 0, 0);
      expect(
        remainingSeconds(
          openedAtUtc: opened,
          durationSec: 30,
          nowUtc: opened.add(const Duration(seconds: 10)),
        ),
        20,
      );
    });

    test('borné à zéro après la fin', () {
      final opened = DateTime.utc(2026, 9, 20, 12, 0, 0);
      expect(
        remainingSeconds(
          openedAtUtc: opened,
          durationSec: 30,
          nowUtc: opened.add(const Duration(seconds: 99)),
        ),
        0,
      );
    });

    test('reconnect tardive : reste exact depuis opened_at absolu', () {
      // App en pause 25 s puis reprise : pas besoin des ticks manqués.
      final opened = DateTime.utc(2026, 9, 20, 12, 0, 0);
      expect(
        remainingSeconds(
          openedAtUtc: opened,
          durationSec: 30,
          nowUtc: opened.add(const Duration(seconds: 25)),
        ),
        5,
      );
    });
  });

  group('seuil de lock', () {
    test('lockEligibleAt = opened + duration − grace', () {
      final opened = DateTime.utc(2026, 9, 20, 12, 0, 0);
      expect(
        lockEligibleAt(
          openedAtUtc: opened,
          durationSec: 30,
          lockGraceSec: 2,
        ),
        opened.add(const Duration(seconds: 28)),
      );
    });

    test('isLockDue faux avant, vrai au point et après', () {
      final opened = DateTime.utc(2026, 9, 20, 12, 0, 0);
      bool dueAt(int sec) => isLockDue(
            openedAtUtc: opened,
            durationSec: 30,
            lockGraceSec: 2,
            nowUtc: opened.add(Duration(seconds: sec)),
          );
      expect(dueAt(27), isFalse);
      expect(dueAt(28), isTrue);
      expect(dueAt(45), isTrue);
    });
  });
}

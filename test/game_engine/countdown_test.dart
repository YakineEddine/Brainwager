import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/shared/widgets/countdown_ring.dart';

void main() {
  test('restant = opened + duration − now, jamais négatif', () {
    final opened = DateTime.utc(2026, 9, 20, 12, 0, 0);
    expect(
      remainingSeconds(
        openedAtUtc: opened,
        durationSec: 30,
        nowUtc: opened.add(const Duration(seconds: 10)),
      ),
      20,
    );
    expect(
      remainingSeconds(
        openedAtUtc: opened,
        durationSec: 30,
        nowUtc: opened.add(const Duration(seconds: 99)),
      ),
      0,
    );
  });
}

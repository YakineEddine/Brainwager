import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/core/navigation/deep_link_parser.dart';

void main() {
  test('J) lien pack -> /packs/shared/PK-AB12', () {
    expect(
      parseBrainwagerLink(Uri.parse('brainwager://pack/PK-AB12')),
      '/packs/shared/PK-AB12',
    );
    expect(
      parseBrainwagerLink(Uri.parse('brainwager://pack/pk-ab12')),
      '/packs/shared/PK-AB12',
    );
  });

  test('K) lien join -> /join?code=ABCDE', () {
    expect(
      parseBrainwagerLink(Uri.parse('brainwager://join/ABCDE')),
      '/join?code=ABCDE',
    );
    expect(
      parseBrainwagerLink(Uri.parse('brainwager://join/abcde')),
      '/join?code=ABCDE',
    );
  });

  test('L) mauvais scheme ignoré', () {
    expect(parseBrainwagerLink(Uri.parse('https://pack/PK-AB12')), isNull);
    expect(parseBrainwagerLink(Uri.parse('http://join/ABCDE')), isNull);
    expect(parseBrainwagerLink(Uri.parse('brainwager2://pack/PK-AB12')),
        isNull);
  });

  test('M) hôte inconnu ignoré', () {
    expect(parseBrainwagerLink(Uri.parse('brainwager://shop/x')), isNull);
    expect(parseBrainwagerLink(Uri.parse('brainwager://')), isNull);
  });

  test('N) URI pack malformée ignorée', () {
    expect(parseBrainwagerLink(Uri.parse('brainwager://pack/AB12')), isNull);
    expect(parseBrainwagerLink(Uri.parse('brainwager://pack/')), isNull);
    expect(parseBrainwagerLink(Uri.parse('brainwager://join/AB')), isNull);
    expect(parseBrainwagerLink(Uri.parse('brainwager://join/')), isNull);
  });

  test('O) segment supplémentaire ignoré', () {
    expect(
        parseBrainwagerLink(Uri.parse('brainwager://pack/PK-AB12/extra')),
        isNull);
    expect(
        parseBrainwagerLink(Uri.parse('brainwager://join/ABCDE/extra')),
        isNull);
  });
}

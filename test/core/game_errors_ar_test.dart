import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/core/utils/game_errors.dart';

void main() {
  test('A) pack-premium-locked ne tombe PAS sur le message locked', () {
    expect(
      friendlyGameError(Exception('pack-premium-locked'), 'fr'),
      isNot(contains('Temps écoulé')),
    );
  });

  test('B) pack-premium-locked FR/EN/AR', () {
    expect(
      friendlyGameError(Exception('pack-premium-locked'), 'fr'),
      'Ce pack premium n’est pas débloqué.',
    );
    expect(
      friendlyGameError(Exception('pack-premium-locked'), 'en'),
      'This premium pack is not unlocked.',
    );
    expect(
      friendlyGameError(Exception('pack-premium-locked'), 'ar'),
      'لم يتم فتح هذه الحزمة المميزة.',
    );
  });

  test('C) locked nu reste le message timer', () {
    expect(
      friendlyGameError(Exception('locked'), 'fr'),
      'Temps écoulé : question verrouillée.',
    );
  });

  test('D) pack-hidden FR/EN/AR', () {
    expect(
      friendlyGameError(Exception('pack-hidden'), 'fr'),
      'Ce pack n’est plus disponible.',
    );
    expect(
      friendlyGameError(Exception('pack-hidden'), 'en'),
      'This pack is no longer available.',
    );
    expect(
      friendlyGameError(Exception('pack-hidden'), 'ar'),
      'هذه الحزمة لم تعد متاحة.',
    );
  });

  test('E) pack-not-visible FR/EN/AR', () {
    expect(
      friendlyGameError(Exception('pack-not-visible'), 'fr'),
      'Tu n’as pas accès à ce pack.',
    );
    expect(
      friendlyGameError(Exception('pack-not-visible'), 'en'),
      'You do not have access to this pack.',
    );
    expect(
      friendlyGameError(Exception('pack-not-visible'), 'ar'),
      'ليس لديك صلاحية الوصول إلى هذه الحزمة.',
    );
  });

  test('F) invalid-nickname FR/EN/AR', () {
    expect(
      friendlyGameError(Exception('invalid-nickname'), 'fr'),
      'Pseudo invalide.',
    );
    expect(
      friendlyGameError(Exception('invalid-nickname'), 'en'),
      'Invalid nickname.',
    );
    expect(
      friendlyGameError(Exception('invalid-nickname'), 'ar'),
      'الاسم المستعار غير صالح.',
    );
  });

  test('G) pseudo-invalide passe par le chemin invalid-nickname', () {
    expect(
      friendlyGameError(Exception('pseudo-invalide'), 'fr'),
      friendlyGameError(Exception('invalid-nickname'), 'fr'),
    );
  });

  test('H) not-host FR/EN/AR', () {
    expect(
      friendlyGameError(Exception('not-host'), 'fr'),
      'Seul l’hôte peut faire ça.',
    );
    expect(
      friendlyGameError(Exception('not-host'), 'en'),
      'Only the host can do that.',
    );
    expect(
      friendlyGameError(Exception('not-host'), 'ar'),
      'المضيف فقط يمكنه فعل ذلك.',
    );
  });

  test('I) pack-manquant localisé', () {
    expect(
      friendlyGameError(Exception('pack-manquant'), 'en'),
      'No pack selected.',
    );
    expect(
      friendlyGameError(Exception('pack-manquant'), 'ar'),
      'لم يتم اختيار أي حزمة.',
    );
  });
}

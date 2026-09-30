import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/packs/pack.dart';
import 'package:brainwager/features/packs/pack_selection.dart';
import 'package:brainwager/features/lobby/lobby_viewmodel.dart';

const _free = PackSummary(
  id: 'free1',
  titleFr: 'Démo',
  titleEn: 'Demo',
  titleAr: 'تجريبي',
  descFr: '',
  descEn: '',
  descAr: '',
  isOfficial: true,
  isPremium: false,
  priceSku: null,
  shareCode: 'DEMO01',
  ownerId: null,
  isHidden: false,
);

const _locked = PackSummary(
  id: 'prem1',
  titleFr: 'Cinéma',
  titleEn: 'Cinema',
  titleAr: '',
  descFr: '',
  descEn: '',
  descAr: '',
  isOfficial: true,
  isPremium: true,
  priceSku: 'pack_cinema',
  shareCode: 'CINE01',
  ownerId: null,
  isHidden: false,
);

const _hidden = PackSummary(
  id: 'hid1',
  titleFr: 'Caché',
  titleEn: 'Hidden',
  titleAr: '',
  descFr: '',
  descEn: '',
  descAr: '',
  isOfficial: false,
  isPremium: false,
  priceSku: null,
  shareCode: 'HID01',
  ownerId: 'u1',
  isHidden: true,
);

void main() {
  test('H) premier pack accessible sélectionné par défaut', () {
    expect(
      defaultSelectedPackId([_locked, _free], {}),
      'free1',
    );
  });

  test('I) premium verrouillé exclu des sélectionnables', () {
    final sel = selectablePacks([_free, _locked], {});
    expect(sel.map((p) => p.id), ['free1']);
    expect(
      defaultSelectedPackId([_locked], {'pack_cinema'}),
      'prem1',
    );
  });

  test('J) aucun pack accessible => sélection nulle (Create désactivé)', () {
    expect(defaultSelectedPackId([_locked], {}), isNull);
    expect(defaultSelectedPackId([], {}), isNull);
    expect(selectablePacks([_locked], {}), isEmpty);
  });

  test('packs masqués exclus défensivement', () {
    expect(
      selectablePacks([_hidden, _free], {}).map((p) => p.id),
      ['free1'],
    );
  });

  test('K) createGame utilise le packId explicite, sans lookup share_code',
      () {
    final params = buildCreateGameParams(
        packId: 'pid-123', nickname: 'Moi', language: 'ar');
    expect(params['p_pack_id'], 'pid-123');
    expect(params['p_nickname'], 'Moi');
    expect(params.containsKey('p_share_code'), isFalse);
    expect(params['p_team_mode'], isFalse);
    expect(params['p_language'], 'ar');
    expect(params['p_duration'], 30);
  });

  test('I) buildCreateGameParams envoie p_language explicite', () {
    for (final lang in ['fr', 'en', 'ar']) {
      final params = buildCreateGameParams(
          packId: 'p', nickname: 'Moi', language: lang);
      expect(params['p_language'], lang);
    }
  });

  test('J) langue par défaut : ar depuis locale arabe, fr sinon', () {
    expect(defaultGameLanguage('ar'), 'ar');
    expect(defaultGameLanguage('en'), 'en');
    expect(defaultGameLanguage('fr'), 'fr');
    expect(defaultGameLanguage('de'), 'fr');
    expect(defaultGameLanguage(''), 'fr');
  });
}

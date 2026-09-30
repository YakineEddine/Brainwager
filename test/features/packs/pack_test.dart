import 'package:flutter_test/flutter_test.dart';
import 'package:brainwager/features/packs/pack.dart';
import 'package:brainwager/features/packs/pack_preview.dart';

const _free = PackSummary(
  id: 'free1',
  titleFr: 'Démo Soirée',
  titleEn: 'Demo Party',
  titleAr: 'سهرة تجريبية',
  descFr: 'Soirée test',
  descEn: 'Test party',
  descAr: '',
  isOfficial: true,
  isPremium: false,
  priceSku: null,
  shareCode: 'DEMO01',
  ownerId: null,
  isHidden: false,
);

const _premium = PackSummary(
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

void main() {
  test('A) FR : titre/description français', () {
    expect(_free.localizedTitle('fr'), 'Démo Soirée');
    expect(_free.localizedDescription('fr'), 'Soirée test');
  });

  test('B) EN : titre/description anglais', () {
    expect(_free.localizedTitle('en'), 'Demo Party');
    expect(_free.localizedDescription('en'), 'Test party');
  });

  test('C) pack gratuit accessible sans entitlement', () {
    expect(_free.isAccessible({}), isTrue);
  });

  test('D) premium verrouillé sans entitlement (y compris sans SKU)', () {
    expect(_premium.isAccessible({}), isFalse);
    const noSku = PackSummary(
      id: 'x',
      titleFr: '',
      titleEn: '',
      titleAr: '',
      descFr: '',
      descEn: '',
      descAr: '',
      isOfficial: true,
      isPremium: true,
      priceSku: null,
      shareCode: 'X',
      ownerId: null,
      isHidden: false,
    );
    expect(noSku.isAccessible({'pack_cinema'}), isFalse);
  });

  test('E) premium débloqué par entitlement actif correspondant', () {
    expect(_premium.isAccessible({'pack_cinema'}), isTrue);
  });

  test('F) entitlement sans rapport ne débloque rien', () {
    expect(_premium.isAccessible({'remove_ads'}), isFalse);
  });

  test('G) aperçu officiel : match_mode absent toléré, lignes triées', () {
    final rows = parsePackPreview([
      {
        'idx': 1,
        'prompt_fr': 'Q2 ?',
        'prompt_en': 'Q2?',
        'category': 'g',
        'difficulty': 2,
      },
      {
        'idx': 0,
        'prompt_fr': 'Q1 ?',
        'prompt_en': 'Q1?',
        'category': 's',
        'difficulty': 1,
        'match_mode': 'exact',
      },
      'junk',
      {'idx': 5},
    ]);
    expect(rows.length, 2);
    expect(rows[0].idx, 0);
    expect(rows[0].matchMode, 'exact');
    expect(rows[1].matchMode, isNull);
    expect(rows[1].localizedPrompt('fr'), 'Q2 ?');
    expect(rows[1].localizedPrompt('en'), 'Q2?');
  });

  test('D) parse title_ar/desc_ar', () {
    final p = PackSummary.fromRow({
      'id': '1',
      'title_fr': 'Titre',
      'title_en': 'Title',
      'title_ar': 'عنوان',
      'desc_fr': '',
      'desc_en': '',
      'desc_ar': 'وصف',
    });
    expect(p.titleAr, 'عنوان');
    expect(p.descAr, 'وصف');
  });

  test('E) localizedTitle ar utilise l’arabe', () {
    expect(_free.localizedTitle('ar'), 'سهرة تجريبية');
  });

  test('F) arabe vide => repli FR (jamais de blanc)', () {
    expect(_premium.localizedTitle('ar'), 'Cinéma');
    expect(_premium.localizedDescription('ar'), '');
    expect(_free.localizedDescription('ar'), 'Soirée test');
  });

  test('G) aperçu parse prompt_ar', () {
    final rows = parsePackPreview([
      {
        'idx': 0,
        'prompt_fr': 'Q ?',
        'prompt_en': 'Q?',
        'prompt_ar': 'سؤال؟',
        'category': 'g',
        'difficulty': 1,
      },
    ]);
    expect(rows.single.promptAr, 'سؤال؟');
  });

  test('H) localizedPrompt ar + repli FR', () {
    final rows = parsePackPreview([
      {
        'idx': 0,
        'prompt_fr': 'Q ?',
        'prompt_en': 'Q?',
        'prompt_ar': 'سؤال؟',
        'category': 'g',
        'difficulty': 1,
      },
      {
        'idx': 1,
        'prompt_fr': 'Q2 ?',
        'prompt_en': 'Q2?',
        'category': 'g',
        'difficulty': 1,
      },
    ]);
    expect(rows[0].localizedPrompt('ar'), 'سؤال؟');
    expect(rows[1].localizedPrompt('ar'), 'Q2 ?');
  });
}

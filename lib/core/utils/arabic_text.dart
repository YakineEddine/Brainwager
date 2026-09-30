// Script arabe partagé (pur Dart) : miroir exact de normalize_answer SQL
// (migration 0012). Source unique pour le matcher de jeu et le normaliseur
// numérique (UGC effectiveMatchMode).
// Tous les caractères arabes sont exprimés en codepoints hexadécimaux
// explicites : aucun glyphe ambigu en source.

// Chiffres arabes orientaux U+0660-0669 et persans U+06F0-06F9 -> ASCII.
const Map<int, int> _arabicDigitMap = {
  0x0660: 0x30,
  0x0661: 0x31,
  0x0662: 0x32,
  0x0663: 0x33,
  0x0664: 0x34,
  0x0665: 0x35,
  0x0666: 0x36,
  0x0667: 0x37,
  0x0668: 0x38,
  0x0669: 0x39,
  0x06F0: 0x30,
  0x06F1: 0x31,
  0x06F2: 0x32,
  0x06F3: 0x33,
  0x06F4: 0x34,
  0x06F5: 0x35,
  0x06F6: 0x36,
  0x06F7: 0x37,
  0x06F8: 0x38,
  0x06F9: 0x39,
};

/// Chiffres arabes/persans -> ASCII (miroir du translate() SQL).
String mapArabicDigits(String s) {
  final buf = StringBuffer();
  for (final c in s.runes) {
    buf.writeCharCode(_arabicDigitMap[c] ?? c);
  }
  return buf.toString();
}

// Séparateurs arabes : décimal U+066B, milliers U+066C.
String _mapArabicSeparators(String s) {
  final buf = StringBuffer();
  for (final c in s.runes) {
    if (c == 0x066B) {
      buf.write('.');
    } else if (c == 0x066C) {
      // Milliers : supprimé (miroir SQL).
    } else {
      buf.writeCharCode(c);
    }
  }
  return buf.toString();
}

/// Normaliseur numérique ciblé : chiffres + séparateurs arabes, sans
/// toucher aux lettres (pas de suppression d'espaces/ponctuation).
String normalizeNumericAnswer(String raw) {
  return _mapArabicSeparators(mapArabicDigits(raw.trim()));
}

/// Réponse primaire numérique ? Nombres et années, chiffres ASCII ou
/// arabes/persans (ex. 1984, ١٩٨٤, ۱۹۸۴, -12,5, -١٢٫٥).
bool isNumericAnswer(String raw) {
  final s = normalizeNumericAnswer(raw);
  return RegExp(r'^-?[0-9]+([.,][0-9]+)?$').hasMatch(s);
}

/// Vrai si le codepoint est une lettre arabe de base (plage SQL exacte
/// U+0621-U+064A, utilisée par la classe de conservation et le test ال).
bool isArabicLetter(int c) => c >= 0x0621 && c <= 0x064A;

/// Vrai si le codepoint est une haraka/diacritique arabe (plages exactes
/// de la regexp SQL : U+0610-061A, U+064B-065F, U+0670, U+06D6-06ED).
bool isArabicDiacritic(int c) {
  return (c >= 0x0610 && c <= 0x061A) ||
      (c >= 0x064B && c <= 0x065F) ||
      c == 0x0670 ||
      (c >= 0x06D6 && c <= 0x06ED);
}

/// Formes de lettres arabes (miroir translate SQL) : variantes d'Alef
/// (U+0623, U+0625, U+0622, U+0671) -> Alef (U+0627), Alef Maqsura
/// (U+0649) -> Ya (U+064A). Jeux disjoints : l'ordre est sans effet.
String normalizeAlefForms(String s) {
  final buf = StringBuffer();
  for (final c in s.runes) {
    if (c == 0x0623 || c == 0x0625 || c == 0x0622 || c == 0x0671) {
      buf.writeCharCode(0x0627);
    } else if (c == 0x0649) {
      buf.writeCharCode(0x064A);
    } else {
      buf.writeCharCode(c);
    }
  }
  return buf.toString();
}

/// Tatweel (U+0640) + harakat retirés (miroir SQL, jeux disjoints).
String stripArabicMarks(String s) {
  final buf = StringBuffer();
  for (final c in s.runes) {
    if (c == 0x0640 || isArabicDiacritic(c)) continue;
    buf.writeCharCode(c);
  }
  return buf.toString();
}

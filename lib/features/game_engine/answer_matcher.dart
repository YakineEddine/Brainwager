// Normalisation + Levenshtein + match_mode.
// Nombres et années toujours en exact, même si la question est en fuzzy.
import '../../core/config/game_config.dart';
import 'models.dart';

final _numberRe = RegExp(r'^-?\d+([.,]\d+)?$');
final _yearRe = RegExp(r'^(17|18|19|20)\d{2}$');
const _articles = {'le', 'la', 'les', 'un', 'une', 'des', "l'", 'l', 'd', 'the', 'a', 'an'};

String normalizeAnswer(String raw) {
  var s = raw.toLowerCase().trim();
  s = s
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ÿ', 'y')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n');
  s = s.replaceAll(RegExp(r"[’‘'ʼ`]"), "'");
  s = s.replaceAll(RegExp(r'[^a-z0-9\s\-]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  final parts = s.split(' ');
  if (parts.isNotEmpty && _articles.contains(parts.first) && parts.length > 1) {
    s = parts.sublist(1).join(' ');
  }
  // Années/nombres : uniformise séparateurs pour comparaison exacte.
  s = s.replaceAll(',', '.');
  return s;
}

bool _isNumericLike(String normalized) {
  final compact = normalized.replaceAll(' ', '').replaceAll('.', '');
  if (_numberRe.hasMatch(normalized)) return true;
  if (_yearRe.hasMatch(normalized)) return true;
  if (RegExp(r'^\d+$').hasMatch(compact)) return true;
  return false;
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final curr = List<int>.filled(b.length + 1, 0);
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = curr;
  }
  return prev[b.length];
}

int _threshold(int len, GameConfig config) {
  if (len <= 5) return config.fuzzy.tiny;
  if (len <= 8) return config.fuzzy.short;
  return config.fuzzy.long;
}

/// Vrai si la réponse du joueur est acceptée.
bool matchAnswer({
  required String playerRaw,
  required String expectedRaw,
  List<String> aliasesRaw = const [],
  MatchMode mode = MatchMode.fuzzy,
  GameConfig config = const GameConfig(),
}) {
  final p = normalizeAnswer(playerRaw);
  final e = normalizeAnswer(expectedRaw);
  if (p.isEmpty || e.isEmpty) return false;
  if (p == e) return true;
  for (final a in aliasesRaw) {
    if (p == normalizeAnswer(a)) return true;
  }
  // Nombres / années : exact strict, sans tolérance.
  if (_isNumericLike(p) || _isNumericLike(e)) return false;
  if (mode == MatchMode.exact) return false;
  final candidates = [e, ...aliasesRaw.map(normalizeAnswer)];
  for (final c in candidates) {
    final d = levenshtein(p, c);
    if (d <= _threshold(c.length, config)) return true;
  }
  return false;
}

// Filtre de pseudos FR/EN embarqué (sans service externe).
// Liste courte de racines : le serveur rejette aussi via longueur + unicité,
// l'hôte peut exclure. À étendre en Phase 4 (signalement packs déjà en 0001).
const _bannedRoots = [
  'merde', 'con', 'connard', 'salope', 'pute', 'encule', 'bite', 'couille',
  'fuck', 'shit', 'bitch', 'asshole', 'dick', 'nazi', 'hitler',
];

bool isNicknameClean(String nickname) {
  final n = nickname.toLowerCase().trim();
  if (n.length < 2 || n.length > 20) return false;
  for (final root in _bannedRoots) {
    if (n.contains(root)) return false;
  }
  return true;
}

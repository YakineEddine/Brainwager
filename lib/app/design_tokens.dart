// Design tokens Brainwager (Phase UI-1) : espacement, rayons, élévations,
// rôles couleur sémantiques. Les hexadécimaux de marque (BrainColors)
// restent inchangés ; ce fichier ajoute la discipline d'usage.
// Pur Dart (aucun import Flutter) : testable, réutilisable partout.
class BrainSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class BrainRadius {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;
}

/// Hauteurs tactiles minimales (accessibilité).
class BrainTouch {
  static const double buttonHeight = 56;
  static const double minTarget = 48;
}

/// Rôles sémantiques (noms, pas de hex ici : voir BrainColors dans theme).
/// - background : fond app    - surface : cartes/panneaux
/// - surfaceHigh : cartes mises en avant / hero
/// - outline : bordures violettes subtiles
/// - accent : or (énergie, CTA secondaires, highlights)
/// - success : turquoise   - danger : corail
class BrainRoles {
  static const String background = 'background';
  static const String surface = 'surface';
  static const String surfaceHigh = 'surfaceHigh';
  static const String outline = 'outline';
  static const String accent = 'accent';
  static const String success = 'success';
  static const String danger = 'danger';
}

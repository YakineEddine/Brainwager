// Direction du contenu de jeu (pur Dart) : langue du CONTENU (serveur),
// jamais la locale UI (une UI FR peut afficher une partie AR et inversement).
import 'package:flutter/widgets.dart';

TextDirection contentDirection(String languageCode) =>
    languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

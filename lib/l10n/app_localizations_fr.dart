// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Brainwager';

  @override
  String get tagline => 'Parie sur ce que tu sais';

  @override
  String get createGame => 'Créer une partie';

  @override
  String get joinGame => 'Rejoindre';

  @override
  String get packs => 'Packs';

  @override
  String get shop => 'Boutique';

  @override
  String get settings => 'Réglages';

  @override
  String get joinCode => 'Code de partie';

  @override
  String get nickname => 'Pseudo';

  @override
  String get start => 'Démarrer';

  @override
  String get nextQuestion => 'Question suivante';

  @override
  String get lockAnswers => 'Verrouiller les réponses';

  @override
  String get revealAnswer => 'Révéler la réponse';

  @override
  String get finalWagerTitle => 'Question finale — mise 0, 10 ou 20';

  @override
  String get packOfficial => 'Officiel';

  @override
  String get packMine => 'Mon pack';

  @override
  String get packPremium => 'Premium';

  @override
  String get packLocked => 'Verrouillé';

  @override
  String get packComingSoon => 'Disponible bientôt';

  @override
  String get packRetry => 'Réessayer';

  @override
  String get packLoadError => 'Chargement impossible';

  @override
  String get packEmpty => 'Aucun pack disponible';

  @override
  String get packChoosePack => 'Choisir un pack';

  @override
  String get packNoAccessiblePack =>
      'Aucun pack accessible pour créer une partie';

  @override
  String get packPreview => 'Aperçu';
}

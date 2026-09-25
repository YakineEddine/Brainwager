// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Brainwager';

  @override
  String get tagline => 'Bet on what you know';

  @override
  String get createGame => 'Create game';

  @override
  String get joinGame => 'Join game';

  @override
  String get packs => 'Packs';

  @override
  String get shop => 'Shop';

  @override
  String get settings => 'Settings';

  @override
  String get joinCode => 'Join code';

  @override
  String get nickname => 'Nickname';

  @override
  String get start => 'Start';

  @override
  String get nextQuestion => 'Next question';

  @override
  String get lockAnswers => 'Lock answers';

  @override
  String get revealAnswer => 'Reveal answer';

  @override
  String get finalWagerTitle => 'Final question — wager 0, 10 or 20';
}

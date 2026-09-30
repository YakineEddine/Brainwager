import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('fr'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Brainwager'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Bet on what you know'**
  String get tagline;

  /// No description provided for @createGame.
  ///
  /// In en, this message translates to:
  /// **'Create game'**
  String get createGame;

  /// No description provided for @joinGame.
  ///
  /// In en, this message translates to:
  /// **'Join game'**
  String get joinGame;

  /// No description provided for @packs.
  ///
  /// In en, this message translates to:
  /// **'Packs'**
  String get packs;

  /// No description provided for @shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @joinCode.
  ///
  /// In en, this message translates to:
  /// **'Join code'**
  String get joinCode;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @nextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get nextQuestion;

  /// No description provided for @lockAnswers.
  ///
  /// In en, this message translates to:
  /// **'Lock answers'**
  String get lockAnswers;

  /// No description provided for @revealAnswer.
  ///
  /// In en, this message translates to:
  /// **'Reveal answer'**
  String get revealAnswer;

  /// Title of final question screen
  ///
  /// In en, this message translates to:
  /// **'Final question — wager 0, 10 or 20'**
  String get finalWagerTitle;

  /// No description provided for @packOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get packOfficial;

  /// No description provided for @packMine.
  ///
  /// In en, this message translates to:
  /// **'My pack'**
  String get packMine;

  /// No description provided for @packPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get packPremium;

  /// No description provided for @packLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get packLocked;

  /// No description provided for @packComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get packComingSoon;

  /// No description provided for @packRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get packRetry;

  /// No description provided for @packLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load'**
  String get packLoadError;

  /// No description provided for @packEmpty.
  ///
  /// In en, this message translates to:
  /// **'No packs available'**
  String get packEmpty;

  /// No description provided for @packChoosePack.
  ///
  /// In en, this message translates to:
  /// **'Choose a pack'**
  String get packChoosePack;

  /// No description provided for @packNoAccessiblePack.
  ///
  /// In en, this message translates to:
  /// **'No accessible pack to create a game'**
  String get packNoAccessiblePack;

  /// No description provided for @packPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get packPreview;

  /// No description provided for @packCreate.
  ///
  /// In en, this message translates to:
  /// **'Create a pack'**
  String get packCreate;

  /// No description provided for @packEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get packEdit;

  /// No description provided for @editorSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editorSave;

  /// No description provided for @editorSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get editorSaved;

  /// No description provided for @editorTitleFr.
  ///
  /// In en, this message translates to:
  /// **'Title FR'**
  String get editorTitleFr;

  /// No description provided for @editorTitleEn.
  ///
  /// In en, this message translates to:
  /// **'Title EN'**
  String get editorTitleEn;

  /// No description provided for @editorDescFr.
  ///
  /// In en, this message translates to:
  /// **'Description FR'**
  String get editorDescFr;

  /// No description provided for @editorDescEn.
  ///
  /// In en, this message translates to:
  /// **'Description EN'**
  String get editorDescEn;

  /// No description provided for @editorQuestionFr.
  ///
  /// In en, this message translates to:
  /// **'Question FR'**
  String get editorQuestionFr;

  /// No description provided for @editorQuestionEn.
  ///
  /// In en, this message translates to:
  /// **'Question EN'**
  String get editorQuestionEn;

  /// No description provided for @editorAnswerFr.
  ///
  /// In en, this message translates to:
  /// **'Answer FR'**
  String get editorAnswerFr;

  /// No description provided for @editorAnswerEn.
  ///
  /// In en, this message translates to:
  /// **'Answer EN'**
  String get editorAnswerEn;

  /// No description provided for @editorAliasesFr.
  ///
  /// In en, this message translates to:
  /// **'Aliases FR (one per line)'**
  String get editorAliasesFr;

  /// No description provided for @editorAliasesEn.
  ///
  /// In en, this message translates to:
  /// **'Aliases EN (one per line)'**
  String get editorAliasesEn;

  /// No description provided for @editorCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get editorCategory;

  /// No description provided for @editorDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get editorDifficulty;

  /// No description provided for @editorExact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get editorExact;

  /// No description provided for @editorFuzzy.
  ///
  /// In en, this message translates to:
  /// **'Fuzzy'**
  String get editorFuzzy;

  /// No description provided for @editorNumericExactNote.
  ///
  /// In en, this message translates to:
  /// **'Numeric answers are evaluated exactly.'**
  String get editorNumericExactNote;

  /// No description provided for @editorAddQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add question'**
  String get editorAddQuestion;

  /// No description provided for @editorRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get editorRemove;

  /// No description provided for @editorMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get editorMoveUp;

  /// No description provided for @editorMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get editorMoveDown;

  /// No description provided for @editorTerms.
  ///
  /// In en, this message translates to:
  /// **'I accept the content creation terms'**
  String get editorTerms;

  /// No description provided for @editorTermsAccepted.
  ///
  /// In en, this message translates to:
  /// **'Terms already accepted'**
  String get editorTermsAccepted;

  /// No description provided for @editorShareCode.
  ///
  /// In en, this message translates to:
  /// **'Share code'**
  String get editorShareCode;

  /// No description provided for @editorCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get editorCopyCode;

  /// No description provided for @editorCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get editorCodeCopied;

  /// No description provided for @editorFixErrors.
  ///
  /// In en, this message translates to:
  /// **'Fix the invalid fields'**
  String get editorFixErrors;

  /// No description provided for @editorQuestions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get editorQuestions;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

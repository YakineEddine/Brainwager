import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
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
    Locale('ar'),
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

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @joinCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Code (4-6)'**
  String get joinCodeHint;

  /// No description provided for @gameTitle.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get gameTitle;

  /// No description provided for @waitingForHost.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host to start…'**
  String get waitingForHost;

  /// No description provided for @answerHint.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get answerHint;

  /// No description provided for @submitAnswer.
  ///
  /// In en, this message translates to:
  /// **'Submit (answer + wager)'**
  String get submitAnswer;

  /// No description provided for @answerSaved.
  ///
  /// In en, this message translates to:
  /// **'Answer saved'**
  String get answerSaved;

  /// No description provided for @answerEdited.
  ///
  /// In en, this message translates to:
  /// **'Answer edited — resubmit to save'**
  String get answerEdited;

  /// No description provided for @wagerAmount.
  ///
  /// In en, this message translates to:
  /// **'Wager {amount}'**
  String wagerAmount(Object amount);

  /// No description provided for @playerCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get playerCorrect;

  /// No description provided for @playerIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get playerIncorrect;

  /// No description provided for @hostStartNext.
  ///
  /// In en, this message translates to:
  /// **'Start / Next question'**
  String get hostStartNext;

  /// No description provided for @hostLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get hostLock;

  /// No description provided for @hostLockLate.
  ///
  /// In en, this message translates to:
  /// **'Lock (after timer)'**
  String get hostLockLate;

  /// No description provided for @hostBoard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get hostBoard;

  /// No description provided for @hostNext.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get hostNext;

  /// No description provided for @hostFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get hostFinish;

  /// No description provided for @gameStart.
  ///
  /// In en, this message translates to:
  /// **'Start the game'**
  String get gameStart;

  /// No description provided for @correctAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer:'**
  String get correctAnswer;

  /// No description provided for @onlineCount.
  ///
  /// In en, this message translates to:
  /// **'Online: {count}'**
  String onlineCount(Object count);

  /// No description provided for @playersCount.
  ///
  /// In en, this message translates to:
  /// **'Players: {count} / {max}'**
  String playersCount(Object count, Object max);

  /// No description provided for @minPlayersHint.
  ///
  /// In en, this message translates to:
  /// **'Players: {count} / {max} — minimum {min}'**
  String minPlayersHint(Object count, Object max, Object min);

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// No description provided for @loadingWagers.
  ///
  /// In en, this message translates to:
  /// **'Loading wagers…'**
  String get loadingWagers;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @statusLobby.
  ///
  /// In en, this message translates to:
  /// **'Lobby'**
  String get statusLobby;

  /// No description provided for @statusQuestionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open question'**
  String get statusQuestionOpen;

  /// No description provided for @statusQuestionLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked question'**
  String get statusQuestionLocked;

  /// No description provided for @statusReveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get statusReveal;

  /// No description provided for @statusLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get statusLeaderboard;

  /// No description provided for @statusFinalWager.
  ///
  /// In en, this message translates to:
  /// **'Final wager'**
  String get statusFinalWager;

  /// No description provided for @statusFinalReveal.
  ///
  /// In en, this message translates to:
  /// **'Final reveal'**
  String get statusFinalReveal;

  /// No description provided for @statusFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get statusFinished;

  /// No description provided for @gameLanguage.
  ///
  /// In en, this message translates to:
  /// **'Game language'**
  String get gameLanguage;

  /// No description provided for @editorTitleAr.
  ///
  /// In en, this message translates to:
  /// **'Title AR'**
  String get editorTitleAr;

  /// No description provided for @editorDescAr.
  ///
  /// In en, this message translates to:
  /// **'Description AR'**
  String get editorDescAr;

  /// No description provided for @editorQuestionAr.
  ///
  /// In en, this message translates to:
  /// **'Question AR'**
  String get editorQuestionAr;

  /// No description provided for @editorAnswerAr.
  ///
  /// In en, this message translates to:
  /// **'Answer AR'**
  String get editorAnswerAr;

  /// No description provided for @editorAliasesAr.
  ///
  /// In en, this message translates to:
  /// **'Aliases AR (one per line)'**
  String get editorAliasesAr;

  /// No description provided for @bootstrapErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Brainwager could not start.'**
  String get bootstrapErrorTitle;

  /// No description provided for @packImport.
  ///
  /// In en, this message translates to:
  /// **'Import a pack'**
  String get packImport;

  /// No description provided for @packShareCode.
  ///
  /// In en, this message translates to:
  /// **'Share code'**
  String get packShareCode;

  /// No description provided for @packOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get packOpen;

  /// No description provided for @sharedPack.
  ///
  /// In en, this message translates to:
  /// **'Shared pack'**
  String get sharedPack;

  /// No description provided for @packCreateWith.
  ///
  /// In en, this message translates to:
  /// **'Create a game with this pack'**
  String get packCreateWith;

  /// No description provided for @copyShareLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyShareLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @packReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get packReport;

  /// No description provided for @reportPackTitle.
  ///
  /// In en, this message translates to:
  /// **'Report pack'**
  String get reportPackTitle;

  /// No description provided for @reportReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reportReason;

  /// No description provided for @reportCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get reportCancel;

  /// No description provided for @reportSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get reportSend;

  /// No description provided for @reportClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get reportClose;

  /// No description provided for @packReported.
  ///
  /// In en, this message translates to:
  /// **'Pack reported'**
  String get packReported;

  /// No description provided for @reportUpdated.
  ///
  /// In en, this message translates to:
  /// **'Report updated'**
  String get reportUpdated;

  /// No description provided for @invalidShareCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code (PK-XXXX format)'**
  String get invalidShareCode;

  /// No description provided for @shopBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get shopBuy;

  /// No description provided for @shopBuyWithPrice.
  ///
  /// In en, this message translates to:
  /// **'Buy · {price}'**
  String shopBuyWithPrice(Object price);

  /// No description provided for @shopRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get shopRestorePurchases;

  /// No description provided for @shopRefreshPurchases.
  ///
  /// In en, this message translates to:
  /// **'Refresh purchases'**
  String get shopRefreshPurchases;

  /// No description provided for @shopOwned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get shopOwned;

  /// No description provided for @shopPurchasing.
  ///
  /// In en, this message translates to:
  /// **'Purchasing…'**
  String get shopPurchasing;

  /// No description provided for @shopPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get shopPending;

  /// No description provided for @shopSuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchase verified'**
  String get shopSuccess;

  /// No description provided for @shopBackendUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Purchases temporarily unavailable'**
  String get shopBackendUnavailable;

  /// No description provided for @shopPlayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Play Store unavailable'**
  String get shopPlayUnavailable;

  /// No description provided for @shopUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Purchases available on Android only'**
  String get shopUnsupported;

  /// No description provided for @shopNoProducts.
  ///
  /// In en, this message translates to:
  /// **'No products configured'**
  String get shopNoProducts;

  /// No description provided for @shopRemoveAds.
  ///
  /// In en, this message translates to:
  /// **'Remove ads'**
  String get shopRemoveAds;

  /// No description provided for @shopCanceled.
  ///
  /// In en, this message translates to:
  /// **'Purchase canceled'**
  String get shopCanceled;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navPacks.
  ///
  /// In en, this message translates to:
  /// **'Packs'**
  String get navPacks;

  /// No description provided for @navShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get navShop;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get profileGuest;

  /// No description provided for @profileAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Signed in anonymously'**
  String get profileAnonymous;

  /// No description provided for @profileDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profileDisplayName;

  /// No description provided for @profileLocale.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLocale;

  /// No description provided for @profileComingSoon.
  ///
  /// In en, this message translates to:
  /// **'More account options coming soon'**
  String get profileComingSoon;

  /// No description provided for @profileAvatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get profileAvatar;
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
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
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

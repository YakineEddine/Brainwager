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

  @override
  String get packOfficial => 'Official';

  @override
  String get packMine => 'My pack';

  @override
  String get packPremium => 'Premium';

  @override
  String get packLocked => 'Locked';

  @override
  String get packComingSoon => 'Coming soon';

  @override
  String get packRetry => 'Retry';

  @override
  String get packLoadError => 'Could not load';

  @override
  String get packEmpty => 'No packs available';

  @override
  String get packChoosePack => 'Choose a pack';

  @override
  String get packNoAccessiblePack => 'No accessible pack to create a game';

  @override
  String get packPreview => 'Preview';

  @override
  String get packCreate => 'Create a pack';

  @override
  String get packEdit => 'Edit';

  @override
  String get editorSave => 'Save';

  @override
  String get editorSaved => 'Saved';

  @override
  String get editorTitleFr => 'Title FR';

  @override
  String get editorTitleEn => 'Title EN';

  @override
  String get editorDescFr => 'Description FR';

  @override
  String get editorDescEn => 'Description EN';

  @override
  String get editorQuestionFr => 'Question FR';

  @override
  String get editorQuestionEn => 'Question EN';

  @override
  String get editorAnswerFr => 'Answer FR';

  @override
  String get editorAnswerEn => 'Answer EN';

  @override
  String get editorAliasesFr => 'Aliases FR (one per line)';

  @override
  String get editorAliasesEn => 'Aliases EN (one per line)';

  @override
  String get editorCategory => 'Category';

  @override
  String get editorDifficulty => 'Difficulty';

  @override
  String get editorExact => 'Exact';

  @override
  String get editorFuzzy => 'Fuzzy';

  @override
  String get editorNumericExactNote => 'Numeric answers are evaluated exactly.';

  @override
  String get editorAddQuestion => 'Add question';

  @override
  String get editorRemove => 'Remove';

  @override
  String get editorMoveUp => 'Move up';

  @override
  String get editorMoveDown => 'Move down';

  @override
  String get editorTerms => 'I accept the content creation terms';

  @override
  String get editorTermsAccepted => 'Terms already accepted';

  @override
  String get editorShareCode => 'Share code';

  @override
  String get editorCopyCode => 'Copy code';

  @override
  String get editorCodeCopied => 'Code copied';

  @override
  String get editorFixErrors => 'Fix the invalid fields';

  @override
  String get editorQuestions => 'Questions';

  @override
  String get create => 'Create';

  @override
  String get joinCodeHint => 'Code (4-6)';

  @override
  String get gameTitle => 'Game';

  @override
  String get waitingForHost => 'Waiting for the host to start…';

  @override
  String get answerHint => 'Your answer';

  @override
  String get submitAnswer => 'Submit (answer + wager)';

  @override
  String get answerSaved => 'Answer saved';

  @override
  String get hostStartNext => 'Start / Next question';

  @override
  String get hostLock => 'Lock';

  @override
  String get hostLockLate => 'Lock (after timer)';

  @override
  String get hostBoard => 'Leaderboard';

  @override
  String get hostNext => 'Next question';

  @override
  String get hostFinish => 'Finish';

  @override
  String get gameStart => 'Start the game';

  @override
  String get correctAnswer => 'Correct answer:';

  @override
  String onlineCount(Object count) {
    return 'Online: $count';
  }

  @override
  String playersCount(Object count, Object max) {
    return 'Players: $count / $max';
  }

  @override
  String minPlayersHint(Object count, Object max, Object min) {
    return 'Players: $count / $max — minimum $min';
  }

  @override
  String get copyCode => 'Copy code';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get loadingWagers => 'Loading wagers…';

  @override
  String get back => 'Back';

  @override
  String get statusLobby => 'Lobby';

  @override
  String get statusQuestionOpen => 'Open question';

  @override
  String get statusQuestionLocked => 'Locked question';

  @override
  String get statusReveal => 'Reveal';

  @override
  String get statusLeaderboard => 'Leaderboard';

  @override
  String get statusFinalWager => 'Final wager';

  @override
  String get statusFinalReveal => 'Final reveal';

  @override
  String get statusFinished => 'Finished';

  @override
  String get gameLanguage => 'Game language';

  @override
  String get editorTitleAr => 'Title AR';

  @override
  String get editorDescAr => 'Description AR';

  @override
  String get editorQuestionAr => 'Question AR';

  @override
  String get editorAnswerAr => 'Answer AR';

  @override
  String get editorAliasesAr => 'Aliases AR (one per line)';

  @override
  String get bootstrapErrorTitle => 'Brainwager could not start.';

  @override
  String get packImport => 'Import a pack';

  @override
  String get packShareCode => 'Share code';

  @override
  String get packOpen => 'Open';

  @override
  String get sharedPack => 'Shared pack';

  @override
  String get packCreateWith => 'Create a game with this pack';

  @override
  String get copyShareLink => 'Copy link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get packReport => 'Report';

  @override
  String get reportPackTitle => 'Report pack';

  @override
  String get reportReason => 'Reason';

  @override
  String get reportCancel => 'Cancel';

  @override
  String get reportSend => 'Send';

  @override
  String get packReported => 'Pack reported';

  @override
  String get reportUpdated => 'Report updated';

  @override
  String get invalidShareCode => 'Invalid code (PK-XXXX format)';
}

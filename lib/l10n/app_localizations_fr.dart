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

  @override
  String get packCreate => 'Créer un pack';

  @override
  String get packEdit => 'Modifier';

  @override
  String get editorSave => 'Enregistrer';

  @override
  String get editorSaved => 'Enregistré';

  @override
  String get editorTitleFr => 'Titre FR';

  @override
  String get editorTitleEn => 'Titre EN';

  @override
  String get editorDescFr => 'Description FR';

  @override
  String get editorDescEn => 'Description EN';

  @override
  String get editorQuestionFr => 'Question FR';

  @override
  String get editorQuestionEn => 'Question EN';

  @override
  String get editorAnswerFr => 'Réponse FR';

  @override
  String get editorAnswerEn => 'Réponse EN';

  @override
  String get editorAliasesFr => 'Alias FR (un par ligne)';

  @override
  String get editorAliasesEn => 'Alias EN (un par ligne)';

  @override
  String get editorCategory => 'Catégorie';

  @override
  String get editorDifficulty => 'Difficulté';

  @override
  String get editorExact => 'Exact';

  @override
  String get editorFuzzy => 'Flou';

  @override
  String get editorNumericExactNote =>
      'Réponses numériques : évaluation exacte.';

  @override
  String get editorAddQuestion => 'Ajouter une question';

  @override
  String get editorRemove => 'Retirer';

  @override
  String get editorMoveUp => 'Monter';

  @override
  String get editorMoveDown => 'Descendre';

  @override
  String get editorTerms => 'J’accepte les CGU de création de contenu';

  @override
  String get editorTermsAccepted => 'CGU déjà acceptées';

  @override
  String get editorShareCode => 'Code de partage';

  @override
  String get editorCopyCode => 'Copier le code';

  @override
  String get editorCodeCopied => 'Code copié';

  @override
  String get editorFixErrors => 'Corrigez les champs en erreur';

  @override
  String get editorQuestions => 'Questions';

  @override
  String get create => 'Créer';

  @override
  String get joinCodeHint => 'Code (4-6)';

  @override
  String get gameTitle => 'Partie';

  @override
  String get waitingForHost => 'En attente du lancement par l’hôte…';

  @override
  String get answerHint => 'Ta réponse';

  @override
  String get submitAnswer => 'Valider (réponse + mise)';

  @override
  String get answerSaved => 'Réponse enregistrée';

  @override
  String get hostStartNext => 'Démarrer / Question suivante';

  @override
  String get hostLock => 'Verrouiller';

  @override
  String get hostLockLate => 'Verrouiller (après timer)';

  @override
  String get hostBoard => 'Classement';

  @override
  String get hostNext => 'Question suivante';

  @override
  String get hostFinish => 'Terminer';

  @override
  String get gameStart => 'Démarrer la partie';

  @override
  String get correctAnswer => 'Bonne réponse :';

  @override
  String onlineCount(Object count) {
    return 'En ligne : $count';
  }

  @override
  String playersCount(Object count, Object max) {
    return 'Joueurs : $count / $max';
  }

  @override
  String minPlayersHint(Object count, Object max, Object min) {
    return 'Joueurs : $count / $max — minimum $min';
  }

  @override
  String get copyCode => 'Copier le code';

  @override
  String get codeCopied => 'Code copié';

  @override
  String get loadingWagers => 'Chargement des mises…';

  @override
  String get back => 'Retour';

  @override
  String get statusLobby => 'Salon';

  @override
  String get statusQuestionOpen => 'Question ouverte';

  @override
  String get statusQuestionLocked => 'Question verrouillée';

  @override
  String get statusReveal => 'Révélation';

  @override
  String get statusLeaderboard => 'Classement';

  @override
  String get statusFinalWager => 'Mise finale';

  @override
  String get statusFinalReveal => 'Révélation finale';

  @override
  String get statusFinished => 'Terminée';

  @override
  String get gameLanguage => 'Langue de la partie';

  @override
  String get editorTitleAr => 'Titre AR';

  @override
  String get editorDescAr => 'Description AR';

  @override
  String get editorQuestionAr => 'Question AR';

  @override
  String get editorAnswerAr => 'Réponse AR';

  @override
  String get editorAliasesAr => 'Alias AR (un par ligne)';

  @override
  String get bootstrapErrorTitle => 'Brainwager ne peut pas démarrer.';
}

// Règles configurables Brainwager (doc 04). Source de vérité côté client.
// Le serveur (SQL) applique les mêmes bornes via CHECK + contraintes uniques.
enum TeamScoringMode { sum, average }

class FuzzyThresholds {
  final int tiny;
  final int short;
  final int long;
  const FuzzyThresholds({this.tiny = 1, this.short = 2, this.long = 3});
}

class GameConfig {
  final int totalQuestions;
  final int finalQuestionIndex;
  final List<int> normalWagers;
  final List<int> finalWagers;
  final int defaultDurationSec;
  final int lockGraceSec;
  final int hostTimeoutSec;
  final int minPlayers;
  final int maxPlayers;
  final bool allowNegativeFinal;
  final int joinCodeLength;
  final int serverOffsetSamples;
  final int packPreviewCount;
  final TeamScoringMode teamScoring;
  final FuzzyThresholds fuzzy;

  const GameConfig({
    this.totalQuestions = 11,
    this.finalQuestionIndex = 10,
    this.normalWagers = const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    this.finalWagers = const [0, 10, 20],
    this.defaultDurationSec = 30,
    this.lockGraceSec = 2,
    this.hostTimeoutSec = 60,
    this.minPlayers = 2,
    this.maxPlayers = 50,
    this.allowNegativeFinal = true,
    this.joinCodeLength = 5,
    this.serverOffsetSamples = 3,
    this.packPreviewCount = 3,
    this.teamScoring = TeamScoringMode.average,
    this.fuzzy = const FuzzyThresholds(),
  });

  bool get isFinalIndexValid =>
      finalQuestionIndex == totalQuestions - 1;

  GameConfig copyWith({
    int? totalQuestions,
    int? finalQuestionIndex,
    List<int>? normalWagers,
    List<int>? finalWagers,
    int? defaultDurationSec,
    int? lockGraceSec,
    int? hostTimeoutSec,
    int? minPlayers,
    int? maxPlayers,
    bool? allowNegativeFinal,
    int? joinCodeLength,
    int? serverOffsetSamples,
    int? packPreviewCount,
    TeamScoringMode? teamScoring,
    FuzzyThresholds? fuzzy,
  }) {
    return GameConfig(
      totalQuestions: totalQuestions ?? this.totalQuestions,
      finalQuestionIndex: finalQuestionIndex ?? this.finalQuestionIndex,
      normalWagers: normalWagers ?? this.normalWagers,
      finalWagers: finalWagers ?? this.finalWagers,
      defaultDurationSec: defaultDurationSec ?? this.defaultDurationSec,
      lockGraceSec: lockGraceSec ?? this.lockGraceSec,
      hostTimeoutSec: hostTimeoutSec ?? this.hostTimeoutSec,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      allowNegativeFinal: allowNegativeFinal ?? this.allowNegativeFinal,
      joinCodeLength: joinCodeLength ?? this.joinCodeLength,
      serverOffsetSamples: serverOffsetSamples ?? this.serverOffsetSamples,
      packPreviewCount: packPreviewCount ?? this.packPreviewCount,
      teamScoring: teamScoring ?? this.teamScoring,
      fuzzy: fuzzy ?? this.fuzzy,
    );
  }
}

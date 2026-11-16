import '../../domain/entities/leaderboard_entry.dart';

class DailyChallengeModel extends DailyChallenge {
  const DailyChallengeModel({
    required super.dateKey,
    required super.boardString,
    required super.optimalMoves,
    super.isCompleted = false,
    super.userMoves,
    super.scoreSubmitted = false,
  });

  factory DailyChallengeModel.fromSupabaseJson(Map<String, dynamic> json) {
    return DailyChallengeModel(
      dateKey: (json['challenge_date'] as String?) ?? '',
      boardString: (json['board_string'] as String?) ?? '',
      optimalMoves: (json['optimal_moves'] as num?)?.toInt() ?? 10,
    );
  }

  factory DailyChallengeModel.fromCacheMap(Map<String, dynamic> map) {
    return DailyChallengeModel(
      dateKey: (map['date_key'] as String?) ?? '',
      boardString: (map['board_string'] as String?) ?? '',
      optimalMoves: (map['optimal_moves'] as num?)?.toInt() ?? 10,
      isCompleted: ((map['is_completed'] as num?)?.toInt() ?? 0) == 1,
      userMoves: (map['user_moves'] as num?)?.toInt(),
      scoreSubmitted: ((map['score_submitted'] as num?)?.toInt() ?? 0) == 1,
    );
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'date_key': dateKey,
      'board_string': boardString,
      'optimal_moves': optimalMoves,
      'is_completed': isCompleted ? 1 : 0,
      'user_moves': userMoves,
      'score_submitted': scoreSubmitted ? 1 : 0,
    };
  }
}

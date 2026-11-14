import '../../domain/entities/leaderboard_entry.dart';

class ScoreModel extends LeaderboardEntry {
  const ScoreModel({
    super.id,
    required super.playerName,
    required super.challengeDate,
    required super.movesCount,
    super.createdAt,
  });

  factory ScoreModel.fromJson(Map<String, dynamic> json) {
    return ScoreModel(
      id: json['id']?.toString(),
      playerName: (json['player_name'] as String?) ?? 'Anonymous',
      challengeDate: (json['challenge_date'] as String?) ?? '',
      movesCount: (json['moves_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toSubmissionJson() {
    return {
      'player_name': playerName,
      'challenge_date': challengeDate,
      'moves_count': movesCount,
    };
  }
}

class DailyChallengeModel extends DailyChallenge {
  const DailyChallengeModel({
    required super.dateKey,
    required super.boardString,
    required super.optimalMoves,
    super.isCompleted = false,
    super.userMoves,
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
      dateKey: map['date_key'] as String,
      boardString: map['board_string'] as String,
      optimalMoves: map['optimal_moves'] as int,
      isCompleted: ((map['is_completed'] as int?) ?? 0) == 1,
      userMoves: map['user_moves'] as int?,
    );
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'date_key': dateKey,
      'board_string': boardString,
      'optimal_moves': optimalMoves,
      'is_completed': isCompleted ? 1 : 0,
      'user_moves': userMoves,
    };
  }
}

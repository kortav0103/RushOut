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

import '../../core/error/exceptions.dart';
import '../../domain/entities/leaderboard_entry.dart';

class ScoreModel extends LeaderboardEntry {
  static final RegExp _isoDateRegex = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final String? userId;

  const ScoreModel({
    super.id,
    this.userId,
    required super.playerName,
    required super.challengeDate,
    required super.movesCount,
    super.createdAt,
  });

  static bool isValidChallengeDate(String value) {
    final match = _isoDateRegex.firstMatch(value);
    if (match == null) return false;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return false;
    final dt = DateTime.utc(year, month, day);
    return dt.year == year && dt.month == month && dt.day == day;
  }

  factory ScoreModel.fromJson(Map<String, dynamic> json) {
    final rawName = json['player_name'];
    if (rawName is! String || rawName.trim().isEmpty) {
      throw const ServerException(
        'Invalid leaderboard entry: missing player name.',
      );
    }

    final rawDate = json['challenge_date'];
    if (rawDate is! String || !isValidChallengeDate(rawDate.trim())) {
      throw const ServerException(
        'Invalid leaderboard entry: invalid challenge date.',
      );
    }

    final rawMoves = json['moves_count'];
    if (rawMoves is! num ||
        rawMoves.isNaN ||
        rawMoves.isInfinite ||
        rawMoves != rawMoves.truncateToDouble() ||
        rawMoves.toInt() < 1) {
      throw const ServerException(
        'Invalid leaderboard entry: moves count must be at least 1.',
      );
    }

    DateTime? parsedCreatedAt;
    final rawCreatedAt = json['created_at'];
    if (rawCreatedAt != null) {
      if (rawCreatedAt is! String) {
        throw const ServerException(
          'Invalid leaderboard entry: invalid created_at timestamp.',
        );
      }
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt.trim());
      if (parsedCreatedAt == null) {
        throw const ServerException(
          'Invalid leaderboard entry: invalid created_at timestamp.',
        );
      }
    }

    final rawId = json['id']?.toString().trim();
    final rawUserId = json['user_id']?.toString().trim();

    return ScoreModel(
      id: (rawId != null && rawId.isNotEmpty) ? rawId : null,
      userId: (rawUserId != null && rawUserId.isNotEmpty) ? rawUserId : null,
      playerName: rawName.trim(),
      challengeDate: rawDate.trim(),
      movesCount: rawMoves.toInt(),
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toSubmissionJson() {
    return {
      'player_name': playerName,
      'challenge_date': challengeDate,
      'moves_count': movesCount,
    };
  }

  @override
  List<Object?> get props => [...super.props, userId];
}

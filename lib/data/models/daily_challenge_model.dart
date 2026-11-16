import 'dart:convert';
import '../../core/error/exceptions.dart';
import '../../core/utils/level_parser.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/move.dart';

class DailyChallengeModel extends DailyChallenge {
  static final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  const DailyChallengeModel({
    required super.dateKey,
    required super.boardString,
    required super.optimalMoves,
    super.isCompleted = false,
    super.userMoves,
    super.solvedBoardString,
    super.bestMoveHistory = const [],
    super.scoreSubmitted = false,
    super.submittedMoves,
    super.submittedPlayerName,
  });

  factory DailyChallengeModel.fromEntity(DailyChallenge entity) {
    return DailyChallengeModel(
      dateKey: entity.dateKey,
      boardString: entity.boardString,
      optimalMoves: entity.optimalMoves,
      isCompleted: entity.isCompleted,
      userMoves: entity.userMoves,
      solvedBoardString: entity.solvedBoardString,
      bestMoveHistory: entity.bestMoveHistory,
      scoreSubmitted: entity.scoreSubmitted,
      submittedMoves: entity.submittedMoves,
      submittedPlayerName: entity.submittedPlayerName,
    );
  }

  /// Strictly parses a Supabase `daily_challenges` row.
  /// Throws [ServerException] if required fields are missing or malformed.
  factory DailyChallengeModel.fromSupabaseJson(Map<String, dynamic> json) {
    final rawDate = json['challenge_date'];
    if (rawDate is! String || !_datePattern.hasMatch(rawDate.trim())) {
      throw const ServerException(
        'Daily Challenge payload from server is missing a valid challenge_date.',
      );
    }

    final rawBoard = json['board_string'];
    if (rawBoard is! String || rawBoard.trim().isEmpty) {
      throw const ServerException(
        'Daily Challenge payload from server is missing board_string.',
      );
    }
    final boardString = rawBoard.trim();
    try {
      LevelParser.parseBoardString(boardString);
    } on LevelParseException catch (e) {
      throw ServerException(
        'Daily Challenge board from server is invalid: ${e.message}',
      );
    }

    final rawOptimal = json['optimal_moves'];
    final optimalMoves = rawOptimal is num ? rawOptimal.toInt() : null;
    if (optimalMoves == null || optimalMoves <= 0) {
      throw const ServerException(
        'Daily Challenge payload from server is missing a valid optimal_moves (> 0).',
      );
    }

    return DailyChallengeModel(
      dateKey: rawDate.trim(),
      boardString: boardString,
      optimalMoves: optimalMoves,
    );
  }

  /// Parses a cached SQLite `daily_cache` row.
  /// Throws [CacheException] if core fields are missing or corrupted.
  factory DailyChallengeModel.fromCacheMap(Map<String, dynamic> map) {
    final rawDate = map['date_key'];
    if (rawDate is! String || rawDate.trim().isEmpty) {
      throw const CacheException('Cached daily challenge is missing date_key.');
    }

    final rawBoard = map['board_string'];
    if (rawBoard is! String || rawBoard.trim().isEmpty) {
      throw const CacheException(
        'Cached daily challenge is missing board_string.',
      );
    }

    final rawOptimal = map['optimal_moves'];
    final optimalMoves = rawOptimal is num ? rawOptimal.toInt() : null;
    if (optimalMoves == null || optimalMoves <= 0) {
      throw const CacheException(
        'Cached daily challenge has invalid optimal_moves.',
      );
    }

    final rawSolvedBoard = map['solved_board_string'] as String?;
    final solvedBoardString =
        (rawSolvedBoard != null && rawSolvedBoard.trim().isNotEmpty)
            ? rawSolvedBoard.trim()
            : null;

    final moveHistory = _decodeMoveHistory(map['best_move_history']);
    final userMovesRaw = (map['user_moves'] as num?)?.toInt();
    final submittedMovesRaw = (map['submitted_moves'] as num?)?.toInt();
    final rawSubmittedName = map['submitted_player_name'] as String?;
    final submittedPlayerName =
        (rawSubmittedName != null && rawSubmittedName.trim().isNotEmpty)
            ? rawSubmittedName.trim()
            : null;

    return DailyChallengeModel(
      dateKey: rawDate.trim(),
      boardString: rawBoard.trim(),
      optimalMoves: optimalMoves,
      isCompleted: ((map['is_completed'] as num?)?.toInt() ?? 0) == 1,
      userMoves: (userMovesRaw != null && userMovesRaw > 0)
          ? userMovesRaw
          : null,
      solvedBoardString: solvedBoardString,
      bestMoveHistory: moveHistory,
      scoreSubmitted: ((map['score_submitted'] as num?)?.toInt() ?? 0) == 1,
      submittedMoves: (submittedMovesRaw != null && submittedMovesRaw > 0)
          ? submittedMovesRaw
          : null,
      submittedPlayerName: submittedPlayerName,
    );
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'date_key': dateKey,
      'board_string': boardString,
      'optimal_moves': optimalMoves,
      'is_completed': isCompleted ? 1 : 0,
      'user_moves': userMoves,
      'solved_board_string': solvedBoardString,
      'best_move_history': bestMoveHistory.isEmpty
          ? null
          : jsonEncode(bestMoveHistory.map((m) => m.toJson()).toList()),
      'score_submitted': scoreSubmitted ? 1 : 0,
      'submitted_moves': submittedMoves,
      'submitted_player_name': submittedPlayerName,
    };
  }

  static List<Move> _decodeMoveHistory(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Move.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

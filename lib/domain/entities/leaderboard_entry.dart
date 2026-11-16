import 'package:equatable/equatable.dart';
import 'move.dart';

class LeaderboardEntry extends Equatable {
  final String? id;
  final String playerName;
  final String challengeDate;
  final int movesCount;
  final DateTime? createdAt;

  const LeaderboardEntry({
    this.id,
    required this.playerName,
    required this.challengeDate,
    required this.movesCount,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        playerName,
        challengeDate,
        movesCount,
        createdAt,
      ];
}

class DailyChallenge extends Equatable {
  final String dateKey;
  final String boardString;
  final int optimalMoves;
  final bool isCompleted;
  final int? userMoves;
  final String? solvedBoardString;
  final List<Move> bestMoveHistory;
  final bool scoreSubmitted;
  final int? submittedMoves;
  final String? submittedPlayerName;

  const DailyChallenge({
    required this.dateKey,
    required this.boardString,
    required this.optimalMoves,
    this.isCompleted = false,
    this.userMoves,
    this.solvedBoardString,
    this.bestMoveHistory = const [],
    this.scoreSubmitted = false,
    this.submittedMoves,
    this.submittedPlayerName,
  });

  DailyChallenge copyWith({
    String? dateKey,
    String? boardString,
    int? optimalMoves,
    bool? isCompleted,
    int? userMoves,
    String? solvedBoardString,
    bool clearSolvedBoard = false,
    List<Move>? bestMoveHistory,
    bool? scoreSubmitted,
    int? submittedMoves,
    String? submittedPlayerName,
  }) {
    return DailyChallenge(
      dateKey: dateKey ?? this.dateKey,
      boardString: boardString ?? this.boardString,
      optimalMoves: optimalMoves ?? this.optimalMoves,
      isCompleted: isCompleted ?? this.isCompleted,
      userMoves: userMoves ?? this.userMoves,
      solvedBoardString: clearSolvedBoard
          ? null
          : (solvedBoardString ?? this.solvedBoardString),
      bestMoveHistory: bestMoveHistory ?? this.bestMoveHistory,
      scoreSubmitted: scoreSubmitted ?? this.scoreSubmitted,
      submittedMoves: submittedMoves ?? this.submittedMoves,
      submittedPlayerName: submittedPlayerName ?? this.submittedPlayerName,
    );
  }

  @override
  List<Object?> get props => [
        dateKey,
        boardString,
        optimalMoves,
        isCompleted,
        userMoves,
        solvedBoardString,
        bestMoveHistory,
        scoreSubmitted,
        submittedMoves,
        submittedPlayerName,
      ];
}

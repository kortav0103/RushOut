import 'package:equatable/equatable.dart';

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

  const DailyChallenge({
    required this.dateKey,
    required this.boardString,
    required this.optimalMoves,
    this.isCompleted = false,
    this.userMoves,
  });

  DailyChallenge copyWith({
    String? dateKey,
    String? boardString,
    int? optimalMoves,
    bool? isCompleted,
    int? userMoves,
  }) {
    return DailyChallenge(
      dateKey: dateKey ?? this.dateKey,
      boardString: boardString ?? this.boardString,
      optimalMoves: optimalMoves ?? this.optimalMoves,
      isCompleted: isCompleted ?? this.isCompleted,
      userMoves: userMoves ?? this.userMoves,
    );
  }

  @override
  List<Object?> get props => [
        dateKey,
        boardString,
        optimalMoves,
        isCompleted,
        userMoves,
      ];
}

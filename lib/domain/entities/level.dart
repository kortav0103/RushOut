import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

enum Difficulty {
  easy,
  medium,
  hard;

  String get label {
    switch (this) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
    }
  }

  int get minOptimalMoves {
    switch (this) {
      case Difficulty.easy:
        return AppConstants.easyMinMoves;
      case Difficulty.medium:
        return AppConstants.mediumMinMoves;
      case Difficulty.hard:
        return AppConstants.hardMinMoves;
    }
  }

  int get maxOptimalMoves {
    switch (this) {
      case Difficulty.easy:
        return AppConstants.easyMaxMoves;
      case Difficulty.medium:
        return AppConstants.mediumMaxMoves;
      case Difficulty.hard:
        return AppConstants.hardMaxMoves;
    }
  }

  static Difficulty? fromOptimalMoves(int moves) {
    if (moves >= AppConstants.easyMinMoves &&
        moves <= AppConstants.easyMaxMoves) {
      return Difficulty.easy;
    }
    if (moves >= AppConstants.mediumMinMoves &&
        moves <= AppConstants.mediumMaxMoves) {
      return Difficulty.medium;
    }
    if (moves >= AppConstants.hardMinMoves &&
        moves <= AppConstants.hardMaxMoves) {
      return Difficulty.hard;
    }
    return null;
  }

  static Difficulty fromString(String value) {
    switch (value.toLowerCase()) {
      case 'easy':
        return Difficulty.easy;
      case 'medium':
        return Difficulty.medium;
      case 'hard':
        return Difficulty.hard;
      default:
        return Difficulty.easy;
    }
  }
}

class Level extends Equatable {
  final int id;
  final Difficulty difficulty;
  final int optimalMoves;
  final String boardString;
  final int clusterSize;
  final int? bestMoves;
  final int stars;
  final bool isUnlocked;

  const Level({
    required this.id,
    required this.difficulty,
    required this.optimalMoves,
    required this.boardString,
    this.clusterSize = 0,
    this.bestMoves,
    this.stars = 0,
    this.isUnlocked = false,
  });

  Level copyWith({
    int? id,
    Difficulty? difficulty,
    int? optimalMoves,
    String? boardString,
    int? clusterSize,
    int? bestMoves,
    int? stars,
    bool? isUnlocked,
  }) {
    return Level(
      id: id ?? this.id,
      difficulty: difficulty ?? this.difficulty,
      optimalMoves: optimalMoves ?? this.optimalMoves,
      boardString: boardString ?? this.boardString,
      clusterSize: clusterSize ?? this.clusterSize,
      bestMoves: bestMoves ?? this.bestMoves,
      stars: stars ?? this.stars,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }

  @override
  List<Object?> get props => [
        id,
        difficulty,
        optimalMoves,
        boardString,
        clusterSize,
        bestMoves,
        stars,
        isUnlocked,
      ];
}

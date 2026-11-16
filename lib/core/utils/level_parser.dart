import '../../domain/engine/level_ordering_pipeline.dart';
import '../../domain/entities/board_state.dart';
import '../../domain/entities/level.dart';
import '../../domain/entities/vehicle.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart';

class RawLevelEntry {
  final int optimalMoves;
  final String boardString;
  final int clusterSize;

  const RawLevelEntry({
    required this.optimalMoves,
    required this.boardString,
    this.clusterSize = 0,
  });
}

class LevelParser {
  LevelParser._();

  /// Checks whether a line or board string contains a fixed wall character ('x').
  static bool containsWall(String input) {
    return input.contains('x') || input.contains('X');
  }

  /// Parses a single line from rush1000.txt:
  /// Format: `<optimal_moves> <36_char_board> <cluster_size>`
  /// Returns null if the line is empty, malformed, or contains `'x'` (fixed wall).
  static RawLevelEntry? parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      return null;
    }

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return null;
    }

    final optimalMoves = int.tryParse(parts[0]);
    final boardString = parts[1];
    final clusterSize = parts.length >= 3 ? (int.tryParse(parts[2]) ?? 0) : 0;

    if (optimalMoves == null ||
        boardString.length != AppConstants.boardStringLength) {
      return null;
    }

    // Rule 1: Filter out any line containing 'x' (fixed walls)
    if (containsWall(boardString)) {
      return null;
    }

    return RawLevelEntry(
      optimalMoves: optimalMoves,
      boardString: boardString,
      clusterSize: clusterSize,
    );
  }

  /// Parses a 36-character row-major board string into a list of [Vehicle]s.
  /// Throws [LevelParseException] if the board string is invalid or contains 'x'.
  static List<Vehicle> parseBoardString(String boardString) {
    if (boardString.length != AppConstants.boardStringLength) {
      throw LevelParseException(
        'Board string must be exactly ${AppConstants.boardStringLength} characters, got ${boardString.length}.',
      );
    }

    if (containsWall(boardString)) {
      throw const LevelParseException(
        'Board string contains fixed wall character "x", which is not supported.',
      );
    }

    final Map<String, List<(int, int)>> cellGroups = {};

    for (int i = 0; i < boardString.length; i++) {
      final ch = boardString[i];
      if (ch == AppConstants.emptyCellChar || ch == '.') {
        continue;
      }

      final code = ch.codeUnitAt(0);
      if (code < 65 || code > 90) {
        throw LevelParseException(
          'Invalid character "$ch" at index $i in board string.',
        );
      }

      final row = i ~/ AppConstants.gridSize;
      final col = i % AppConstants.gridSize;
      cellGroups.putIfAbsent(ch, () => []).add((row, col));
    }

    final List<Vehicle> vehicles = [];

    final sortedIds = cellGroups.keys.toList()..sort();
    for (final id in sortedIds) {
      final cells = cellGroups[id]!;
      final length = cells.length;

      if (length != 2 && length != 3) {
        throw LevelParseException(
          'Vehicle "$id" has invalid length $length (must be 2 or 3).',
        );
      }

      final firstRow = cells.first.$1;
      final firstCol = cells.first.$2;

      final allSameRow = cells.every((c) => c.$1 == firstRow);
      final allSameCol = cells.every((c) => c.$2 == firstCol);

      if (!allSameRow && !allSameCol) {
        throw LevelParseException(
          'Vehicle "$id" cells are neither in the same row nor in the same column.',
        );
      }

      if (allSameRow) {
        cells.sort((a, b) => a.$2.compareTo(b.$2));
        for (int k = 1; k < cells.length; k++) {
          if (cells[k].$2 - cells[k - 1].$2 != 1) {
            throw LevelParseException(
              'Vehicle "$id" horizontal cells are not contiguous.',
            );
          }
        }
        vehicles.add(
          Vehicle(
            id: id,
            row: firstRow,
            col: cells.first.$2,
            length: length,
            isHorizontal: true,
          ),
        );
      } else {
        cells.sort((a, b) => a.$1.compareTo(b.$1));
        for (int k = 1; k < cells.length; k++) {
          if (cells[k].$1 - cells[k - 1].$1 != 1) {
            throw LevelParseException(
              'Vehicle "$id" vertical cells are not contiguous.',
            );
          }
        }
        vehicles.add(
          Vehicle(
            id: id,
            row: cells.first.$1,
            col: firstCol,
            length: length,
            isHorizontal: false,
          ),
        );
      }
    }

    return vehicles;
  }

  /// Parses a 36-character board string directly into a [BoardState].
  static BoardState parseToBoardState(
    String boardString, {
    int optimalMoves = 0,
  }) {
    final vehicles = parseBoardString(boardString);
    return BoardState(
      vehicles: vehicles,
      optimalMoves: optimalMoves,
    );
  }

  /// Parses the entire content of `rush1000.txt`, filters out lines with `'x'`,
  /// and extracts 30 campaign levels divided equally into:
  /// - Easy: optimalMoves 5..10 (10 levels, IDs 1..10)
  /// - Medium: optimalMoves 11..18 (10 levels, IDs 11..20)
  /// - Hard: optimalMoves 19..25 (10 levels, IDs 21..30)
  static List<Level> parseCampaignLevels(
    String fileContent, {
    int perDifficulty = AppConstants.levelsPerDifficulty,
  }) {
    final lines = fileContent.split(RegExp(r'\r?\n'));

    final List<RawLevelEntry> easyEntries = [];
    final List<RawLevelEntry> mediumEntries = [];
    final List<RawLevelEntry> hardEntries = [];

    for (final line in lines) {
      final entry = parseLine(line);
      if (entry == null) continue;

      // Ensure the board string itself is valid and has target vehicle 'A'
      try {
        final vehicles = parseBoardString(entry.boardString);
        final hasValidTarget = vehicles.any(
          (v) =>
              v.id == AppConstants.targetVehicleId &&
              v.isHorizontal &&
              v.row == AppConstants.exitRow,
        );
        if (!hasValidTarget) continue;
      } catch (_) {
        continue;
      }

      final difficulty = Difficulty.fromOptimalMoves(entry.optimalMoves);
      if (difficulty == Difficulty.easy && easyEntries.length < perDifficulty) {
        easyEntries.add(entry);
      } else if (difficulty == Difficulty.medium &&
          mediumEntries.length < perDifficulty) {
        mediumEntries.add(entry);
      } else if (difficulty == Difficulty.hard &&
          hardEntries.length < perDifficulty) {
        hardEntries.add(entry);
      }

      if (easyEntries.length >= perDifficulty &&
          mediumEntries.length >= perDifficulty &&
          hardEntries.length >= perDifficulty) {
        break;
      }
    }

    // Sort each bucket by optimalMoves ascending for smooth progression
    easyEntries.sort((a, b) => a.optimalMoves.compareTo(b.optimalMoves));
    mediumEntries.sort((a, b) => a.optimalMoves.compareTo(b.optimalMoves));
    hardEntries.sort((a, b) => a.optimalMoves.compareTo(b.optimalMoves));

    final List<Level> levels = [];
    int nextId = 1;

    for (int i = 0; i < easyEntries.length; i++) {
      final e = easyEntries[i];
      levels.add(
        Level(
          id: nextId++,
          difficulty: Difficulty.easy,
          optimalMoves: e.optimalMoves,
          boardString: e.boardString,
          clusterSize: e.clusterSize,
          isUnlocked: nextId == 2,
        ),
      );
    }

    for (int i = 0; i < mediumEntries.length; i++) {
      final e = mediumEntries[i];
      levels.add(
        Level(
          id: nextId++,
          difficulty: Difficulty.medium,
          optimalMoves: e.optimalMoves,
          boardString: e.boardString,
          clusterSize: e.clusterSize,
          isUnlocked: false,
        ),
      );
    }

    for (int i = 0; i < hardEntries.length; i++) {
      final e = hardEntries[i];
      levels.add(
        Level(
          id: nextId++,
          difficulty: Difficulty.hard,
          optimalMoves: e.optimalMoves,
          boardString: e.boardString,
          clusterSize: e.clusterSize,
          isUnlocked: false,
        ),
      );
    }

    return LevelOrderingPipeline.orderLevels(levels);
  }
}

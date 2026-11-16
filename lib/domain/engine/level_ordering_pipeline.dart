import 'dart:math' as math;
import '../../core/constants/app_constants.dart';
import '../../core/utils/level_parser.dart';
import '../entities/level.dart';

class LevelDifficultyMetrics {
  final int occupiedCells;
  final int initialBlockers;
  final int vehicleCount;
  final double difficultyScore;

  const LevelDifficultyMetrics({
    required this.occupiedCells,
    required this.initialBlockers,
    required this.vehicleCount,
    required this.difficultyScore,
  });

  /// Parses a 36-character 6x6 board string and computes hidden difficulty metrics:
  /// `difficultyScore = (optimalMoves * 10.0) + (occupiedCells * 0.8) + (initialBlockers * 1.5) + (ln(clusterSize + 1) * 2.5)`
  factory LevelDifficultyMetrics.fromBoardString(
    String boardString, {
    required int optimalMoves,
    int clusterSize = 0,
  }) {
    final vehicles = LevelParser.parseBoardString(boardString);

    int occupied = 0;
    int? targetEndCol;
    int targetRow = AppConstants.exitRow;

    for (final v in vehicles) {
      occupied += v.length;
      if (v.isTarget) {
        targetRow = v.row;
        targetEndCol = v.endCol;
      }
    }

    int blockers = 0;
    if (targetEndCol != null) {
      for (final v in vehicles) {
        if (v.isTarget) continue;
        // Intersects the target red car's exit path (to the right of 'A' on its row)
        if (v.row <= targetRow && v.endRow >= targetRow && v.col > targetEndCol) {
          blockers++;
        }
      }
    }

    final clusterWeight =
        clusterSize > 0 ? (math.log(clusterSize + 1) * 2.5) : 0.0;
    final score = (optimalMoves * 10.0) +
        (occupied * 0.8) +
        (blockers * 1.5) +
        clusterWeight;

    return LevelDifficultyMetrics(
      occupiedCells: occupied,
      initialBlockers: blockers,
      vehicleCount: vehicles.length,
      difficultyScore: score,
    );
  }
}

class _IndexedLevel {
  final int originalIndex;
  final Level level;
  final LevelDifficultyMetrics metrics;

  const _IndexedLevel({
    required this.originalIndex,
    required this.level,
    required this.metrics,
  });
}

/// Deterministic 3-zone commercial level ordering pipeline (`#1` to `#4050`):
/// - Levels `#1–#6`: Strict raw easiest sorted by
///   `(optimalMoves, vehicleCount, initialBlockers, originalIndex)` ascending.
/// - Levels `#7–#19`: Slow linear ramp-up (13 lowest `difficultyScore` from remaining).
/// - Levels `#20–#4050`: 10-Level Commercial Sawtooth Wave pacing:
///   Warm-up (`L0, L1, L3`) -> Escalation (`L4..L8`) -> Hard Boss Spike (slot 9) -> Breather (`L2`, slot 10).
class LevelOrderingPipeline {
  LevelOrderingPipeline._();

  static const int rawEasiestCount = 6;
  static const int rampCount = 13;
  static const int microWaveSize = 10;

  static int _compareRawEasiest(_IndexedLevel a, _IndexedLevel b) {
    final movesCmp = a.level.optimalMoves.compareTo(b.level.optimalMoves);
    if (movesCmp != 0) return movesCmp;

    final vehCmp = a.metrics.vehicleCount.compareTo(b.metrics.vehicleCount);
    if (vehCmp != 0) return vehCmp;

    final blockerCmp =
        a.metrics.initialBlockers.compareTo(b.metrics.initialBlockers);
    if (blockerCmp != 0) return blockerCmp;

    return a.originalIndex.compareTo(b.originalIndex);
  }

  static int _compareDifficultyScore(_IndexedLevel a, _IndexedLevel b) {
    final cmp = a.metrics.difficultyScore.compareTo(b.metrics.difficultyScore);
    return cmp != 0 ? cmp : a.originalIndex.compareTo(b.originalIndex);
  }

  static List<Level> orderLevels(
    List<Level> levels, {
    bool reassignSequentialIds = true,
  }) {
    if (levels.isEmpty) return const [];

    final List<_IndexedLevel> indexed = [];
    for (int i = 0; i < levels.length; i++) {
      final level = levels[i];
      final metrics = LevelDifficultyMetrics.fromBoardString(
        level.boardString,
        optimalMoves: level.optimalMoves,
        clusterSize: level.clusterSize,
      );
      indexed.add(
        _IndexedLevel(
          originalIndex: i,
          level: level,
          metrics: metrics,
        ),
      );
    }

    // A. Levels #1 - #6: Strict Raw Easiest (no difficultyScore weighting or shuffling)
    final rawSorted = List<_IndexedLevel>.from(indexed)..sort(_compareRawEasiest);
    final int takeRaw =
        rawSorted.length < rawEasiestCount ? rawSorted.length : rawEasiestCount;
    final List<_IndexedLevel> zone1 = rawSorted.sublist(0, takeRaw);
    final Set<int> pickedIndices = zone1.map((e) => e.originalIndex).toSet();

    // Remaining levels sorted strictly ascending by difficultyScore
    final List<_IndexedLevel> remainingByScore = indexed
        .where((item) => !pickedIndices.contains(item.originalIndex))
        .toList()
      ..sort(_compareDifficultyScore);

    // B. Levels #7 - #19: Slow Linear Ramp-Up (next 13 lowest difficultyScore)
    final int takeRamp = remainingByScore.length < rampCount
        ? remainingByScore.length
        : rampCount;
    final List<_IndexedLevel> zone2 = remainingByScore.sublist(0, takeRamp);

    // C. Levels #20 - #4050: 10-Level Commercial Sawtooth Waves
    // Weave Hard Boss Spikes into slot 9 of each 10-level wave while Easy/Medium levels remain,
    // followed immediately by a lighter Breather level at slot 10.
    final List<_IndexedLevel> remaining = remainingByScore.sublist(takeRamp);
    final List<_IndexedLevel> mainPool = remaining
        .where((e) => e.level.difficulty != Difficulty.hard)
        .toList();
    final List<_IndexedLevel> hardSpikes = remaining
        .where((e) => e.level.difficulty == Difficulty.hard)
        .toList();

    final List<_IndexedLevel> zone3 = [];
    int mainCursor = 0;
    int hardCursor = 0;

    // 1. Commercial waves combining 9 progressive Easy/Medium levels + 1 Hard Boss Spike
    while (mainCursor + 9 <= mainPool.length &&
        hardCursor < hardSpikes.length) {
      final chunk = mainPool.sublist(mainCursor, mainCursor + 9);
      final bossSpike = hardSpikes[hardCursor++];
      mainCursor += 9;

      // Slots 1-3 (Warm-up): chunk[0], chunk[1], chunk[3]
      // Slots 4-8 (Escalation): chunk[4], chunk[5], chunk[6], chunk[7], chunk[8]
      // Slot 9 (Boss Spike): Hard level
      // Slot 10 (Breather): chunk[2]
      zone3.addAll([
        chunk[0],
        chunk[1],
        chunk[3],
        chunk[4],
        chunk[5],
        chunk[6],
        chunk[7],
        chunk[8],
        bossSpike,
        chunk[2],
      ]);
    }

    // 2. Remaining levels continue in 10-level Micro-Waves ([L0, L1, L3..L9, L2])
    final List<_IndexedLevel> tail = [
      ...mainPool.sublist(mainCursor),
      ...hardSpikes.sublist(hardCursor),
    ];
    int tailCursor = 0;
    while (tailCursor + microWaveSize <= tail.length) {
      final chunk = tail.sublist(tailCursor, tailCursor + microWaveSize);
      zone3.addAll([
        chunk[0],
        chunk[1],
        chunk[3],
        chunk[4],
        chunk[5],
        chunk[6],
        chunk[7],
        chunk[8],
        chunk[9],
        chunk[2],
      ]);
      tailCursor += microWaveSize;
    }

    // Trailing remainder (< 10 levels) stays in ascending difficultyScore order
    if (tailCursor < tail.length) {
      zone3.addAll(tail.sublist(tailCursor));
    }

    final combined = [...zone1, ...zone2, ...zone3];

    if (!reassignSequentialIds) {
      return combined.map((e) => e.level).toList();
    }

    return List<Level>.generate(combined.length, (i) {
      final lvl = combined[i].level;
      return lvl.copyWith(
        id: i + 1,
        isUnlocked: i == 0,
      );
    });
  }
}

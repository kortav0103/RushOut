import 'dart:collection';
import 'dart:math' as math;
import '../../core/constants/app_constants.dart';
import '../../core/utils/level_parser.dart';
import '../entities/level.dart';
import '../entities/vehicle.dart';

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
    return LevelDifficultyMetrics.fromVehicles(
      vehicles,
      optimalMoves: optimalMoves,
      clusterSize: clusterSize,
    );
  }

  factory LevelDifficultyMetrics.fromVehicles(
    List<Vehicle> vehicles, {
    required int optimalMoves,
    int clusterSize = 0,
  }) {
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
        if (v.row <= targetRow &&
            v.endRow >= targetRow &&
            v.col > targetEndCol) {
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

/// Compact 36-cell bitmask (split into two 18-bit halves for cross-platform safety)
/// capturing target position (`A`) and horizontal/vertical vehicle occupancy.
class _BoardMask {
  final int aLo;
  final int aHi;
  final int hLo;
  final int hHi;
  final int vLo;
  final int vHi;

  const _BoardMask({
    required this.aLo,
    required this.aHi,
    required this.hLo,
    required this.hHi,
    required this.vLo,
    required this.vHi,
  });

  factory _BoardMask.fromVehicles(List<Vehicle> vehicles) {
    int aLo = 0, aHi = 0, hLo = 0, hHi = 0, vLo = 0, vHi = 0;
    for (final v in vehicles) {
      for (int i = 0; i < v.length; i++) {
        final r = v.isHorizontal ? v.row : v.row + i;
        final c = v.isHorizontal ? v.col + i : v.col;
        final idx = r * AppConstants.gridSize + c;
        if (idx < 18) {
          final bit = 1 << idx;
          if (v.isTarget) {
            aLo |= bit;
          } else if (v.isHorizontal) {
            hLo |= bit;
          } else {
            vLo |= bit;
          }
        } else {
          final bit = 1 << (idx - 18);
          if (v.isTarget) {
            aHi |= bit;
          } else if (v.isHorizontal) {
            hHi |= bit;
          } else {
            vHi |= bit;
          }
        }
      }
    }
    return _BoardMask(
      aLo: aLo,
      aHi: aHi,
      hLo: hLo,
      hHi: hHi,
      vLo: vLo,
      vHi: vHi,
    );
  }

  static int _popcount18(int x) {
    int v = x;
    int count = 0;
    while (v != 0) {
      v &= v - 1;
      count++;
    }
    return count;
  }

  double jaccardSimilarity(_BoardMask other) {
    final same = _popcount18(aLo & other.aLo) +
        _popcount18(aHi & other.aHi) +
        _popcount18(hLo & other.hLo) +
        _popcount18(hHi & other.hHi) +
        _popcount18(vLo & other.vLo) +
        _popcount18(vHi & other.vHi);

    final occLo = aLo | hLo | vLo;
    final occHi = aHi | hHi | vHi;
    final otherOccLo = other.aLo | other.hLo | other.vLo;
    final otherOccHi = other.aHi | other.hHi | other.vHi;

    final union =
        _popcount18(occLo | otherOccLo) + _popcount18(occHi | otherOccHi);
    return union == 0 ? 1.0 : same / union;
  }
}

class _IndexedLevel {
  final int originalIndex;
  final Level level;
  final LevelDifficultyMetrics metrics;
  final _BoardMask mask;

  const _IndexedLevel({
    required this.originalIndex,
    required this.level,
    required this.metrics,
    required this.mask,
  });
}

class _IndexedPool {
  final List<_IndexedLevel> items;
  final List<bool> used;
  int head = 0;

  _IndexedPool(this.items) : used = List<bool>.filled(items.length, false);

  int get remainingCount {
    int count = 0;
    for (int i = head; i < items.length; i++) {
      if (!used[i]) count++;
    }
    return count;
  }

  _IndexedLevel takeAt(int index) {
    used[index] = true;
    while (head < items.length && used[head]) {
      head++;
    }
    return items[index];
  }
}

/// Deterministic 3-zone commercial level ordering pipeline (`#1` to `#4050`)
/// with layout-diversity spacing so near-identical puzzle variants are separated:
/// - Levels `#1–#6`: Strict raw easiest sorted by
///   `(optimalMoves, vehicleCount, initialBlockers)` with distinct board geometries.
/// - Levels `#7–#19`: Slow linear ramp-up (13 ascending `difficultyScore` levels)
///   with distinct board geometries.
/// - Levels `#20–#4050`: 10-Level Commercial Sawtooth Wave pacing:
///   Warm-up (`L0, L1, L3`) -> Escalation (`L4..L8`) -> Hard Boss Spike (slot 9) -> Breather (`L2`, slot 10),
///   spreading near-duplicate puzzle families across a sliding window of 55 levels.
class LevelOrderingPipeline {
  LevelOrderingPipeline._();

  static const int rawEasiestCount = 6;
  static const int rampCount = 13;
  static const int microWaveSize = 10;
  static const double _similarityThreshold = 0.60;
  static const int _diversityWindow = 55;
  static const int _zone3Lookahead = 500;

  /// Computes structural Jaccard similarity (`0.0..1.0`) between two 36-char boards
  /// based on target car position and horizontal/vertical vehicle occupancy.
  static double boardSimilarity(String boardA, String boardB) {
    final maskA = _BoardMask.fromVehicles(LevelParser.parseBoardString(boardA));
    final maskB = _BoardMask.fromVehicles(LevelParser.parseBoardString(boardB));
    return maskA.jaccardSimilarity(maskB);
  }

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

  static double _maxSimilarityInWindow(
    _BoardMask candidate,
    Iterable<_BoardMask> recentMasks,
  ) {
    double best = 0.0;
    for (final recent in recentMasks) {
      final sim = candidate.jaccardSimilarity(recent);
      if (sim > best) {
        best = sim;
      }
    }
    return best;
  }

  static void _pushWindow(Queue<_BoardMask> window, _BoardMask mask) {
    window.addLast(mask);
    while (window.length > _diversityWindow) {
      window.removeFirst();
    }
  }

  static _IndexedLevel _pickDiverse(
    _IndexedPool pool,
    Iterable<_BoardMask> recentMasks, {
    required int lookahead,
    double? minScore,
    _IndexedLevel? minRawFloor,
    bool lockToHeadRawBucket = false,
  }) {
    int bestIndex = -1;
    double bestSimilarity = 2.0;
    int scanned = 0;

    final headItem = pool.head < pool.items.length ? pool.items[pool.head] : null;

    for (int i = pool.head; i < pool.items.length; i++) {
      if (pool.used[i]) continue;
      final candidate = pool.items[i];

      if (lockToHeadRawBucket &&
          headItem != null &&
          (candidate.level.optimalMoves != headItem.level.optimalMoves ||
              candidate.metrics.vehicleCount != headItem.metrics.vehicleCount)) {
        break;
      }

      if (minScore != null && candidate.metrics.difficultyScore < minScore) {
        continue;
      }
      if (minRawFloor != null && _compareRawEasiest(candidate, minRawFloor) < 0) {
        continue;
      }

      final sim = _maxSimilarityInWindow(candidate.mask, recentMasks);
      if (sim < _similarityThreshold) {
        return pool.takeAt(i);
      }
      if (sim < bestSimilarity) {
        bestSimilarity = sim;
        bestIndex = i;
      }

      scanned++;
      if (scanned >= lookahead) {
        break;
      }
    }

    if (bestIndex >= 0) {
      return pool.takeAt(bestIndex);
    }

    // Fallback when minScore wasn't satisfied inside lookahead window
    if (minScore != null) {
      int highestScoreIdx = -1;
      for (int i = pool.head; i < pool.items.length; i++) {
        if (pool.used[i]) continue;
        final candidate = pool.items[i];
        if (candidate.metrics.difficultyScore >= minScore) {
          return pool.takeAt(i);
        }
        if (highestScoreIdx < 0 ||
            candidate.metrics.difficultyScore >
                pool.items[highestScoreIdx].metrics.difficultyScore) {
          highestScoreIdx = i;
        }
      }
      if (highestScoreIdx >= 0) {
        return pool.takeAt(highestScoreIdx);
      }
    }

    for (int i = pool.head; i < pool.items.length; i++) {
      if (!pool.used[i]) {
        return pool.takeAt(i);
      }
    }
    throw StateError('Pool unexpectedly exhausted.');
  }

  static List<Level> orderLevels(
    List<Level> levels, {
    bool reassignSequentialIds = true,
  }) {
    if (levels.isEmpty) return const [];

    final List<_IndexedLevel> indexed = [];
    for (int i = 0; i < levels.length; i++) {
      final level = levels[i];
      final vehicles = LevelParser.parseBoardString(level.boardString);
      final metrics = LevelDifficultyMetrics.fromVehicles(
        vehicles,
        optimalMoves: level.optimalMoves,
        clusterSize: level.clusterSize,
      );
      indexed.add(
        _IndexedLevel(
          originalIndex: i,
          level: level,
          metrics: metrics,
          mask: _BoardMask.fromVehicles(vehicles),
        ),
      );
    }

    final Queue<_BoardMask> recentWindow = Queue<_BoardMask>();

    // A. Levels #1 - #6: Strict Raw Easiest, skipping near-identical layouts
    final rawSorted = List<_IndexedLevel>.from(indexed)..sort(_compareRawEasiest);
    final rawPool = _IndexedPool(rawSorted);
    final int takeRaw =
        rawSorted.length < rawEasiestCount ? rawSorted.length : rawEasiestCount;
    final List<_IndexedLevel> zone1 = [];
    _IndexedLevel? rawFloor;
    for (int i = 0; i < takeRaw; i++) {
      final chosen = _pickDiverse(
        rawPool,
        recentWindow,
        lookahead: rawSorted.length,
        minRawFloor: rawFloor,
        lockToHeadRawBucket: true,
      );
      zone1.add(chosen);
      rawFloor = chosen;
      _pushWindow(recentWindow, chosen.mask);
    }
    final Set<int> pickedIndices = zone1.map((e) => e.originalIndex).toSet();

    // Remaining levels sorted strictly ascending by difficultyScore
    final List<_IndexedLevel> remainingByScore = indexed
        .where((item) => !pickedIndices.contains(item.originalIndex))
        .toList()
      ..sort(_compareDifficultyScore);

    // B. Levels #7 - #19: Slow Linear Ramp-Up (13 ascending difficultyScore, diverse layouts)
    final rampPool = _IndexedPool(remainingByScore);
    final int takeRamp = remainingByScore.length < rampCount
        ? remainingByScore.length
        : rampCount;
    final List<_IndexedLevel> zone2 = [];
    double prevRampScore = -1.0;
    for (int i = 0; i < takeRamp; i++) {
      final chosen = _pickDiverse(
        rampPool,
        recentWindow,
        lookahead: 200,
        minScore: prevRampScore < 0 ? null : prevRampScore,
      );
      zone2.add(chosen);
      prevRampScore = chosen.metrics.difficultyScore;
      _pushWindow(recentWindow, chosen.mask);
      pickedIndices.add(chosen.originalIndex);
    }

    // C. Levels #20 - #4050: 10-Level Commercial Sawtooth Waves with diversity spacing
    final List<_IndexedLevel> remaining = remainingByScore
        .where((item) => !pickedIndices.contains(item.originalIndex))
        .toList();
    final mainPool = _IndexedPool(
      remaining.where((e) => e.level.difficulty != Difficulty.hard).toList(),
    );
    final hardPool = _IndexedPool(
      remaining.where((e) => e.level.difficulty == Difficulty.hard).toList(),
    );

    final List<_IndexedLevel> zone3 = [];

    // 1. Commercial waves combining 9 progressive Easy/Medium levels + 1 Hard Boss Spike
    while (mainPool.remainingCount >= 9 && hardPool.remainingCount >= 1) {
      final Queue<_BoardMask> localWindow = Queue<_BoardMask>.from(recentWindow);
      final List<_IndexedLevel> chunk = [];
      for (int i = 0; i < 9; i++) {
        final chosen = _pickDiverse(
          mainPool,
          localWindow,
          lookahead: _zone3Lookahead,
        );
        chunk.add(chosen);
        _pushWindow(localWindow, chosen.mask);
      }
      chunk.sort(_compareDifficultyScore);

      final bossSpike = _pickDiverse(
        hardPool,
        localWindow,
        lookahead: _zone3Lookahead,
        minScore: chunk[8].metrics.difficultyScore,
      );

      final wave = [
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
      ];
      zone3.addAll(wave);
      for (final w in wave) {
        _pushWindow(recentWindow, w.mask);
      }
    }

    // 2. Remaining levels continue in 10-level Micro-Waves ([L0, L1, L3..L9, L2])
    //    while preserving layout-diversity spacing across the 55-level window.
    final List<_IndexedLevel> tailItems = [
      for (int i = mainPool.head; i < mainPool.items.length; i++)
        if (!mainPool.used[i]) mainPool.items[i],
      for (int i = hardPool.head; i < hardPool.items.length; i++)
        if (!hardPool.used[i]) hardPool.items[i],
    ]..sort(_compareDifficultyScore);
    final tailPool = _IndexedPool(tailItems);

    while (tailPool.remainingCount >= microWaveSize) {
      final Queue<_BoardMask> localWindow = Queue<_BoardMask>.from(recentWindow);
      final List<_IndexedLevel> chunk = [];
      for (int i = 0; i < microWaveSize; i++) {
        final chosen = _pickDiverse(
          tailPool,
          localWindow,
          lookahead: _zone3Lookahead,
        );
        chunk.add(chosen);
        _pushWindow(localWindow, chosen.mask);
      }
      chunk.sort(_compareDifficultyScore);

      final wave = [
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
      ];
      zone3.addAll(wave);
      for (final w in wave) {
        _pushWindow(recentWindow, w.mask);
      }
    }

    // Trailing remainder (< 10 levels) still goes through diversity selection
    // and stays ordered by ascending difficultyScore.
    final List<_IndexedLevel> remainder = [];
    while (tailPool.remainingCount > 0) {
      final chosen = _pickDiverse(
        tailPool,
        recentWindow,
        lookahead: _zone3Lookahead,
      );
      remainder.add(chosen);
      _pushWindow(recentWindow, chosen.mask);
    }
    remainder.sort(_compareDifficultyScore);
    zone3.addAll(remainder);

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

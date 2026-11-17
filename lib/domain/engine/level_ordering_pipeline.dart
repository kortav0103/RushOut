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

/// Deterministic level ordering pipeline with layout-diversity spacing:
/// - Index `0` (Tutorial): Strict raw easiest Easy level (`_compareRawEasiest`).
/// - `#1–#3`: 3 Easy levels with distinct `optimalMoves` and distinct layout from Tutorial.
/// - `#4–#7`: 4 Medium levels with distinct `optimalMoves`.
/// - `#8–#10`: 3 Hard levels with distinct `optimalMoves`.
/// - Excess Easy levels after `#3` are discarded.
/// - `#11+`: Medium and Hard only, 10-level Commercial Sawtooth Wave pacing,
///   strictly enforcing at most 3 consecutive levels with the same `optimalMoves`.
class LevelOrderingPipeline {
  LevelOrderingPipeline._();

  static const int onboardingEasyCount = 3;
  static const int onboardingMediumCount = 4;
  static const int onboardingHardCount = 3;
  static const int maxConsecutiveSameOptimalMoves = 3;
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

  static _IndexedLevel? _pickDiverse(
    _IndexedPool pool,
    Iterable<_BoardMask> recentMasks, {
    required int lookahead,
    double? minScore,
    Set<int>? forbiddenOptimalMoves,
    bool strictForbidden = false,
  }) {
    int bestIndex = -1;
    double bestSimilarity = 2.0;
    int scanned = 0;

    for (int i = pool.head; i < pool.items.length; i++) {
      if (pool.used[i]) continue;
      final candidate = pool.items[i];

      if (minScore != null && candidate.metrics.difficultyScore < minScore) {
        continue;
      }
      if (forbiddenOptimalMoves != null &&
          forbiddenOptimalMoves.contains(candidate.level.optimalMoves)) {
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
        if (forbiddenOptimalMoves != null &&
            forbiddenOptimalMoves.contains(candidate.level.optimalMoves)) {
          continue;
        }
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

    if (strictForbidden &&
        forbiddenOptimalMoves != null &&
        forbiddenOptimalMoves.isNotEmpty) {
      for (int i = pool.head; i < pool.items.length; i++) {
        if (!pool.used[i] &&
            !forbiddenOptimalMoves.contains(pool.items[i].level.optimalMoves)) {
          return pool.takeAt(i);
        }
      }
      return null;
    }

    for (int i = pool.head; i < pool.items.length; i++) {
      if (!pool.used[i]) {
        return pool.takeAt(i);
      }
    }
    return null;
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

    final easyItems = indexed
        .where((e) => e.level.difficulty == Difficulty.easy)
        .toList()
      ..sort(_compareRawEasiest);
    final mediumItems = indexed
        .where((e) => e.level.difficulty == Difficulty.medium)
        .toList()
      ..sort(_compareDifficultyScore);
    final hardItems = indexed
        .where((e) => e.level.difficulty == Difficulty.hard)
        .toList()
      ..sort(_compareDifficultyScore);

    final easyPool = _IndexedPool(easyItems);
    final mediumPool = _IndexedPool(mediumItems);
    final hardPool = _IndexedPool(hardItems);

    final Queue<_BoardMask> recentWindow = Queue<_BoardMask>();
    final List<_IndexedLevel> onboarding = [];

    // 0. Tutorial (index 0): strict raw easiest Easy level (unchanged)
    _IndexedLevel? tutorial;
    if (easyPool.remainingCount > 0) {
      tutorial = easyPool.takeAt(0);
    } else if (mediumPool.remainingCount > 0) {
      tutorial = mediumPool.takeAt(0);
    } else if (hardPool.remainingCount > 0) {
      tutorial = hardPool.takeAt(0);
    }
    if (tutorial != null) {
      onboarding.add(tutorial);
      _pushWindow(recentWindow, tutorial.mask);
    }

    // 1. Levels #1 - #3: 3 Easy levels (distinct optimalMoves, not identical to tutorial)
    final Set<int> usedEasyMoves = {
      if (tutorial != null) tutorial.level.optimalMoves,
    };
    final int takeEasy = easyPool.remainingCount < onboardingEasyCount
        ? easyPool.remainingCount
        : onboardingEasyCount;
    for (int i = 0; i < takeEasy; i++) {
      var chosen = _pickDiverse(
        easyPool,
        recentWindow,
        lookahead: easyItems.length,
        forbiddenOptimalMoves: usedEasyMoves,
        strictForbidden: true,
      );
      if (chosen == null && tutorial != null) {
        final withoutTutorialMove = Set<int>.from(usedEasyMoves)
          ..remove(tutorial.level.optimalMoves);
        chosen = _pickDiverse(
          easyPool,
          recentWindow,
          lookahead: easyItems.length,
          forbiddenOptimalMoves: withoutTutorialMove,
          strictForbidden: true,
        );
      }
      chosen ??= _pickDiverse(
        easyPool,
        recentWindow,
        lookahead: easyItems.length,
      );
      if (chosen == null) break;
      onboarding.add(chosen);
      usedEasyMoves.add(chosen.level.optimalMoves);
      _pushWindow(recentWindow, chosen.mask);
    }

    // 2. Levels #4 - #7: 4 Medium levels (distinct optimalMoves)
    final Set<int> usedMediumMoves = {};
    final int takeMedium = mediumPool.remainingCount < onboardingMediumCount
        ? mediumPool.remainingCount
        : onboardingMediumCount;
    for (int i = 0; i < takeMedium; i++) {
      var chosen = _pickDiverse(
        mediumPool,
        recentWindow,
        lookahead: 200,
        forbiddenOptimalMoves: usedMediumMoves,
        strictForbidden: true,
      );
      chosen ??= _pickDiverse(
        mediumPool,
        recentWindow,
        lookahead: 200,
      );
      if (chosen == null) break;
      onboarding.add(chosen);
      usedMediumMoves.add(chosen.level.optimalMoves);
      _pushWindow(recentWindow, chosen.mask);
    }

    // 3. Levels #8 - #10: 3 Hard levels (distinct optimalMoves)
    final Set<int> usedHardMoves = {};
    final int takeHard = hardPool.remainingCount < onboardingHardCount
        ? hardPool.remainingCount
        : onboardingHardCount;
    for (int i = 0; i < takeHard; i++) {
      var chosen = _pickDiverse(
        hardPool,
        recentWindow,
        lookahead: 200,
        forbiddenOptimalMoves: usedHardMoves,
        strictForbidden: true,
      );
      chosen ??= _pickDiverse(
        hardPool,
        recentWindow,
        lookahead: 200,
      );
      if (chosen == null) break;
      onboarding.add(chosen);
      usedHardMoves.add(chosen.level.optimalMoves);
      _pushWindow(recentWindow, chosen.mask);
    }

    // Remaining Easy levels are discarded (not included in Zone 3).
    // 4. Levels #11+: Medium & Hard only, 10-Level Sawtooth Waves,
    //    strictly enforcing at most 3 consecutive levels with the same optimalMoves.
    final List<_IndexedLevel> zone3 = [];
    int? lastZone3Move;
    int zone3Run = 0;

    bool canAppendZone3(_IndexedLevel item) {
      return !(zone3Run >= maxConsecutiveSameOptimalMoves &&
          item.level.optimalMoves == lastZone3Move);
    }

    Set<int>? currentForbidden() {
      if (zone3Run >= maxConsecutiveSameOptimalMoves && lastZone3Move != null) {
        return {lastZone3Move!};
      }
      return null;
    }

    void appendZone3(_IndexedLevel item) {
      if (item.level.optimalMoves == lastZone3Move) {
        zone3Run++;
      } else {
        lastZone3Move = item.level.optimalMoves;
        zone3Run = 1;
      }
      zone3.add(item);
      _pushWindow(recentWindow, item.mask);
    }

    bool commitWave(
      List<_IndexedLevel> wave, {
      required List<_IndexedPool> bridgePools,
    }) {
      final remainingWave = List<_IndexedLevel>.from(wave);
      while (remainingWave.isNotEmpty) {
        int pickIdx = -1;
        for (int i = 0; i < remainingWave.length; i++) {
          if (canAppendZone3(remainingWave[i])) {
            pickIdx = i;
            break;
          }
        }
        if (pickIdx >= 0) {
          appendZone3(remainingWave.removeAt(pickIdx));
          continue;
        }

        // All remaining items in this wave share lastZone3Move and zone3Run >= 3.
        // Try pulling a diverse bridge item with a different optimalMoves.
        _IndexedLevel? bridge;
        final forbidden = currentForbidden();
        for (final pool in bridgePools) {
          if (pool.remainingCount == 0) continue;
          bridge = _pickDiverse(
            pool,
            recentWindow,
            lookahead: _zone3Lookahead,
            forbiddenOptimalMoves: forbidden,
            strictForbidden: true,
          );
          if (bridge != null) break;
        }
        if (bridge == null) {
          return false;
        }
        appendZone3(bridge);
      }
      return true;
    }

    // Commercial waves combining 9 progressive Medium levels + 1 Hard Boss Spike
    while (mediumPool.remainingCount >= 9 && hardPool.remainingCount >= 1) {
      final Queue<_BoardMask> localWindow = Queue<_BoardMask>.from(recentWindow);
      final List<_IndexedLevel> chunk = [];
      final Map<int, int> waveMoveCounts = {};
      for (int i = 0; i < 9; i++) {
        final forbiddenInWave = {
          for (final entry in waveMoveCounts.entries)
            if (entry.value >= maxConsecutiveSameOptimalMoves) entry.key,
        };
        final chosen = _pickDiverse(
          mediumPool,
          localWindow,
          lookahead: _zone3Lookahead,
          forbiddenOptimalMoves:
              forbiddenInWave.isEmpty ? null : forbiddenInWave,
        )!;
        chunk.add(chosen);
        waveMoveCounts[chosen.level.optimalMoves] =
            (waveMoveCounts[chosen.level.optimalMoves] ?? 0) + 1;
        _pushWindow(localWindow, chosen.mask);
      }
      chunk.sort(_compareDifficultyScore);

      final bossSpike = _pickDiverse(
        hardPool,
        localWindow,
        lookahead: _zone3Lookahead,
        minScore: chunk[8].metrics.difficultyScore,
      )!;

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
      if (!commitWave(wave, bridgePools: [hardPool, mediumPool])) {
        break;
      }
    }

    // Remaining Medium + Hard levels continue in 10-level Micro-Waves
    // while strictly enforcing max 3 consecutive same optimalMoves.
    final List<_IndexedLevel> tailItems = [
      for (int i = mediumPool.head; i < mediumPool.items.length; i++)
        if (!mediumPool.used[i]) mediumPool.items[i],
      for (int i = hardPool.head; i < hardPool.items.length; i++)
        if (!hardPool.used[i]) hardPool.items[i],
    ]..sort(_compareDifficultyScore);
    final tailPool = _IndexedPool(tailItems);

    while (tailPool.remainingCount >= microWaveSize) {
      final Queue<_BoardMask> localWindow = Queue<_BoardMask>.from(recentWindow);
      final List<_IndexedLevel> chunk = [];
      final Map<int, int> waveMoveCounts = {};
      for (int i = 0; i < microWaveSize; i++) {
        final forbiddenInWave = {
          for (final entry in waveMoveCounts.entries)
            if (entry.value >= maxConsecutiveSameOptimalMoves) entry.key,
        };
        final chosen = _pickDiverse(
          tailPool,
          localWindow,
          lookahead: _zone3Lookahead,
          forbiddenOptimalMoves:
              forbiddenInWave.isEmpty ? null : forbiddenInWave,
        )!;
        chunk.add(chosen);
        waveMoveCounts[chosen.level.optimalMoves] =
            (waveMoveCounts[chosen.level.optimalMoves] ?? 0) + 1;
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
      if (!commitWave(wave, bridgePools: [tailPool])) {
        break;
      }
    }

    // Trailing remainder (< 10 levels) still enforces diversity and max 3 consecutive optimalMoves
    while (tailPool.remainingCount > 0) {
      final chosen = _pickDiverse(
        tailPool,
        recentWindow,
        lookahead: _zone3Lookahead,
        forbiddenOptimalMoves: currentForbidden(),
        strictForbidden: true,
      );
      if (chosen == null) break;
      appendZone3(chosen);
    }

    final combined = [...onboarding, ...zone3];

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

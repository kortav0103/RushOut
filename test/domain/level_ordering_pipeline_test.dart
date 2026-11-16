import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/utils/level_parser.dart';
import 'package:rush_out/domain/engine/level_ordering_pipeline.dart';
import 'package:rush_out/domain/entities/level.dart';

void main() {
  group('LevelOrderingPipeline Tests', () {
    test('Scoring: occupiedCells and initialBlockers are accurately parsed and reflected in difficultyScore', () {
      // Row 0: o o o o o o
      // Row 1: o o o B o o  (B starts at (1,3))
      // Row 2: A A o B C o  (A at (2,0)-(2,1), B at (2,3), C at (2,4)) -> 2 blockers: B and C
      // Row 3: o o o o C o  (C ends at (3,4), len 2)
      // Row 4: D D D o o o  (D at (4,0)-(4,2), len 3)
      // Row 5: o o o o o o
      const board = 'oooooo'
          'oooBoo'
          'AAoBCo'
          'ooooCo'
          'DDDooo'
          'oooooo';

      // A(2) + B(2) + C(2) + D(3) = 9 occupied cells; blockers to right of A on row 2 = B, C (2)
      final metrics = LevelDifficultyMetrics.fromBoardString(
        board,
        optimalMoves: 7,
      );

      expect(metrics.vehicleCount, 4);
      expect(metrics.occupiedCells, 9);
      expect(metrics.initialBlockers, 2);
      expect(
        metrics.difficultyScore,
        closeTo((7 * 10.0) + (9 * 0.8) + (2 * 1.5), 1e-6),
      );
    });

    test('Determinism, Onboarding (#1-#15), and 10-Level Micro-Wave Pacing on real dataset', () {
      final file = File('assets/levels/rush1000.txt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Determinism: running twice yields identical ordering from #1 to #4050
      final run1 = LevelParser.parseCampaignLevels(content);
      final run2 = LevelParser.parseCampaignLevels(content);

      expect(run1.length, 4050);
      expect(run2.length, 4050);
      for (int i = 0; i < run1.length; i++) {
        expect(run1[i].id, i + 1);
        expect(run1[i].boardString, run2[i].boardString);
        expect(run1[i].optimalMoves, run2[i].optimalMoves);
        expect(run1[i].isUnlocked, i == 0);
      }

      // #1-#6: Strict raw easiest sorted by (optimalMoves, vehicleCount, initialBlockers, originalIndex)
      for (int i = 0; i < 5; i++) {
        final curr = run1[i];
        final next = run1[i + 1];
        final mc = LevelDifficultyMetrics.fromBoardString(
          curr.boardString,
          optimalMoves: curr.optimalMoves,
        );
        final mn = LevelDifficultyMetrics.fromBoardString(
          next.boardString,
          optimalMoves: next.optimalMoves,
        );
        expect(curr.optimalMoves, lessThanOrEqualTo(next.optimalMoves));
        if (curr.optimalMoves == next.optimalMoves) {
          expect(mc.vehicleCount, lessThanOrEqualTo(mn.vehicleCount));
          if (mc.vehicleCount == mn.vehicleCount) {
            expect(mc.initialBlockers, lessThanOrEqualTo(mn.initialBlockers));
          }
        }
      }

      // #7-#19: Strictly ascending difficultyScore
      double prevRampScore = -1;
      for (int i = 6; i < 19; i++) {
        final lvl = run1[i];
        final m = LevelDifficultyMetrics.fromBoardString(
          lvl.boardString,
          optimalMoves: lvl.optimalMoves,
          clusterSize: lvl.clusterSize,
        );
        expect(m.difficultyScore, greaterThanOrEqualTo(prevRampScore));
        prevRampScore = m.difficultyScore;
      }

      // #20+: 10-Level Commercial Sawtooth Wave: slot 9 >= slot 8 (Boss Spike), slot 10 <= slot 9 (Breather)
      // First commercial wave (#20-#29) must weave a Hard Boss Spike at slot 9 (#28) followed by a non-Hard Breather (#29)
      expect(run1[19 + 8].difficulty, Difficulty.hard);
      expect(run1[19 + 9].difficulty, isNot(Difficulty.hard));

      for (int start = 19; start + 10 <= run1.length; start += 10) {
        final slot8 = run1[start + 7];
        final slot9 = run1[start + 8];
        final slot10 = run1[start + 9];

        final s8 = LevelDifficultyMetrics.fromBoardString(
          slot8.boardString,
          optimalMoves: slot8.optimalMoves,
          clusterSize: slot8.clusterSize,
        ).difficultyScore;
        final s9 = LevelDifficultyMetrics.fromBoardString(
          slot9.boardString,
          optimalMoves: slot9.optimalMoves,
          clusterSize: slot9.clusterSize,
        ).difficultyScore;
        final s10 = LevelDifficultyMetrics.fromBoardString(
          slot10.boardString,
          optimalMoves: slot10.optimalMoves,
          clusterSize: slot10.clusterSize,
        ).difficultyScore;

        expect(s9, greaterThanOrEqualTo(s8));
        expect(s10, lessThanOrEqualTo(s9));
      }

      // First 50 levels must have diverse layouts (no near-identical variants clumped together)
      for (int i = 0; i < 50; i++) {
        for (int j = i + 1; j < 50; j++) {
          final sim = LevelOrderingPipeline.boardSimilarity(
            run1[i].boardString,
            run1[j].boardString,
          );
          expect(
            sim,
            lessThan(0.62),
            reason:
                'Levels #${i + 1} and #${j + 1} should not share near-identical layout (similarity=$sim)',
          );
        }
      }
    });

    test('Micro-Wave strictly places L9 at slot 9 (peak) and L2 at slot 10 (breather)', () {
      // Create 29 synthetic levels: first 19 onboarding (5 moves), next 10 with distinct optimalMoves 7..16
      const simpleBoard = 'oooooo'
          'oooooo'
          'AAoooo'
          'oooooo'
          'oooooo'
          'oooooo';

      final levels = <Level>[
        for (int i = 0; i < 19; i++)
          Level(
            id: i + 1,
            difficulty: Difficulty.easy,
            optimalMoves: 5,
            boardString: simpleBoard,
          ),
        for (int i = 0; i < 10; i++)
          Level(
            id: 20 + i,
            difficulty: Difficulty.medium,
            optimalMoves: 7 + i, // 7, 8, 9, 10, 11, 12, 13, 14, 15, 16
            boardString: simpleBoard,
          ),
      ];

      final ordered = LevelOrderingPipeline.orderLevels(levels);
      expect(ordered.length, 29);

      // Wave #20..#29 should be: [7, 8, 10, 11, 12, 13, 14, 15, 16, 9]
      final waveMoves = ordered.sublist(19, 29).map((l) => l.optimalMoves).toList();
      expect(waveMoves, [7, 8, 10, 11, 12, 13, 14, 15, 16, 9]);
    });

    test('Levels #1-#6 sort strictly by (optimalMoves, vehicleCount, initialBlockers, originalIndex) without difficultyScore weighting', () {
      // 4 vehicles, 5 moves, 0 blockers -> higher occupiedCells (10) than 2-vehicle board,
      // wait: 2 vehicles < 4 vehicles so 2-vehicle board comes first;
      // 3 vehicles with 3-len trucks (occupiedCells = 9) vs 4 vehicles with 2-len cars (occupiedCells = 8):
      // difficultyScore would rank 4-car board (8*0.8=6.4) lower than 3-truck board (9*0.8=7.2),
      // but raw easiest MUST rank 3-truck board (vehicleCount=3) before 4-car board (vehicleCount=4)!
      const threeTruckBoard = 'BBBooo'
          'CCCooo'
          'AAoooo'
          'oooooo'
          'oooooo'
          'oooooo';
      const fourCarBoard = 'BBCCoo'
          'DDoooo'
          'AAoooo'
          'oooooo'
          'oooooo'
          'oooooo';

      final levels = <Level>[
        for (int i = 0; i < 6; i++)
          Level(
            id: i + 1,
            difficulty: Difficulty.easy,
            optimalMoves: 5,
            boardString: fourCarBoard,
          ),
        for (int i = 0; i < 6; i++)
          Level(
            id: 7 + i,
            difficulty: Difficulty.easy,
            optimalMoves: 5,
            boardString: threeTruckBoard,
          ),
        for (int i = 0; i < 8; i++)
          Level(
            id: 13 + i,
            difficulty: Difficulty.easy,
            optimalMoves: 6,
            boardString: fourCarBoard,
          ),
      ];

      final ordered = LevelOrderingPipeline.orderLevels(levels);
      expect(ordered.length, 20);

      // #1-#6 must all be the 3-vehicle boards (vehicleCount = 3)
      for (int i = 0; i < 6; i++) {
        final m = LevelDifficultyMetrics.fromBoardString(
          ordered[i].boardString,
          optimalMoves: ordered[i].optimalMoves,
        );
        expect(ordered[i].optimalMoves, 5);
        expect(m.vehicleCount, 3);
      }

      // #7-#15 must ascend monotonically by difficultyScore
      double prevRamp = -1;
      for (int i = 6; i < 15; i++) {
        final m = LevelDifficultyMetrics.fromBoardString(
          ordered[i].boardString,
          optimalMoves: ordered[i].optimalMoves,
        );
        expect(m.difficultyScore, greaterThanOrEqualTo(prevRamp));
        prevRamp = m.difficultyScore;
      }
    });

    test('Zone 3 tail applies layout diversity so identical Hard families do not clump consecutively', () {
      // 10 identical copies of hardLayoutA (optimalMoves=19) plus 10 distinct
      // Hard board layouts (optimalMoves=20) so a 10-level wave has enough distinct layouts.
      const hardLayoutA = 'BBCCoo'
          'oooDoo'
          'AAoDoo'
          'oooooo'
          'oooooo'
          'oooooo';
      const distinctLayouts = <String>[
        'oooooo' 'oooooo' 'oAAoBo' 'ooooBo' 'CCDDDo' 'oooooo',
        'BBBooo' 'oooooo' 'AAoooo' 'oooCoo' 'oooCoo' 'DDoooo',
        'oooooo' 'CCoooo' 'AAoDoo' 'oooDoo' 'oooooo' 'EEEooo',
        'oooBBB' 'oooooo' 'AAoooo' 'oooooo' 'CCoooo' 'DDDooo',
        'oooooo' 'oooooo' 'AAoooo' 'Booooo' 'Booooo' 'CCCDDD',
        'oooooo' 'ooBBoo' 'AAoooo' 'oooooo' 'ooCCoo' 'ooDDDo',
        'CCoooo' 'oooooo' 'AAoooo' 'ooBooo' 'ooBooo' 'ooBDDD',
        'oooooo' 'oooCCC' 'AAoooo' 'oooooo' 'Booooo' 'BDDDoo',
        'BBoooo' 'CCoooo' 'AAoooo' 'oooooo' 'oooooo' 'oDDDoo',
        'oooooo' 'oooooo' 'AAoBBo' 'oooooo' 'CCCooo' 'oooDDD',
      ];

      const simpleEasyBoard = 'oooooo'
          'oooooo'
          'AAoooo'
          'oooooo'
          'oooooo'
          'oooooo';

      // 19 onboarding Easy levels + 20 Hard levels going straight into Zone 3 tail
      final levels = <Level>[
        for (int i = 0; i < 19; i++)
          Level(
            id: i + 1,
            difficulty: Difficulty.easy,
            optimalMoves: 5 + (i % 5),
            boardString: simpleEasyBoard,
          ),
        for (int i = 0; i < 10; i++)
          Level(
            id: 20 + i,
            difficulty: Difficulty.hard,
            optimalMoves: 19,
            boardString: hardLayoutA,
          ),
        for (int i = 0; i < 10; i++)
          Level(
            id: 30 + i,
            difficulty: Difficulty.hard,
            optimalMoves: 20,
            boardString: distinctLayouts[i],
          ),
      ];

      final ordered = LevelOrderingPipeline.orderLevels(levels);
      expect(ordered.length, 39);

      // Without tail diversity, all 10 hardLayoutA levels clump at indices 19..28.
      // With _pickDiverse in tail, the first 10-level tail wave (indices 19..28)
      // contains at most 1 copy of hardLayoutA.
      final firstTailWaveBoards =
          ordered.sublist(19, 29).map((l) => l.boardString).toList();
      final hardACountInFirstWave =
          firstTailWaveBoards.where((b) => b == hardLayoutA).length;
      expect(
        hardACountInFirstWave,
        1,
        reason: 'Tail wave must diversify across distinct layouts instead of clumping identical Hard levels.',
      );
    });
  });
}

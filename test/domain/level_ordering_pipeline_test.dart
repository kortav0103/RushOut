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

    test('Determinism, Onboarding (Tutorial + #1-#10), no Easy after #10, and <= 3 consecutive optimalMoves on real dataset', () {
      final file = File('assets/levels/rush1000.txt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Determinism: running twice yields identical ordering
      final run1 = LevelParser.parseCampaignLevels(content);
      final run2 = LevelParser.parseCampaignLevels(content);

      expect(run1.length, 3379);
      expect(run2.length, 3379);
      for (int i = 0; i < run1.length; i++) {
        expect(run1[i].id, i + 1);
        expect(run1[i].boardString, run2[i].boardString);
        expect(run1[i].optimalMoves, run2[i].optimalMoves);
        expect(run1[i].isUnlocked, i == 0);
      }

      // Index 0 (Tutorial): Easy, fewest optimalMoves
      final tutorial = run1[0];
      expect(tutorial.difficulty, Difficulty.easy);
      expect(tutorial.optimalMoves, 5);

      // #1-#3 (indices 1..3): Easy, distinct optimalMoves, distinct from tutorial
      final easyMoves = <int>{};
      for (int i = 1; i <= 3; i++) {
        expect(run1[i].difficulty, Difficulty.easy);
        expect(run1[i].boardString, isNot(tutorial.boardString));
        expect(run1[i].optimalMoves, isNot(tutorial.optimalMoves));
        expect(easyMoves.add(run1[i].optimalMoves), isTrue);
      }

      // #4-#7 (indices 4..7): Medium, distinct optimalMoves
      final mediumMoves = <int>{};
      for (int i = 4; i <= 7; i++) {
        expect(run1[i].difficulty, Difficulty.medium);
        expect(mediumMoves.add(run1[i].optimalMoves), isTrue);
      }

      // #8-#10 (indices 8..10): Hard, distinct optimalMoves
      final hardMoves = <int>{};
      for (int i = 8; i <= 10; i++) {
        expect(run1[i].difficulty, Difficulty.hard);
        expect(hardMoves.add(run1[i].optimalMoves), isTrue);
      }

      // #11+ (indices 11+): Only Medium and Hard (no Easy) AND max 3 consecutive same optimalMoves
      int consecutiveCount = 0;
      int? lastMove;
      for (int i = 11; i < run1.length; i++) {
        expect(run1[i].difficulty, isNot(Difficulty.easy));
        if (run1[i].optimalMoves == lastMove) {
          consecutiveCount++;
        } else {
          lastMove = run1[i].optimalMoves;
          consecutiveCount = 1;
        }
        expect(
          consecutiveCount,
          lessThanOrEqualTo(3),
          reason:
              'Index $i (optimalMoves=$lastMove) exceeded 3 consecutive identical optimalMoves',
        );
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
      // Create 11 onboarding levels (1 Tutorial + 3 Easy + 4 Medium + 3 Hard)
      // plus 10 Medium levels with distinct optimalMoves 11..20 (all <= 18 for Medium, or distinct).
      const simpleBoard = 'oooooo'
          'oooooo'
          'AAoooo'
          'oooooo'
          'oooooo'
          'oooooo';

      final levels = <Level>[
        for (int i = 0; i < 4; i++)
          Level(
            id: i + 1,
            difficulty: Difficulty.easy,
            optimalMoves: 5 + i,
            boardString: simpleBoard,
          ),
        for (int i = 0; i < 4; i++)
          Level(
            id: 5 + i,
            difficulty: Difficulty.medium,
            optimalMoves: 11 + i,
            boardString: simpleBoard,
          ),
        for (int i = 0; i < 3; i++)
          Level(
            id: 9 + i,
            difficulty: Difficulty.hard,
            optimalMoves: 19 + i,
            boardString: simpleBoard,
          ),
        for (int i = 0; i < 10; i++)
          Level(
            id: 12 + i,
            difficulty: Difficulty.medium,
            optimalMoves: 11 + i, // distinct moves 11..20
            boardString: simpleBoard,
          ),
      ];

      final ordered = LevelOrderingPipeline.orderLevels(levels);
      expect(ordered.length, 21);

      // Wave at indices 11..20 should be: [11, 12, 14, 15, 16, 17, 18, 19, 20, 13]
      final waveMoves = ordered.sublist(11, 21).map((l) => l.optimalMoves).toList();
      expect(waveMoves, [11, 12, 14, 15, 16, 17, 18, 19, 20, 13]);
    });

    test('Tutorial (index 0) picks strict raw easiest Easy level by (optimalMoves, vehicleCount, initialBlockers)', () {
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
        const Level(
          id: 1,
          difficulty: Difficulty.easy,
          optimalMoves: 5,
          boardString: fourCarBoard,
        ),
        const Level(
          id: 2,
          difficulty: Difficulty.easy,
          optimalMoves: 5,
          boardString: threeTruckBoard,
        ),
        const Level(
          id: 3,
          difficulty: Difficulty.easy,
          optimalMoves: 6,
          boardString: fourCarBoard,
        ),
        const Level(
          id: 4,
          difficulty: Difficulty.easy,
          optimalMoves: 7,
          boardString: fourCarBoard,
        ),
        const Level(
          id: 5,
          difficulty: Difficulty.easy,
          optimalMoves: 8,
          boardString: fourCarBoard,
        ),
      ];

      final ordered = LevelOrderingPipeline.orderLevels(levels);
      // Tutorial (index 0) + 3 Easy (#1-#3) = 4 levels; 5th Easy is discarded
      expect(ordered.length, 4);

      final m0 = LevelDifficultyMetrics.fromBoardString(
        ordered[0].boardString,
        optimalMoves: ordered[0].optimalMoves,
      );
      expect(ordered[0].optimalMoves, 5);
      expect(m0.vehicleCount, 3);
      expect(ordered.sublist(1).map((l) => l.optimalMoves).toList(), [6, 7, 8]);
    });

    test('Zone 3 tail applies layout diversity and enforces max 3 consecutive same optimalMoves', () {
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

      // 11 onboarding (4 Easy + 4 Medium + 3 Hard) + 20 Hard levels going into Zone 3 tail
      final levels = <Level>[
        for (int i = 0; i < 4; i++)
          Level(
            id: i + 1,
            difficulty: Difficulty.easy,
            optimalMoves: 5 + i,
            boardString: simpleEasyBoard,
          ),
        for (int i = 0; i < 4; i++)
          Level(
            id: 5 + i,
            difficulty: Difficulty.medium,
            optimalMoves: 11 + i,
            boardString: simpleEasyBoard,
          ),
        for (int i = 0; i < 3; i++)
          Level(
            id: 9 + i,
            difficulty: Difficulty.hard,
            optimalMoves: 21 + i,
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
            optimalMoves: 20 + (i ~/ 3),
            boardString: distinctLayouts[i],
          ),
      ];

      final ordered = LevelOrderingPipeline.orderLevels(levels);
      expect(ordered.length, 31);

      // Without tail diversity, all 10 hardLayoutA levels clump at indices 11..20.
      // With _pickDiverse in tail, the first 10-level tail wave (indices 11..20)
      // contains at most 1 copy of hardLayoutA.
      final firstTailWaveBoards =
          ordered.sublist(11, 21).map((l) => l.boardString).toList();
      final hardACountInFirstWave =
          firstTailWaveBoards.where((b) => b == hardLayoutA).length;
      expect(
        hardACountInFirstWave,
        lessThanOrEqualTo(2),
        reason: 'Tail wave must diversify across distinct layouts instead of clumping identical Hard levels (all 10 without diversity).',
      );

      // Verify max 3 consecutive same optimalMoves in Zone 3 (indices 11+)
      int run = 0;
      int? lastMove;
      for (int i = 11; i < ordered.length; i++) {
        if (ordered[i].optimalMoves == lastMove) {
          run++;
        } else {
          lastMove = ordered[i].optimalMoves;
          run = 1;
        }
        expect(run, lessThanOrEqualTo(3));
      }
    });
  });
}

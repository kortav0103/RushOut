import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/error/exceptions.dart';
import 'package:rush_out/core/utils/level_parser.dart';
import 'package:rush_out/domain/entities/level.dart';

void main() {
  group('LevelParser Tests', () {
    const validBoardString = 'BBoKooIooKooIAAKooIooLCCJDDLFFJGGooo';
    // Grid breakdown of validBoardString:
    // Row 0: B B o K o o  -> B: (0,0) len 2 horiz; K starts at (0,3)
    // Row 1: I o o K o o  -> I starts at (1,0); K continues at (1,3)
    // Row 2: I A A K o o  -> I at (2,0); A: (2,1) len 2 horiz; K ends at (2,3) len 3 vert
    // Row 3: I o o L C C  -> I ends at (3,0) len 3 vert; L starts at (3,3); C: (3,4) len 2 horiz
    // Row 4: J D D L F F  -> J starts at (4,0); D: (4,1) len 2 horiz; L ends at (4,3) len 2 vert; F: (4,4) len 2 horiz
    // Row 5: J G G o o o  -> J ends at (5,0) len 2 vert; G: (5,1) len 2 horiz

    test('parses 36-char board string into accurate Vehicle entities', () {
      final vehicles = LevelParser.parseBoardString(validBoardString);

      expect(vehicles.length, 10);

      final targetA = vehicles.firstWhere((v) => v.id == 'A');
      expect(targetA.isTarget, isTrue);
      expect(targetA.row, 2);
      expect(targetA.col, 1);
      expect(targetA.length, 2);
      expect(targetA.isHorizontal, isTrue);
      expect(targetA.endRow, 2);
      expect(targetA.endCol, 2);
      expect(targetA.occupies(2, 1), isTrue);
      expect(targetA.occupies(2, 2), isTrue);
      expect(targetA.occupies(2, 3), isFalse);

      final truckK = vehicles.firstWhere((v) => v.id == 'K');
      expect(truckK.isTarget, isFalse);
      expect(truckK.row, 0);
      expect(truckK.col, 3);
      expect(truckK.length, 3);
      expect(truckK.isHorizontal, isFalse);
      expect(truckK.endRow, 2);
      expect(truckK.endCol, 3);

      final truckI = vehicles.firstWhere((v) => v.id == 'I');
      expect(truckI.row, 1);
      expect(truckI.col, 0);
      expect(truckI.length, 3);
      expect(truckI.isHorizontal, isFalse);

      // Round-trip back to canonical 36-character string
      final state = LevelParser.parseToBoardState(
        validBoardString,
        optimalMoves: 8,
      );
      expect(state.toBoardString(), validBoardString);
      expect(state.optimalMoves, 8);
    });

    test('filters out lines containing fixed wall character "x"', () {
      const lineWithWall = '08 BBooxxooKoooAAKoooIoKCCoIooLDDJooLFF 42';
      const validLine = '08 BBoKooIooKooIAAKooIooLCCJDDLFFJGGooo 95';

      expect(LevelParser.containsWall(lineWithWall), isTrue);
      expect(LevelParser.parseLine(lineWithWall), isNull);

      final parsedValid = LevelParser.parseLine(validLine);
      expect(parsedValid, isNotNull);
      expect(parsedValid!.optimalMoves, 8);
      expect(parsedValid.boardString, validBoardString);
      expect(parsedValid.clusterSize, 95);
    });

    test('throws LevelParseException on invalid board strings', () {
      // Wrong length
      expect(
        () => LevelParser.parseBoardString('AAoooo'),
        throwsA(isA<LevelParseException>()),
      );

      // Contains 'x'
      expect(
        () => LevelParser.parseBoardString(
          'BBooxxooKoooAAKoooIoKCCoIooLDDJooLFF',
        ),
        throwsA(isA<LevelParseException>()),
      );

      // Vehicle of length 1
      expect(
        () => LevelParser.parseBoardString(
          'Aooooooooooooooooooooooooooooooooooo',
        ),
        throwsA(isA<LevelParseException>()),
      );

      // Non-contiguous vehicle cells
      expect(
        () => LevelParser.parseBoardString(
          'AoAooooooooooooooooooooooooooooooooo',
        ),
        throwsA(isA<LevelParseException>()),
      );

      // Missing target vehicle 'A'
      expect(
        () => LevelParser.parseBoardString(
          'BBoKooIooKooIooKooIooLCCJDDLFFJGGooo',
        ),
        throwsA(isA<LevelParseException>()),
      );

      // Target vehicle 'A' length != 2 (length 3)
      expect(
        () => LevelParser.parseBoardString(
          'ooooooooooooAAAooooooooooooooooooooo',
        ),
        throwsA(isA<LevelParseException>()),
      );

      // Target vehicle 'A' is vertical
      expect(
        () => LevelParser.parseBoardString(
          'ooAoooooAooooooooooooooooooooooooooo',
        ),
        throwsA(isA<LevelParseException>()),
      );

      // Target vehicle 'A' is on wrong row (row 0 instead of exitRow 2)
      expect(
        () => LevelParser.parseBoardString(
          'AAoooooooooooooooooooooooooooooooooo',
        ),
        throwsA(isA<LevelParseException>()),
      );
    });

    test('parseLine rejects non-positive optimalMoves and negative clusterSize', () {
      expect(
        LevelParser.parseLine('0 $validBoardString 10'),
        isNull,
      );
      expect(
        LevelParser.parseLine('-3 $validBoardString 10'),
        isNull,
      );
      expect(
        LevelParser.parseLine('8 $validBoardString -1'),
        isNull,
      );
      expect(
        LevelParser.parseLine('8 $validBoardString invalid_cluster'),
        isNull,
      );
    });

    test(
      'parses assets/levels/rush1000.txt into 3379 levels (4 Easy, 1800 Medium, 1575 Hard) without walls',
      () {
        final file = File('assets/levels/rush1000.txt');
        expect(file.existsSync(), isTrue);

        final content = file.readAsStringSync();
        final levels = LevelParser.parseCampaignLevels(content);

        expect(levels.length, 3379);

        final easyLevels =
            levels.where((l) => l.difficulty == Difficulty.easy).toList();
        final mediumLevels =
            levels.where((l) => l.difficulty == Difficulty.medium).toList();
        final hardLevels =
            levels.where((l) => l.difficulty == Difficulty.hard).toList();

        expect(easyLevels.length, 4);
        expect(mediumLevels.length, 1800);
        expect(hardLevels.length, 1575);

        for (final level in easyLevels) {
          expect(level.optimalMoves, inInclusiveRange(5, 10));
          expect(LevelParser.containsWall(level.boardString), isFalse);
        }
        for (final level in mediumLevels) {
          expect(level.optimalMoves, inInclusiveRange(11, 18));
          expect(LevelParser.containsWall(level.boardString), isFalse);
        }
        for (final level in hardLevels) {
          expect(level.optimalMoves, inInclusiveRange(19, 25));
          expect(LevelParser.containsWall(level.boardString), isFalse);
        }
      },
    );

    test(
      'campaign_ordered.txt contains 3379 pre-ordered levels without "x" matching LevelOrderingPipeline',
      () {
        final orderedFile = File('assets/levels/campaign_ordered.txt');
        final rawFile = File('assets/levels/rush1000.txt');
        expect(orderedFile.existsSync(), isTrue);
        expect(rawFile.existsSync(), isTrue);

        final orderedLevels = LevelParser.parsePreOrderedCampaignLevels(
          orderedFile.readAsStringSync(),
        );
        final expectedLevels = LevelParser.parseCampaignLevels(
          rawFile.readAsStringSync(),
        );

        expect(orderedLevels.length, 3379);
        expect(expectedLevels.length, 3379);

        final easyCount =
            orderedLevels.where((l) => l.difficulty == Difficulty.easy).length;
        final mediumCount =
            orderedLevels.where((l) => l.difficulty == Difficulty.medium).length;
        final hardCount =
            orderedLevels.where((l) => l.difficulty == Difficulty.hard).length;
        expect(easyCount, 4);
        expect(mediumCount, 1800);
        expect(hardCount, 1575);

        for (int i = 0; i < orderedLevels.length; i++) {
          final actual = orderedLevels[i];
          final expected = expectedLevels[i];

          expect(actual.id, i + 1);
          expect(actual.id, expected.id);
          expect(actual.difficulty, expected.difficulty);
          expect(actual.optimalMoves, expected.optimalMoves);
          expect(actual.boardString, expected.boardString);
          expect(actual.clusterSize, expected.clusterSize);
          expect(actual.isUnlocked, i == 0);
          expect(LevelParser.containsWall(actual.boardString), isFalse);
        }
      },
    );

    test(
      'parsePreOrderedCampaignLevels falls back to parseCampaignLevels when fewer than 4050 lines',
      () {
        const mockRawContent = '''
06 $validBoardString 25
14 $validBoardString 40
21 $validBoardString 80
''';
        final levels = LevelParser.parsePreOrderedCampaignLevels(mockRawContent);

        expect(levels.length, 3);
        expect(levels[0].id, 1);
        expect(levels[0].optimalMoves, 6);
        expect(levels[0].difficulty, Difficulty.easy);
        expect(levels[0].isUnlocked, isTrue);
        expect(levels[1].id, 2);
        expect(levels[1].optimalMoves, 14);
        expect(levels[1].difficulty, Difficulty.medium);
        expect(levels[2].id, 3);
        expect(levels[2].optimalMoves, 21);
        expect(levels[2].difficulty, Difficulty.hard);
      },
    );
  });
}

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
    });

    test(
      'parses assets/levels/rush1000.txt into 4050 levels (1350 Easy, 1350 Medium, 1350 Hard) without walls',
      () {
        final file = File('assets/levels/rush1000.txt');
        expect(file.existsSync(), isTrue);

        final content = file.readAsStringSync();
        final levels = LevelParser.parseCampaignLevels(content);

        expect(levels.length, 4050);

        final easyLevels =
            levels.where((l) => l.difficulty == Difficulty.easy).toList();
        final mediumLevels =
            levels.where((l) => l.difficulty == Difficulty.medium).toList();
        final hardLevels =
            levels.where((l) => l.difficulty == Difficulty.hard).toList();

        expect(easyLevels.length, 1350);
        expect(mediumLevels.length, 1350);
        expect(hardLevels.length, 1350);

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
  });
}

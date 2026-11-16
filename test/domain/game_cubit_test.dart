import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/services/audio_service.dart';
import 'package:rush_out/domain/entities/level.dart';
import 'package:rush_out/presentation/bloc/daily_cubit.dart';
import 'package:rush_out/presentation/bloc/game_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameCubit Tests', () {
    const sampleLevel = Level(
      id: 1,
      difficulty: Difficulty.easy,
      optimalMoves: 2,
      boardString: 'oooooo'
          'oooBoo'
          'AAoBoo'
          'oooooo'
          'oooooo'
          'oooooo',
      isUnlocked: true,
    );

    late GameCubit cubit;

    setUp(() {
      cubit = GameCubit(
        level: sampleLevel,
        audioService: AudioService(enablePlatformAudio: false),
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    test('manages board state, async Isolate hint, undo, reset, and win detection', () async {
      expect(cubit.state.boardState.moveCount, 0);
      expect(cubit.state.isWon, isFalse);
      expect(cubit.state.remainingHints, 3);

      // Request hint -> runs BfsSolver in background Isolate and decrements remainingHints
      await cubit.requestHint();
      expect(cubit.state.activeHint, isNotNull);
      expect(cubit.state.activeHint!.vehicleId, 'B');
      expect(cubit.state.remainingHints, 2);

      // Drag B down to row 3
      cubit.onVehicleDragStart('B');
      await cubit.onVehicleDragEnd('B', draggedRow: 3.1, draggedCol: 3.0);

      expect(cubit.state.boardState.moveCount, 1);
      expect(cubit.state.activeHint, isNull);
      expect(cubit.state.canUndo, isTrue);

      // Undo -> back to 0 moves
      cubit.undo();
      expect(cubit.state.boardState.moveCount, 0);
      expect(cubit.state.boardState.getVehicleById('B')!.row, 1);

      // Redo move 1 (B -> row 3) and move 2 (A -> col 4) to win
      await cubit.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0);
      await cubit.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 4.0);

      expect(cubit.state.isWon, isTrue);
      expect(cubit.state.earnedStars, 3);
      expect(cubit.state.level.bestMoves, 2);
      expect(cubit.state.level.stars, 3);
      // Earned 3 stars for the first time -> +1 bonus hint (2 + 1 = 3)
      expect(cubit.state.remainingHints, 3);

      // Reset -> restores initial state
      cubit.reset();
      expect(cubit.state.isWon, isFalse);
      expect(cubit.state.boardState.moveCount, 0);
      expect(cubit.state.earnedStars, 0);
    });

    test('DailyCubit UTC date formatting and nickname profanity filter work accurately', () {
      // 2026-11-15 02:30:00 in UTC+7 is 2026-11-14 19:30:00 UTC
      final localEarlyMorning = DateTime.utc(2026, 11, 14, 19, 30);
      expect(DailyCubit.formatTodayDateKey(localEarlyMorning), '2026-11-14');

      expect(DailyCubit.validatePlayerName('SpeedRacer_VN'), isNull);
      expect(DailyCubit.validatePlayerName('A'), isNotNull); // too short
      expect(DailyCubit.validatePlayerName('bad link http://spam.com'), isNotNull);
      expect(DailyCubit.validatePlayerName('player fuck 123'), isNotNull);
    });
  });
}

import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/tutorial_service.dart';
import '../../core/utils/level_parser.dart';
import '../../domain/engine/board_engine.dart';
import '../../domain/entities/board_state.dart';
import '../../domain/entities/level.dart';
import '../../domain/entities/move.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/solver/bfs_solver.dart';
import '../../domain/usecases/save_progress.dart';

class GameState extends Equatable {
  final Level level;
  final String initialBoardString;
  final BoardState boardState;
  final Move? activeHint;
  final bool isComputingHint;
  final int remainingHints;
  final bool isWon;
  final int earnedStars;
  final bool isMuted;
  final bool isTutorialMode;
  final List<Move> tutorialSteps;
  final int tutorialStepIndex;

  const GameState({
    required this.level,
    required this.initialBoardString,
    required this.boardState,
    this.activeHint,
    this.isComputingHint = false,
    this.remainingHints = 3,
    this.isWon = false,
    this.earnedStars = 0,
    this.isMuted = false,
    this.isTutorialMode = false,
    this.tutorialSteps = const [],
    this.tutorialStepIndex = 0,
  });

  bool get canUndo => boardState.canUndo && !isWon && !isTutorialMode;
  bool get canReset => boardState.moveCount > 0 && !isWon;
  bool get canHint =>
      !isWon && !isComputingHint && !isTutorialMode && remainingHints > 0;

  Move? get currentTutorialMove => (isTutorialMode &&
          !isWon &&
          tutorialStepIndex >= 0 &&
          tutorialStepIndex < tutorialSteps.length)
      ? tutorialSteps[tutorialStepIndex]
      : null;

  String? get tutorialInstruction {
    final move = currentTutorialMove;
    if (!isTutorialMode || move == null) return null;
    if (move.vehicleId == AppConstants.targetVehicleId) {
      return 'Slide the pink car out to the exit!';
    }
    return 'Slide the blocking vehicle to clear the path';
  }

  String? get tutorialDetailInstruction {
    final move = currentTutorialMove;
    if (!isTutorialMode || move == null) return null;
    final dCol = move.toCol - move.fromCol;
    final dRow = move.toRow - move.fromRow;
    if (move.vehicleId == AppConstants.targetVehicleId && dCol > 0) {
      return 'Drag the glowing pink car (↔) right to the hazard exit gate.';
    }
    if (dCol > 0) {
      return 'Drag right $dCol ${dCol == 1 ? 'cell' : 'cells'} into the glowing slot.';
    }
    if (dCol < 0) {
      final steps = -dCol;
      return 'Drag left $steps ${steps == 1 ? 'cell' : 'cells'} into the glowing slot.';
    }
    if (dRow > 0) {
      return 'Drag down $dRow ${dRow == 1 ? 'cell' : 'cells'} into the glowing slot.';
    }
    if (dRow < 0) {
      final steps = -dRow;
      return 'Drag up $steps ${steps == 1 ? 'cell' : 'cells'} into the glowing slot.';
    }
    return 'Drag the glowing vehicle into the highlighted slot.';
  }

  Set<String>? get unlockedVehicleIds {
    if (!isTutorialMode) return null;
    final move = currentTutorialMove;
    if (isWon || move == null) return const <String>{};
    return {move.vehicleId};
  }

  GameState copyWith({
    Level? level,
    String? initialBoardString,
    BoardState? boardState,
    Move? activeHint,
    bool clearHint = false,
    bool? isComputingHint,
    int? remainingHints,
    bool? isWon,
    int? earnedStars,
    bool? isMuted,
    bool? isTutorialMode,
    List<Move>? tutorialSteps,
    int? tutorialStepIndex,
  }) {
    return GameState(
      level: level ?? this.level,
      initialBoardString: initialBoardString ?? this.initialBoardString,
      boardState: boardState ?? this.boardState,
      activeHint: clearHint ? null : (activeHint ?? this.activeHint),
      isComputingHint: isComputingHint ?? this.isComputingHint,
      remainingHints: remainingHints ?? this.remainingHints,
      isWon: isWon ?? this.isWon,
      earnedStars: earnedStars ?? this.earnedStars,
      isMuted: isMuted ?? this.isMuted,
      isTutorialMode: isTutorialMode ?? this.isTutorialMode,
      tutorialSteps: tutorialSteps ?? this.tutorialSteps,
      tutorialStepIndex: tutorialStepIndex ?? this.tutorialStepIndex,
    );
  }

  @override
  List<Object?> get props => [
        level,
        initialBoardString,
        boardState,
        activeHint,
        isComputingHint,
        remainingHints,
        isWon,
        earnedStars,
        isMuted,
        isTutorialMode,
        tutorialSteps,
        tutorialStepIndex,
      ];
}

class GameCubit extends Cubit<GameState> {
  static const String _inProgressPrefix = 'rush_out_in_progress_level_';

  final SaveProgress? saveProgressUseCase;
  final AudioService audioService;
  final TutorialService? tutorialService;

  GameCubit({
    required Level level,
    required this.audioService,
    this.saveProgressUseCase,
    this.tutorialService,
    bool isTutorialMode = false,
  }) : super(
          _createInitialState(
            level: level,
            audioService: audioService,
            isTutorialMode: isTutorialMode,
          ),
        ) {
    if (!isTutorialMode) {
      _restoreInProgressState(level);
    }
  }

  static BoardState _safeParseBoard(String boardString, int optimalMoves) {
    try {
      return LevelParser.parseToBoardState(
        boardString,
        optimalMoves: optimalMoves,
      );
    } catch (_) {
      return BoardState(
        vehicles: const [],
        optimalMoves: optimalMoves,
      );
    }
  }

  static GameState _createInitialState({
    required Level level,
    required AudioService audioService,
    required bool isTutorialMode,
  }) {
    final initialBoard = _safeParseBoard(
      level.boardString,
      level.optimalMoves,
    );
    if (!isTutorialMode) {
      return GameState(
        level: level,
        initialBoardString: level.boardString,
        boardState: initialBoard,
        isMuted: audioService.isMuted,
      );
    }

    final solution = BfsSolver.solve(initialBoard) ?? const <Move>[];
    return GameState(
      level: level,
      initialBoardString: level.boardString,
      boardState: initialBoard,
      activeHint: solution.isNotEmpty ? solution.first : null,
      isMuted: audioService.isMuted,
      isTutorialMode: true,
      tutorialSteps: solution,
      tutorialStepIndex: 0,
    );
  }

  Future<void> _restoreInProgressState(Level level) async {
    if (level.id <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_inProgressPrefix${level.id}');
      if (raw == null ||
          isClosed ||
          state.level.id != level.id ||
          state.isWon ||
          state.boardState.moveCount > 0) {
        return;
      }

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedBoard = decoded['boardString'] as String?;
      final savedMoves = decoded['moveCount'] as int?;
      if (savedBoard == null || savedMoves == null || savedMoves <= 0) return;

      final rawHistory = decoded['moveHistory'];
      final List<Move> restoredHistory = [];
      if (rawHistory is List) {
        for (final item in rawHistory) {
          if (item is Map<String, dynamic>) {
            restoredHistory.add(Move.fromJson(item));
          } else if (item is Map) {
            restoredHistory.add(Move.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }

      final restored = LevelParser.parseToBoardState(
        savedBoard,
        optimalMoves: level.optimalMoves,
      ).copyWith(
        moveCount: savedMoves,
        moveHistory: restoredHistory,
      );

      if (!restored.isWon && !isClosed) {
        emit(state.copyWith(boardState: restored, clearHint: true));
      }
    } catch (_) {}
  }

  Future<void> _saveInProgressState(int levelId, BoardState board) async {
    if (levelId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_inProgressPrefix$levelId',
        jsonEncode({
          'boardString': board.toBoardString(),
          'moveCount': board.moveCount,
          'moveHistory': board.moveHistory.map((m) => m.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }

  Future<void> _clearInProgressState(int levelId) async {
    if (levelId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_inProgressPrefix$levelId');
    } catch (_) {}
  }

  void loadLevel(Level newLevel, {bool isTutorialMode = false}) {
    final parsedState = _safeParseBoard(
      newLevel.boardString,
      newLevel.optimalMoves,
    );
    final solution = isTutorialMode
        ? (BfsSolver.solve(parsedState) ?? const <Move>[])
        : const <Move>[];
    emit(
      GameState(
        level: newLevel,
        initialBoardString: newLevel.boardString,
        boardState: parsedState,
        activeHint: solution.isNotEmpty ? solution.first : null,
        remainingHints: state.remainingHints,
        isMuted: audioService.isMuted,
        isTutorialMode: isTutorialMode,
        tutorialSteps: solution,
        tutorialStepIndex: 0,
      ),
    );
    if (!isTutorialMode) {
      _restoreInProgressState(newLevel);
    }
  }

  void startTutorial({Level? level}) {
    loadLevel(level ?? state.level, isTutorialMode: true);
  }

  Future<void> skipTutorial() async {
    await tutorialService?.setTutorialCompleted(true);
    if (isClosed) return;
    loadLevel(state.level, isTutorialMode: false);
  }

  Future<void> skipCurrentLevel() async {
    if (state.isTutorialMode || state.isWon) return;
    if (saveProgressUseCase != null && state.level.id > 0) {
      await saveProgressUseCase!.skipLevel(
        levelId: state.level.id,
        difficulty: state.level.difficulty,
      );
    }
    await _clearInProgressState(state.level.id);
  }

  ({int minRow, int maxRow, int minCol, int maxCol})?
      dragBoundsForTutorialVehicle(Vehicle vehicle) {
    if (!state.isTutorialMode) return null;
    final expected = state.currentTutorialMove;
    if (expected == null || vehicle.id != expected.vehicleId) {
      return (
        minRow: vehicle.row,
        maxRow: vehicle.row,
        minCol: vehicle.col,
        maxCol: vehicle.col,
      );
    }
    if (vehicle.isHorizontal) {
      return (
        minRow: vehicle.row,
        maxRow: vehicle.row,
        minCol: math.min(vehicle.col, expected.toCol),
        maxCol: math.max(vehicle.col, expected.toCol),
      );
    }
    return (
      minRow: math.min(vehicle.row, expected.toRow),
      maxRow: math.max(vehicle.row, expected.toRow),
      minCol: vehicle.col,
      maxCol: vehicle.col,
    );
  }

  /// Computes valid movement bounds without emitting any BLoC state.
  MovementBounds onVehicleDragStart(String vehicleId) {
    audioService.playCarSelect();
    if (state.boardState.getVehicleById(vehicleId) == null) {
      return const MovementBounds(minRow: 0, maxRow: 0, minCol: 0, maxCol: 0);
    }
    return BoardEngine.getMovementBounds(state.boardState, vehicleId);
  }

  /// Called ONLY after the 100ms snap AnimationController finishes onPanEnd
  /// and the grid cell has changed.
  Future<void> onVehicleDragEnd(
    String vehicleId, {
    required double draggedRow,
    required double draggedCol,
  }) async {
    if (state.isWon || isClosed) return;

    if (state.isTutorialMode) {
      await _onTutorialDragEnd(
        vehicleId,
        draggedRow: draggedRow,
        draggedCol: draggedCol,
      );
      return;
    }

    final prevMoves = state.boardState.moveCount;
    final nextBoard = BoardEngine.snapVehicle(
      state.boardState,
      vehicleId,
      draggedRow: draggedRow,
      draggedCol: draggedCol,
    );

    final didMove = nextBoard.moveCount > prevMoves;
    if (!didMove) {
      return;
    }

    final currentLevel = state.level;

    if (nextBoard.isWon) {
      final stars = BoardEngine.calculateStars(
        userMoves: nextBoard.moveCount,
        optimalMoves: nextBoard.optimalMoves,
      );

      final oldBest = currentLevel.bestMoves;
      final newBest = (oldBest == null || nextBoard.moveCount < oldBest)
          ? nextBoard.moveCount
          : oldBest;
      final newStars = stars > currentLevel.stars ? stars : currentLevel.stars;

      final updatedLevel = currentLevel.copyWith(
        bestMoves: newBest,
        stars: newStars,
        isUnlocked: true,
      );

      final bonusHint = (stars == 3 && currentLevel.stars < 3) ? 1 : 0;

      // Commit state synchronously before awaiting audio/persistence so concurrent
      // multi-touch drags never read stale BoardState and drop/overwrite moves.
      emit(
        state.copyWith(
          level: updatedLevel,
          boardState: nextBoard,
          clearHint: true,
          isWon: true,
          earnedStars: stars,
          remainingHints: state.remainingHints + bonusHint,
        ),
      );

      await audioService.playSlide();
      if (isClosed) return;

      if (saveProgressUseCase != null && currentLevel.id > 0) {
        try {
          await saveProgressUseCase!(
            levelId: currentLevel.id,
            difficulty: currentLevel.difficulty,
            userMoves: nextBoard.moveCount,
            optimalMoves: nextBoard.optimalMoves,
          );
        } catch (_) {}
      }

      await _clearInProgressState(currentLevel.id);
      if (isClosed) return;

      await audioService.playWin();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!isClosed) {
          audioService.playStarPop();
        }
      });
    } else {
      // Commit move synchronously before any await to prevent concurrent drag races.
      emit(
        state.copyWith(
          boardState: nextBoard,
          clearHint: true,
        ),
      );

      await _saveInProgressState(currentLevel.id, nextBoard);
      if (isClosed) return;
      await audioService.playSlide();
    }
  }

  Future<void> _onTutorialDragEnd(
    String vehicleId, {
    required double draggedRow,
    required double draggedCol,
  }) async {
    final expected = state.currentTutorialMove;
    if (expected == null || vehicleId != expected.vehicleId) return;

    final currentVehicle = state.boardState.getVehicleById(vehicleId);
    if (currentVehicle == null) return;

    final bounds = dragBoundsForTutorialVehicle(currentVehicle)!;
    final clampedRow =
        draggedRow.round().clamp(bounds.minRow, bounds.maxRow).toDouble();
    final clampedCol =
        draggedCol.round().clamp(bounds.minCol, bounds.maxCol).toDouble();

    final prevMoves = state.boardState.moveCount;
    final nextBoard = BoardEngine.snapVehicle(
      state.boardState,
      vehicleId,
      draggedRow: clampedRow,
      draggedCol: clampedCol,
    );

    if (nextBoard.moveCount <= prevMoves) {
      return;
    }

    final movedVehicle = nextBoard.getVehicleById(vehicleId);
    final reachedTarget = movedVehicle != null &&
        movedVehicle.row == expected.toRow &&
        movedVehicle.col == expected.toCol;

    if (!reachedTarget) {
      // Do not penalize moveCount for a partial drag; keep the step intact
      // so the vehicle snaps back and the player can complete the full slide.
      return;
    }

    final currentLevel = state.level;
    final nextStepIndex = state.tutorialStepIndex + 1;
    if (nextBoard.isWon || nextStepIndex >= state.tutorialSteps.length) {
      final stars = BoardEngine.calculateStars(
        userMoves: nextBoard.moveCount,
        optimalMoves: nextBoard.optimalMoves,
      );
      final oldBest = currentLevel.bestMoves;
      final newBest = (oldBest == null || nextBoard.moveCount < oldBest)
          ? nextBoard.moveCount
          : oldBest;
      final newStars = stars > currentLevel.stars ? stars : currentLevel.stars;
      final updatedLevel = currentLevel.copyWith(
        bestMoves: newBest,
        stars: newStars,
        isUnlocked: true,
      );

      emit(
        state.copyWith(
          level: updatedLevel,
          boardState: nextBoard,
          clearHint: true,
          isWon: true,
          earnedStars: stars,
        ),
      );

      await audioService.playSlide();
      if (isClosed) return;

      await tutorialService?.setTutorialCompleted(true);
      if (saveProgressUseCase != null && currentLevel.id > 0) {
        try {
          await saveProgressUseCase!(
            levelId: currentLevel.id,
            difficulty: currentLevel.difficulty,
            userMoves: nextBoard.moveCount,
            optimalMoves: nextBoard.optimalMoves,
          );
        } catch (_) {}
      }

      await _clearInProgressState(currentLevel.id);
      if (isClosed) return;

      await audioService.playWin();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!isClosed) {
          audioService.playStarPop();
        }
      });
    } else {
      final nextMove = state.tutorialSteps[nextStepIndex];
      emit(
        state.copyWith(
          boardState: nextBoard,
          tutorialStepIndex: nextStepIndex,
          activeHint: nextMove,
        ),
      );
      await audioService.playSlide();
    }
  }

  void undo() {
    if (!state.canUndo) return;
    final prevBoard = BoardEngine.undo(state.boardState);
    audioService.playUndoWhoosh();
    _saveInProgressState(state.level.id, prevBoard);
    emit(
      state.copyWith(
        boardState: prevBoard,
        clearHint: true,
        isWon: false,
        earnedStars: 0,
      ),
    );
  }

  void reset() {
    final resetBoard = BoardEngine.reset(
      state.boardState,
      initialBoardString: state.initialBoardString,
    );
    audioService.playUndoWhoosh();
    _clearInProgressState(state.level.id);
    if (state.isTutorialMode) {
      final firstMove =
          state.tutorialSteps.isNotEmpty ? state.tutorialSteps.first : null;
      emit(
        state.copyWith(
          boardState: resetBoard,
          activeHint: firstMove,
          clearHint: firstMove == null,
          tutorialStepIndex: 0,
          isWon: false,
          earnedStars: 0,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        boardState: resetBoard,
        clearHint: true,
        isWon: false,
        earnedStars: 0,
      ),
    );
  }

  Future<bool> requestHint() async {
    if (state.isTutorialMode ||
        state.isWon ||
        state.isComputingHint ||
        state.remainingHints <= 0) {
      return true;
    }

    emit(state.copyWith(isComputingHint: true));
    final snapshot = state.boardState;

    final hintMove = await Isolate.run(
      () => BfsSolver.findNextMove(snapshot, maxVisitedStates: 100000),
    );

    if (isClosed) return true;

    if (hintMove != null) {
      audioService.playHintPing();
      emit(
        state.copyWith(
          activeHint: hintMove,
          isComputingHint: false,
          remainingHints: state.remainingHints - 1,
        ),
      );
      return true;
    } else {
      emit(state.copyWith(isComputingHint: false));
      return false;
    }
  }

  Future<void> toggleMute() async {
    final muted = await audioService.toggleMute();
    if (isClosed) return;
    emit(state.copyWith(isMuted: muted));
  }
}

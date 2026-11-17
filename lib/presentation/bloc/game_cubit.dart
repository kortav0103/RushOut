import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/error_reporting_service.dart';
import '../../core/services/tutorial_service.dart';
import '../../core/utils/level_parser.dart';
import '../../domain/engine/board_engine.dart';
import '../../domain/entities/board_state.dart';
import '../../domain/entities/level.dart';
import '../../domain/entities/move.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/repositories/level_repository.dart';
import '../../domain/solver/bfs_solver.dart';
import '../../domain/usecases/save_progress.dart';

class GameState extends Equatable {
  static const int maxActiveSkippedLevels = 3;
  static const int defaultHintsPerLevel = 2;

  final Level level;
  final List<Level> campaignLevels;
  final String initialBoardString;
  final BoardState boardState;
  final Move? activeHint;
  final bool isComputingHint;
  final int remainingHints;
  final bool isWon;
  final int earnedStars;
  final bool isMuted;
  final bool isTutorialMode;
  final bool isLoadingTutorial;
  final List<Move> tutorialSteps;
  final int tutorialStepIndex;
  final Level? tutorialReturnLevel;
  final String? saveErrorMessage;

  const GameState({
    required this.level,
    this.campaignLevels = const [],
    required this.initialBoardString,
    required this.boardState,
    this.activeHint,
    this.isComputingHint = false,
    this.remainingHints = defaultHintsPerLevel,
    this.isWon = false,
    this.earnedStars = 0,
    this.isMuted = false,
    this.isTutorialMode = false,
    this.isLoadingTutorial = false,
    this.tutorialSteps = const [],
    this.tutorialStepIndex = 0,
    this.tutorialReturnLevel,
    this.saveErrorMessage,
  });

  bool get canUndo => boardState.canUndo && !isWon && !isTutorialMode;
  bool get canReset =>
      boardState.moveCount > 0 && !isWon && !isLoadingTutorial;
  bool get canHint =>
      !isWon && !isComputingHint && !isTutorialMode && remainingHints > 0;

  bool get isTutorialReplay => isTutorialMode && tutorialReturnLevel != null;

  int get activeSkippedCount =>
      campaignLevels.where((l) => l.isSkipped && l.stars == 0).length;

  Level? get nextLevel {
    if (campaignLevels.isEmpty) return null;
    final idx = campaignLevels.indexWhere((l) => l.id == level.id);
    if (idx >= 0 && idx + 1 < campaignLevels.length) {
      return campaignLevels[idx + 1];
    }
    for (final candidate in campaignLevels) {
      if (candidate.id == level.id + 1) return candidate;
    }
    return null;
  }

  bool get hasNextLevel => isTutorialReplay || nextLevel != null;

  int get requiredMovesToSkip => math.min(5, math.max(2, level.optimalMoves));

  int get movesRemainingToUnlockSkip =>
      math.max(0, requiredMovesToSkip - boardState.moveCount);

  bool get canShowSkipButton =>
      !isTutorialMode &&
      !isWon &&
      nextLevel != null &&
      level.stars == 0 &&
      !level.isSkipped;

  bool get isSkipQuotaReached => activeSkippedCount >= maxActiveSkippedLevels;

  bool get canSkipLevel =>
      canShowSkipButton &&
      boardState.moveCount >= requiredMovesToSkip &&
      !isSkipQuotaReached;

  String? get skipLockedReason {
    if (!canShowSkipButton || canSkipLevel) return null;
    if (isSkipQuotaReached) {
      return 'Skip limit reached ($maxActiveSkippedLevels/$maxActiveSkippedLevels). Clear a skipped level first!';
    }
    return 'Try $movesRemainingToUnlockSkip more ${movesRemainingToUnlockSkip == 1 ? 'move' : 'moves'} to unlock Skip!';
  }

  Move? get currentTutorialMove => (isTutorialMode &&
          !isLoadingTutorial &&
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
    List<Level>? campaignLevels,
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
    bool? isLoadingTutorial,
    List<Move>? tutorialSteps,
    int? tutorialStepIndex,
    Level? tutorialReturnLevel,
    bool clearTutorialReturnLevel = false,
    String? saveErrorMessage,
    bool clearSaveError = false,
  }) {
    return GameState(
      level: level ?? this.level,
      campaignLevels: campaignLevels ?? this.campaignLevels,
      initialBoardString: initialBoardString ?? this.initialBoardString,
      boardState: boardState ?? this.boardState,
      activeHint: clearHint ? null : (activeHint ?? this.activeHint),
      isComputingHint: isComputingHint ?? this.isComputingHint,
      remainingHints: remainingHints ?? this.remainingHints,
      isWon: isWon ?? this.isWon,
      earnedStars: earnedStars ?? this.earnedStars,
      isMuted: isMuted ?? this.isMuted,
      isTutorialMode: isTutorialMode ?? this.isTutorialMode,
      isLoadingTutorial: isLoadingTutorial ?? this.isLoadingTutorial,
      tutorialSteps: tutorialSteps ?? this.tutorialSteps,
      tutorialStepIndex: tutorialStepIndex ?? this.tutorialStepIndex,
      tutorialReturnLevel: clearTutorialReturnLevel
          ? null
          : (tutorialReturnLevel ?? this.tutorialReturnLevel),
      saveErrorMessage: clearSaveError
          ? null
          : (saveErrorMessage ?? this.saveErrorMessage),
    );
  }

  @override
  List<Object?> get props => [
        level,
        campaignLevels,
        initialBoardString,
        boardState,
        activeHint,
        isComputingHint,
        remainingHints,
        isWon,
        earnedStars,
        isMuted,
        isTutorialMode,
        isLoadingTutorial,
        tutorialSteps,
        tutorialStepIndex,
        tutorialReturnLevel,
        saveErrorMessage,
      ];
}

class GameCubit extends Cubit<GameState> {
  final SaveProgress? saveProgressUseCase;
  final LevelRepository? levelRepository;
  final AudioService audioService;
  final TutorialService? tutorialService;
  final Future<Move?> Function(BoardState board)? hintSolver;
  final Future<List<Move>?> Function(BoardState board)? tutorialSolver;

  int _hintRequestId = 0;
  int _tutorialRequestId = 0;
  int _boardEpoch = 0;
  Future<void> _persistenceQueue = Future<void>.value();

  GameCubit({
    required Level level,
    List<Level> initialLevels = const [],
    required this.audioService,
    this.saveProgressUseCase,
    LevelRepository? levelRepository,
    this.tutorialService,
    this.hintSolver,
    this.tutorialSolver,
    bool isTutorialMode = false,
    Level? tutorialReturnLevel,
  })  : levelRepository = levelRepository ?? saveProgressUseCase?.repository,
        super(
          _createInitialState(
            level: level,
            initialLevels: initialLevels,
            audioService: audioService,
            isTutorialMode: isTutorialMode,
            tutorialReturnLevel: tutorialReturnLevel,
          ),
        ) {
    if (isTutorialMode) {
      _solveTutorialSteps(
        state.boardState,
        levelId: level.id,
        epoch: _boardEpoch,
      );
    } else {
      _restoreInProgressState(level, expectedEpoch: _boardEpoch);
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
    required List<Level> initialLevels,
    required AudioService audioService,
    required bool isTutorialMode,
    Level? tutorialReturnLevel,
  }) {
    final initialBoard = _safeParseBoard(
      level.boardString,
      level.optimalMoves,
    );
    final immutableLevels = initialLevels.isEmpty
        ? const <Level>[]
        : List<Level>.unmodifiable(initialLevels);
    return GameState(
      level: level,
      campaignLevels: immutableLevels,
      initialBoardString: level.boardString,
      boardState: initialBoard,
      isMuted: audioService.isMuted,
      isTutorialMode: isTutorialMode,
      isLoadingTutorial: isTutorialMode,
      tutorialSteps: const <Move>[],
      tutorialStepIndex: 0,
      tutorialReturnLevel: isTutorialMode ? tutorialReturnLevel : null,
    );
  }

  Future<void> _solveTutorialSteps(
    BoardState initialBoard, {
    required int levelId,
    required int epoch,
  }) async {
    final requestId = ++_tutorialRequestId;
    List<Move>? solution;
    try {
      solution = await (tutorialSolver != null
          ? tutorialSolver!(initialBoard)
          : Isolate.run(() => BfsSolver.solve(initialBoard)));
    } catch (_) {
      solution = const <Move>[];
    }

    if (isClosed ||
        _tutorialRequestId != requestId ||
        _boardEpoch != epoch ||
        !state.isTutorialMode ||
        state.level.id != levelId) {
      return;
    }

    final steps = solution ?? const <Move>[];
    emit(
      state.copyWith(
        isLoadingTutorial: false,
        tutorialSteps: steps,
        tutorialStepIndex: 0,
        activeHint: steps.isNotEmpty ? steps.first : null,
        clearHint: steps.isEmpty,
      ),
    );
  }

  Future<void> _enqueuePersistence(Future<void> Function() action) {
    final next = _persistenceQueue.then((_) => action()).catchError((_) {});
    _persistenceQueue = next;
    return next;
  }

  Future<void> _restoreInProgressState(
    Level level, {
    required int expectedEpoch,
  }) {
    final repo = levelRepository;
    if (repo == null || level.id <= 0) return Future<void>.value();
    return _enqueuePersistence(() async {
      if (isClosed ||
          _boardEpoch != expectedEpoch ||
          state.isTutorialMode ||
          state.level.id != level.id ||
          state.isWon ||
          state.boardState.moveCount > 0) {
        return;
      }

      try {
        final saved = await repo.getInProgressLevel(
          level.id,
          expectedBoardString: level.boardString,
        );
        if (saved == null ||
            isClosed ||
            _boardEpoch != expectedEpoch ||
            state.isTutorialMode ||
            state.level.id != level.id ||
            state.isWon ||
            state.boardState.moveCount > 0) {
          return;
        }

        final restored = LevelParser.parseToBoardState(
          saved.boardString,
          optimalMoves: level.optimalMoves,
        ).copyWith(
          moveCount: saved.moveCount,
          moveHistory: saved.moveHistory,
        );

        if (!restored.isWon && !isClosed) {
          emit(state.copyWith(boardState: restored, clearHint: true));
        }
      } catch (_) {}
    });
  }

  Future<void> _saveInProgressState(
    int levelId,
    BoardState board, {
    required int expectedEpoch,
  }) {
    final repo = levelRepository;
    if (repo == null || levelId <= 0) return Future<void>.value();
    return _enqueuePersistence(() async {
      if (_boardEpoch != expectedEpoch) return;
      if (board.moveCount <= 0) {
        await repo.clearInProgressLevel(levelId);
      } else {
        await repo.saveInProgressLevel(
          InProgressLevelState(
            levelId: levelId,
            boardString: board.toBoardString(),
            moveCount: board.moveCount,
            moveHistory: board.moveHistory,
          ),
        );
      }
    });
  }

  Future<void> _clearInProgressState(int levelId) {
    final repo = levelRepository;
    if (repo == null || levelId <= 0) return Future<void>.value();
    return _enqueuePersistence(() => repo.clearInProgressLevel(levelId));
  }

  List<Level> _withUpdatedCampaignProgress(
    List<Level> levels, {
    required Level updatedLevel,
    bool unlockNext = true,
  }) {
    if (levels.isEmpty) return levels;
    bool unlockFollowing = false;
    final List<Level> updated = [];
    for (int i = 0; i < levels.length; i++) {
      final item = levels[i];
      if (item.id == updatedLevel.id) {
        updated.add(updatedLevel);
        if (unlockNext && i + 1 < levels.length) {
          unlockFollowing = true;
        }
      } else if (unlockFollowing) {
        updated.add(item.isUnlocked ? item : item.copyWith(isUnlocked: true));
        unlockFollowing = false;
      } else if (unlockNext &&
          item.id == updatedLevel.id + 1 &&
          !item.isUnlocked) {
        updated.add(item.copyWith(isUnlocked: true));
      } else {
        updated.add(item);
      }
    }
    return List<Level>.unmodifiable(updated);
  }

  void loadLevel(
    Level newLevel, {
    bool isTutorialMode = false,
    Level? tutorialReturnLevel,
  }) {
    _boardEpoch++;
    _hintRequestId++;
    _tutorialRequestId++;
    final parsedState = _safeParseBoard(
      newLevel.boardString,
      newLevel.optimalMoves,
    );
    emit(
      GameState(
        level: newLevel,
        campaignLevels: state.campaignLevels,
        initialBoardString: newLevel.boardString,
        boardState: parsedState,
        remainingHints: GameState.defaultHintsPerLevel,
        isMuted: audioService.isMuted,
        isTutorialMode: isTutorialMode,
        isLoadingTutorial: isTutorialMode,
        tutorialSteps: const <Move>[],
        tutorialStepIndex: 0,
        tutorialReturnLevel: isTutorialMode ? tutorialReturnLevel : null,
      ),
    );
    if (isTutorialMode) {
      _solveTutorialSteps(
        parsedState,
        levelId: newLevel.id,
        epoch: _boardEpoch,
      );
    } else {
      _restoreInProgressState(newLevel, expectedEpoch: _boardEpoch);
    }
  }

  void startTutorial({Level? level, Level? returnToLevel}) {
    loadLevel(
      level ?? state.level,
      isTutorialMode: true,
      tutorialReturnLevel: returnToLevel,
    );
  }

  void replayTutorial() {
    final tutorialLevel = state.campaignLevels.isNotEmpty
        ? state.campaignLevels.first
        : state.level;
    loadLevel(
      tutorialLevel,
      isTutorialMode: true,
      tutorialReturnLevel: state.level,
    );
  }

  void loadNextLevel() {
    if (state.isTutorialReplay) {
      final returnLevel = state.tutorialReturnLevel!;
      loadLevel(returnLevel, isTutorialMode: false);
      return;
    }
    final next = state.nextLevel;
    if (next == null) return;
    final unlockedNext =
        next.isUnlocked ? next : next.copyWith(isUnlocked: true);
    loadLevel(unlockedNext, isTutorialMode: false);
  }

  Future<void> skipTutorial() async {
    await tutorialService?.setTutorialCompleted(true);
    if (isClosed) return;
    if (state.isTutorialReplay) {
      loadLevel(state.tutorialReturnLevel!, isTutorialMode: false);
    } else {
      loadLevel(state.level, isTutorialMode: false);
    }
  }

  Future<bool> skipCurrentLevel() async {
    if (!state.canSkipLevel) return false;
    final currentLevel = state.level;
    final next = state.nextLevel;
    if (next == null) return false;

    final repo = levelRepository;
    if (saveProgressUseCase != null && currentLevel.id > 0) {
      try {
        await saveProgressUseCase!.skipLevel(
          levelId: currentLevel.id,
          difficulty: currentLevel.difficulty,
        );
      } catch (_) {
        return false;
      }
    } else if (repo != null && currentLevel.id > 0) {
      try {
        await repo.skipLevel(
          levelId: currentLevel.id,
          difficulty: currentLevel.difficulty,
        );
      } catch (_) {
        return false;
      }
    }

    _boardEpoch++;
    final updatedCurrent = currentLevel.copyWith(
      isUnlocked: true,
      isSkipped: currentLevel.stars == 0,
    );
    final updatedCampaign = _withUpdatedCampaignProgress(
      state.campaignLevels,
      updatedLevel: updatedCurrent,
    );
    await _clearInProgressState(currentLevel.id);
    if (isClosed) return true;

    final unlockedNext =
        next.isUnlocked ? next : next.copyWith(isUnlocked: true);
    emit(state.copyWith(campaignLevels: updatedCampaign));
    loadLevel(unlockedNext, isTutorialMode: false);
    return true;
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
    final vehicle = state.boardState.getVehicleById(vehicleId);
    if (vehicle == null) {
      return const MovementBounds(minRow: 0, maxRow: 0, minCol: 0, maxCol: 0);
    }
    if (state.isWon) {
      return MovementBounds(
        minRow: vehicle.row,
        maxRow: vehicle.row,
        minCol: vehicle.col,
        maxCol: vehicle.col,
      );
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
    final epoch = ++_boardEpoch;

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
        isSkipped: false,
      );
      final updatedCampaign = _withUpdatedCampaignProgress(
        state.campaignLevels,
        updatedLevel: updatedLevel,
      );

      _hintRequestId++;

      // Commit state synchronously before awaiting audio/persistence so concurrent
      // multi-touch drags never read stale BoardState and drop/overwrite moves.
      emit(
        state.copyWith(
          level: updatedLevel,
          campaignLevels: updatedCampaign,
          boardState: nextBoard,
          clearHint: true,
          isComputingHint: false,
          isWon: true,
          earnedStars: stars,
          clearSaveError: true,
        ),
      );

      if (saveProgressUseCase != null && currentLevel.id > 0) {
        try {
          await saveProgressUseCase!(
            levelId: currentLevel.id,
            difficulty: currentLevel.difficulty,
            userMoves: nextBoard.moveCount,
            optimalMoves: nextBoard.optimalMoves,
          );
        } catch (e, stack) {
          ErrorReportingService.instance.recordError(
            e,
            stack,
            fatal: false,
            context: 'GameCubit.onVehicleDragEnd.saveProgress',
          );
          if (!isClosed) {
            emit(
              state.copyWith(
                saveErrorMessage:
                    'Could not save level progress locally. Your progress may not persist.',
              ),
            );
          }
        }
      }

      await _clearInProgressState(currentLevel.id);
      if (isClosed) return;

      await audioService.playSlide();
      if (isClosed) return;

      await audioService.playWin();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!isClosed) {
          audioService.playStarPop();
        }
      });
    } else {
      _hintRequestId++;
      // Commit move synchronously before any await to prevent concurrent drag races.
      emit(
        state.copyWith(
          boardState: nextBoard,
          clearHint: true,
          isComputingHint: false,
          clearSaveError: true,
        ),
      );

      await _saveInProgressState(
        currentLevel.id,
        nextBoard,
        expectedEpoch: epoch,
      );
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
    _boardEpoch++;
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
        isSkipped: false,
      );
      final updatedCampaign = _withUpdatedCampaignProgress(
        state.campaignLevels,
        updatedLevel: updatedLevel,
      );

      emit(
        state.copyWith(
          level: updatedLevel,
          campaignLevels: updatedCampaign,
          boardState: nextBoard,
          clearHint: true,
          isWon: true,
          earnedStars: stars,
          clearSaveError: true,
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
        } catch (e, stack) {
          ErrorReportingService.instance.recordError(
            e,
            stack,
            fatal: false,
            context: 'GameCubit._onTutorialDragEnd.saveProgress',
          );
          if (!isClosed) {
            emit(
              state.copyWith(
                saveErrorMessage:
                    'Could not save level progress locally. Your progress may not persist.',
              ),
            );
          }
        }
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
    final epoch = ++_boardEpoch;
    _hintRequestId++;
    final prevBoard = BoardEngine.undo(state.boardState);
    audioService.playUndoWhoosh();
    _saveInProgressState(
      state.level.id,
      prevBoard,
      expectedEpoch: epoch,
    );
    emit(
      state.copyWith(
        boardState: prevBoard,
        clearHint: true,
        isComputingHint: false,
        isWon: false,
        earnedStars: 0,
        clearSaveError: true,
      ),
    );
  }

  void reset() {
    _boardEpoch++;
    _hintRequestId++;
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
          isComputingHint: false,
          tutorialStepIndex: 0,
          isWon: false,
          earnedStars: 0,
          clearSaveError: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        boardState: resetBoard,
        clearHint: true,
        isComputingHint: false,
        isWon: false,
        earnedStars: 0,
        clearSaveError: true,
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

    final requestId = ++_hintRequestId;
    final snapshot = state.boardState;
    final snapshotLevelId = state.level.id;
    emit(state.copyWith(isComputingHint: true));

    final hintMove = await (hintSolver != null
        ? hintSolver!(snapshot)
        : Isolate.run(
            () => BfsSolver.findNextMove(snapshot, maxVisitedStates: 100000),
          ));

    if (isClosed) return true;

    // Guard against async race: ignore stale result if user moved, undid, reset,
    // switched levels, or already won while BFS was running.
    if (_hintRequestId != requestId ||
        state.isTutorialMode ||
        state.isWon ||
        state.level.id != snapshotLevelId ||
        state.boardState != snapshot) {
      if (state.isComputingHint && _hintRequestId == requestId) {
        emit(state.copyWith(isComputingHint: false));
      }
      return true;
    }

    if (hintMove != null) {
      audioService.playHintPing();
      emit(
        state.copyWith(
          activeHint: hintMove,
          isComputingHint: false,
          remainingHints: math.max(0, state.remainingHints - 1),
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

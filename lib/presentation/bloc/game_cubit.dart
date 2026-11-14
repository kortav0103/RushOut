import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/audio_service.dart';
import '../../core/utils/level_parser.dart';
import '../../domain/engine/board_engine.dart';
import '../../domain/entities/board_state.dart';
import '../../domain/entities/level.dart';
import '../../domain/entities/move.dart';
import '../../domain/solver/bfs_solver.dart';
import '../../domain/usecases/save_progress.dart';

class GameState extends Equatable {
  final Level level;
  final String initialBoardString;
  final BoardState boardState;
  final Move? activeHint;
  final bool isWon;
  final int earnedStars;
  final bool isMuted;

  const GameState({
    required this.level,
    required this.initialBoardString,
    required this.boardState,
    this.activeHint,
    this.isWon = false,
    this.earnedStars = 0,
    this.isMuted = false,
  });

  bool get canUndo => boardState.canUndo && !isWon;
  bool get canReset => boardState.moveCount > 0 && !isWon;

  GameState copyWith({
    Level? level,
    String? initialBoardString,
    BoardState? boardState,
    Move? activeHint,
    bool clearHint = false,
    bool? isWon,
    int? earnedStars,
    bool? isMuted,
  }) {
    return GameState(
      level: level ?? this.level,
      initialBoardString: initialBoardString ?? this.initialBoardString,
      boardState: boardState ?? this.boardState,
      activeHint: clearHint ? null : (activeHint ?? this.activeHint),
      isWon: isWon ?? this.isWon,
      earnedStars: earnedStars ?? this.earnedStars,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  @override
  List<Object?> get props => [
        level,
        initialBoardString,
        boardState,
        activeHint,
        isWon,
        earnedStars,
        isMuted,
      ];
}

class GameCubit extends Cubit<GameState> {
  final SaveProgress? saveProgressUseCase;
  final AudioService audioService;

  GameCubit({
    required Level level,
    required this.audioService,
    this.saveProgressUseCase,
  }) : super(
          GameState(
            level: level,
            initialBoardString: level.boardString,
            boardState: LevelParser.parseToBoardState(
              level.boardString,
              optimalMoves: level.optimalMoves,
            ),
            isMuted: audioService.isMuted,
          ),
        );

  void loadLevel(Level newLevel) {
    final parsedState = LevelParser.parseToBoardState(
      newLevel.boardString,
      optimalMoves: newLevel.optimalMoves,
    );
    emit(
      GameState(
        level: newLevel,
        initialBoardString: newLevel.boardString,
        boardState: parsedState,
        isMuted: audioService.isMuted,
      ),
    );
  }

  /// Computes valid movement bounds without emitting any BLoC state.
  MovementBounds onVehicleDragStart(String vehicleId) {
    audioService.playCarSelect();
    return BoardEngine.getMovementBounds(state.boardState, vehicleId);
  }

  /// Called ONLY after the 100ms snap AnimationController finishes onPanEnd
  /// and the grid cell has changed.
  Future<void> onVehicleDragEnd(
    String vehicleId, {
    required double draggedRow,
    required double draggedCol,
  }) async {
    if (state.isWon) return;

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

    await audioService.playSlide();

    if (nextBoard.isWon) {
      final stars = BoardEngine.calculateStars(
        userMoves: nextBoard.moveCount,
        optimalMoves: nextBoard.optimalMoves,
      );
      emit(
        state.copyWith(
          boardState: nextBoard,
          clearHint: true,
          isWon: true,
          earnedStars: stars,
        ),
      );
      await audioService.playWin();
      await audioService.playStarPop();

      if (saveProgressUseCase != null && state.level.id > 0) {
        await saveProgressUseCase!(
          levelId: state.level.id,
          difficulty: state.level.difficulty,
          userMoves: nextBoard.moveCount,
          optimalMoves: nextBoard.optimalMoves,
        );
      }
    } else {
      emit(
        state.copyWith(
          boardState: nextBoard,
          clearHint: true,
        ),
      );
    }
  }

  void undo() {
    if (!state.canUndo) return;
    final prevBoard = BoardEngine.undo(state.boardState);
    audioService.playUndoWhoosh();
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
    emit(
      state.copyWith(
        boardState: resetBoard,
        clearHint: true,
        isWon: false,
        earnedStars: 0,
      ),
    );
  }

  void requestHint() {
    if (state.isWon) return;
    final hintMove = BfsSolver.findNextMove(state.boardState);
    if (hintMove != null) {
      audioService.playHintPing();
      emit(state.copyWith(activeHint: hintMove));
    }
  }

  Future<void> toggleMute() async {
    final muted = await audioService.toggleMute();
    emit(state.copyWith(isMuted: muted));
  }
}

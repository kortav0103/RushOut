import 'dart:isolate';
import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/error/exceptions.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/player_identity_service.dart';
import '../../core/utils/level_parser.dart';
import '../../domain/engine/board_engine.dart';
import '../../domain/entities/board_state.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/move.dart';
import '../../domain/repositories/daily_challenge_repository.dart';
import '../../domain/repositories/level_repository.dart';
import '../../domain/solver/bfs_solver.dart';
import '../../domain/usecases/submit_score.dart';

enum DailyViewStatus { loading, content, empty, error }

class DailyState extends Equatable {
  final DailyViewStatus status;
  final String dateKey;
  final DailyChallenge? challenge;
  final BoardState? boardState;
  final Move? activeHint;
  final bool isComputingHint;
  final int remainingHints;
  final bool isWon;
  final int earnedStars;
  final bool isSubmittingScore;
  final bool scoreSubmitted;
  final String? errorMessage;
  final String? submitErrorMessage;

  const DailyState({
    this.status = DailyViewStatus.loading,
    required this.dateKey,
    this.challenge,
    this.boardState,
    this.activeHint,
    this.isComputingHint = false,
    this.remainingHints = 3,
    this.isWon = false,
    this.earnedStars = 0,
    this.isSubmittingScore = false,
    this.scoreSubmitted = false,
    this.errorMessage,
    this.submitErrorMessage,
  });

  bool get canUndo => (boardState?.canUndo ?? false) && !isWon;
  bool get canReset => ((boardState?.moveCount ?? 0) > 0) && !isWon;

  DailyState copyWith({
    DailyViewStatus? status,
    String? dateKey,
    DailyChallenge? challenge,
    BoardState? boardState,
    Move? activeHint,
    bool clearHint = false,
    bool? isComputingHint,
    int? remainingHints,
    bool? isWon,
    int? earnedStars,
    bool? isSubmittingScore,
    bool? scoreSubmitted,
    String? errorMessage,
    bool clearError = false,
    String? submitErrorMessage,
    bool clearSubmitError = false,
  }) {
    return DailyState(
      status: status ?? this.status,
      dateKey: dateKey ?? this.dateKey,
      challenge: challenge ?? this.challenge,
      boardState: boardState ?? this.boardState,
      activeHint: clearHint ? null : (activeHint ?? this.activeHint),
      isComputingHint: isComputingHint ?? this.isComputingHint,
      remainingHints: remainingHints ?? this.remainingHints,
      isWon: isWon ?? this.isWon,
      earnedStars: earnedStars ?? this.earnedStars,
      isSubmittingScore: isSubmittingScore ?? this.isSubmittingScore,
      scoreSubmitted: scoreSubmitted ?? this.scoreSubmitted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      submitErrorMessage: clearSubmitError
          ? null
          : (submitErrorMessage ?? this.submitErrorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        dateKey,
        challenge,
        boardState,
        activeHint,
        isComputingHint,
        remainingHints,
        isWon,
        earnedStars,
        isSubmittingScore,
        scoreSubmitted,
        errorMessage,
        submitErrorMessage,
      ];
}

class DailyCubit extends Cubit<DailyState> {
  final DailyChallengeRepository dailyRepository;
  final SubmitScore submitScoreUseCase;
  final AudioService audioService;
  final LevelRepository? levelRepository;
  final Future<Move?> Function(BoardState board)? hintSolver;

  int _hintRequestId = 0;

  DailyCubit({
    required this.dailyRepository,
    required this.submitScoreUseCase,
    required this.audioService,
    this.levelRepository,
    this.hintSolver,
    String? initialDateKey,
  }) : super(
          DailyState(
            status: DailyViewStatus.loading,
            dateKey: initialDateKey ?? formatTodayDateKey(),
          ),
        );

  /// Synchronizes with Supabase PostgreSQL CURRENT_DATE (UTC) to prevent
  /// timezone mismatch bugs.
  static String formatTodayDateKey([DateTime? now]) {
    final dt = (now ?? DateTime.now()).toUtc();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Validates player nickname for UGC compliance (length, characters, profanity).
  static String? validatePlayerName(String rawName) =>
      PlayerIdentityService.validateUsername(rawName);

  Future<void> loadDailyChallenge({String? dateKey}) async {
    _hintRequestId++;
    final targetDate = dateKey ?? state.dateKey;
    final preservedHints =
        targetDate == state.dateKey ? state.remainingHints : 3;
    emit(
      state.copyWith(
        status: DailyViewStatus.loading,
        dateKey: targetDate,
        clearError: true,
        clearHint: true,
        isComputingHint: false,
        remainingHints: preservedHints,
        isWon: false,
        earnedStars: 0,
        scoreSubmitted: false,
        clearSubmitError: true,
      ),
    );

    try {
      int? persistedHints;
      if (levelRepository != null) {
        try {
          persistedHints = await levelRepository!.getRemainingHints();
        } catch (_) {}
      }

      final challenge = await dailyRepository.getDailyChallenge(targetDate);
      if (isClosed) return;
      if (challenge.boardString.trim().isEmpty) {
        emit(
          state.copyWith(
            status: DailyViewStatus.empty,
            remainingHints: persistedHints ?? state.remainingHints,
            errorMessage: 'No Daily Challenge is available for $targetDate.',
          ),
        );
        return;
      }

      final parsedBoard = LevelParser.parseToBoardState(
        challenge.boardString,
        optimalMoves: challenge.optimalMoves,
      );

      if (isClosed) return;
      if (challenge.isCompleted) {
        final solvedMoves = challenge.userMoves ?? challenge.optimalMoves;
        final stars = BoardEngine.calculateStars(
          userMoves: solvedMoves,
          optimalMoves: challenge.optimalMoves,
        );
        emit(
          state.copyWith(
            status: DailyViewStatus.content,
            challenge: challenge,
            boardState: parsedBoard.copyWith(moveCount: solvedMoves),
            remainingHints: persistedHints ?? state.remainingHints,
            isWon: true,
            earnedStars: stars,
            scoreSubmitted: challenge.scoreSubmitted,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: DailyViewStatus.content,
          challenge: challenge,
          boardState: parsedBoard,
          remainingHints: persistedHints ?? state.remainingHints,
          isWon: false,
          earnedStars: 0,
          scoreSubmitted: challenge.scoreSubmitted,
        ),
      );
    } on EmptyDataException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DailyViewStatus.empty,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DailyViewStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Computes valid movement bounds without emitting any BLoC state.
  MovementBounds onVehicleDragStart(String vehicleId) {
    audioService.playCarSelect();
    final currentBoard = state.boardState;
    if (currentBoard == null) {
      return const MovementBounds(minRow: 0, maxRow: 0, minCol: 0, maxCol: 0);
    }
    final vehicle = currentBoard.getVehicleById(vehicleId);
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
    return BoardEngine.getMovementBounds(currentBoard, vehicleId);
  }

  Future<void> onVehicleDragEnd(
    String vehicleId, {
    required double draggedRow,
    required double draggedCol,
  }) async {
    final currentBoard = state.boardState;
    if (currentBoard == null || state.isWon || isClosed) return;

    final prevMoves = currentBoard.moveCount;
    final nextBoard = BoardEngine.snapVehicle(
      currentBoard,
      vehicleId,
      draggedRow: draggedRow,
      draggedCol: draggedCol,
    );

    if (nextBoard.moveCount <= prevMoves) return;

    if (nextBoard.isWon) {
      _hintRequestId++;
      final stars = BoardEngine.calculateStars(
        userMoves: nextBoard.moveCount,
        optimalMoves: nextBoard.optimalMoves,
      );

      // Commit win state synchronously before any await so concurrent multi-touch
      // drags cannot overwrite or double-win.
      emit(
        state.copyWith(
          boardState: nextBoard,
          clearHint: true,
          isComputingHint: false,
          isWon: true,
          earnedStars: stars,
        ),
      );

      await audioService.playSlide();
      if (isClosed) return;

      try {
        final updatedChallenge = await dailyRepository.saveDailyCompletion(
          dateKey: state.dateKey,
          userMoves: nextBoard.moveCount,
        );
        if (!isClosed) {
          emit(state.copyWith(challenge: updatedChallenge));
        }
      } catch (_) {}

      if (isClosed) return;
      await audioService.playWin();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!isClosed) {
          audioService.playStarPop();
        }
      });
    } else {
      _hintRequestId++;
      // Commit move synchronously before awaiting slide audio.
      emit(
        state.copyWith(
          boardState: nextBoard,
          clearHint: true,
          isComputingHint: false,
        ),
      );
      await audioService.playSlide();
    }
  }

  void undo() {
    final currentBoard = state.boardState;
    if (currentBoard == null || !state.canUndo) return;
    _hintRequestId++;
    final prevBoard = BoardEngine.undo(currentBoard);
    audioService.playUndoWhoosh();
    emit(
      state.copyWith(
        boardState: prevBoard,
        clearHint: true,
        isComputingHint: false,
        isWon: false,
      ),
    );
  }

  void reset() {
    final challenge = state.challenge;
    final currentBoard = state.boardState;
    if (challenge == null || currentBoard == null) return;

    _hintRequestId++;
    final resetBoard = BoardEngine.reset(
      currentBoard,
      initialBoardString: challenge.boardString,
    );
    audioService.playUndoWhoosh();
    emit(
      state.copyWith(
        boardState: resetBoard,
        clearHint: true,
        isComputingHint: false,
        isWon: false,
        earnedStars: 0,
        scoreSubmitted: state.scoreSubmitted,
        clearSubmitError: true,
      ),
    );
  }

  Future<bool> requestHint() async {
    final currentBoard = state.boardState;
    if (currentBoard == null ||
        state.isWon ||
        state.isComputingHint ||
        state.remainingHints <= 0) {
      return true;
    }

    final requestId = ++_hintRequestId;
    final snapshot = currentBoard;
    final snapshotDateKey = state.dateKey;
    emit(state.copyWith(isComputingHint: true));

    final hintMove = await (hintSolver != null
        ? hintSolver!(snapshot)
        : Isolate.run(
            () => BfsSolver.findNextMove(snapshot, maxVisitedStates: 100000),
          ));

    if (isClosed) return true;

    if (_hintRequestId != requestId ||
        state.isWon ||
        state.dateKey != snapshotDateKey ||
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
      if (levelRepository != null) {
        try {
          final updated = await levelRepository!.updateRemainingHints(-1);
          if (!isClosed) {
            emit(state.copyWith(remainingHints: updated));
          }
        } catch (_) {}
      }
      return true;
    } else {
      emit(state.copyWith(isComputingHint: false));
      return false;
    }
  }

  Future<bool> submitPlayerScore(String playerName) async {
    final currentBoard = state.boardState;
    if (currentBoard == null ||
        !state.isWon ||
        currentBoard.moveCount <= 0 ||
        state.scoreSubmitted ||
        state.isSubmittingScore) {
      return false;
    }
    final trimmedName = playerName.trim();
    if (trimmedName.isEmpty) return false;

    final validationError = validatePlayerName(trimmedName);
    if (validationError != null) {
      emit(
        state.copyWith(
          isSubmittingScore: false,
          submitErrorMessage: validationError,
        ),
      );
      return false;
    }

    emit(
      state.copyWith(
        isSubmittingScore: true,
        clearSubmitError: true,
      ),
    );

    try {
      await submitScoreUseCase(
        playerName: trimmedName,
        challengeDate: state.dateKey,
        movesCount: currentBoard.moveCount,
      );
      DailyChallenge? updatedChallenge = state.challenge;
      try {
        updatedChallenge =
            await dailyRepository.markScoreSubmitted(state.dateKey) ??
                updatedChallenge;
      } catch (_) {}
      if (isClosed) return false;
      emit(
        state.copyWith(
          challenge: updatedChallenge,
          isSubmittingScore: false,
          scoreSubmitted: true,
        ),
      );
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSubmittingScore: false,
          submitErrorMessage: e.toString(),
        ),
      );
      return false;
    }
  }
}

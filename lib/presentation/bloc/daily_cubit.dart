import 'dart:async';
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
  final bool isReviewMode;
  final bool hasSolvedBoardSnapshot;
  final int earnedStars;
  final int? bestMoves;
  final int bestStars;
  final bool isSubmittingScore;
  final bool scoreSubmitted;
  final int? submittedMoves;
  final String? submittedPlayerName;
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
    this.isReviewMode = false,
    this.hasSolvedBoardSnapshot = false,
    this.earnedStars = 0,
    this.bestMoves,
    this.bestStars = 0,
    this.isSubmittingScore = false,
    this.scoreSubmitted = false,
    this.submittedMoves,
    this.submittedPlayerName,
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
    bool? isReviewMode,
    bool? hasSolvedBoardSnapshot,
    int? earnedStars,
    int? bestMoves,
    bool clearBestMoves = false,
    int? bestStars,
    bool? isSubmittingScore,
    bool? scoreSubmitted,
    int? submittedMoves,
    String? submittedPlayerName,
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
      isReviewMode: isReviewMode ?? this.isReviewMode,
      hasSolvedBoardSnapshot:
          hasSolvedBoardSnapshot ?? this.hasSolvedBoardSnapshot,
      earnedStars: earnedStars ?? this.earnedStars,
      bestMoves: clearBestMoves ? null : (bestMoves ?? this.bestMoves),
      bestStars: bestStars ?? this.bestStars,
      isSubmittingScore: isSubmittingScore ?? this.isSubmittingScore,
      scoreSubmitted: scoreSubmitted ?? this.scoreSubmitted,
      submittedMoves: submittedMoves ?? this.submittedMoves,
      submittedPlayerName: submittedPlayerName ?? this.submittedPlayerName,
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
        isReviewMode,
        hasSolvedBoardSnapshot,
        earnedStars,
        bestMoves,
        bestStars,
        isSubmittingScore,
        scoreSubmitted,
        submittedMoves,
        submittedPlayerName,
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
  Future<void> _dragQueue = Future<void>.value();

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

  /// Validates player nickname for UGC compliance (non-empty, length, chars, profanity).
  static String? validatePlayerName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return 'Please enter a nickname before submitting your score.';
    }
    return PlayerIdentityService.validateUsername(trimmed);
  }

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
        isReviewMode: false,
        hasSolvedBoardSnapshot: false,
        earnedStars: 0,
        clearBestMoves: true,
        bestStars: 0,
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

      final parsedInitialBoard = LevelParser.parseToBoardState(
        challenge.boardString,
        optimalMoves: challenge.optimalMoves,
      );

      if (isClosed) return;

      if (challenge.isCompleted) {
        final recordedBestMoves =
            challenge.userMoves ?? challenge.submittedMoves;
        final bestStars = recordedBestMoves != null && recordedBestMoves > 0
            ? BoardEngine.calculateStars(
                userMoves: recordedBestMoves,
                optimalMoves: challenge.optimalMoves,
              )
            : 0;

        BoardState displayBoard = parsedInitialBoard;
        bool hasSolvedSnapshot = false;

        final solvedStr = challenge.solvedBoardString;
        if (solvedStr != null && solvedStr.isNotEmpty) {
          try {
            final parsedSolved = LevelParser.parseToBoardState(
              solvedStr,
              optimalMoves: challenge.optimalMoves,
            );
            if (parsedSolved.isWon) {
              final effectiveMoveCount = recordedBestMoves ??
                  (challenge.bestMoveHistory.isNotEmpty
                      ? challenge.bestMoveHistory.length
                      : challenge.optimalMoves);
              displayBoard = parsedSolved.copyWith(
                moveCount: effectiveMoveCount,
                moveHistory: challenge.bestMoveHistory,
              );
              hasSolvedSnapshot = true;
            }
          } catch (_) {
            hasSolvedSnapshot = false;
          }
        }

        emit(
          state.copyWith(
            status: DailyViewStatus.content,
            challenge: challenge,
            boardState: displayBoard,
            remainingHints: persistedHints ?? state.remainingHints,
            isWon: true,
            isReviewMode: true,
            hasSolvedBoardSnapshot: hasSolvedSnapshot,
            earnedStars: bestStars,
            bestMoves: recordedBestMoves,
            bestStars: bestStars,
            scoreSubmitted: challenge.scoreSubmitted,
            submittedMoves: challenge.submittedMoves,
            submittedPlayerName: challenge.submittedPlayerName,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: DailyViewStatus.content,
          challenge: challenge,
          boardState: parsedInitialBoard,
          remainingHints: persistedHints ?? state.remainingHints,
          isWon: false,
          isReviewMode: false,
          hasSolvedBoardSnapshot: false,
          earnedStars: 0,
          clearBestMoves: true,
          bestStars: 0,
          scoreSubmitted: challenge.scoreSubmitted,
          submittedMoves: challenge.submittedMoves,
          submittedPlayerName: challenge.submittedPlayerName,
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
    } on ServerException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DailyViewStatus.error,
          errorMessage: e.message,
        ),
      );
    } on LevelParseException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DailyViewStatus.error,
          errorMessage: 'Daily Challenge puzzle data is invalid: ${e.message}',
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DailyViewStatus.error,
          errorMessage:
              'Unable to load today\'s Daily Challenge. Please check your connection and tap Retry.',
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
  }) {
    final completer = Completer<void>();
    _dragQueue = _dragQueue.then((_) async {
      try {
        await _handleVehicleDragEnd(
          vehicleId,
          draggedRow: draggedRow,
          draggedCol: draggedCol,
        );
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    return completer.future;
  }

  Future<void> _handleVehicleDragEnd(
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
      final currentMoves = nextBoard.moveCount;
      final stars = BoardEngine.calculateStars(
        userMoves: currentMoves,
        optimalMoves: nextBoard.optimalMoves,
      );
      final priorBest = state.bestMoves ?? state.challenge?.userMoves;
      final effectiveBestMoves = (priorBest != null && priorBest <= currentMoves)
          ? priorBest
          : currentMoves;
      final effectiveBestStars = BoardEngine.calculateStars(
        userMoves: effectiveBestMoves,
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
          isReviewMode: false,
          hasSolvedBoardSnapshot: true,
          earnedStars: stars,
          bestMoves: effectiveBestMoves,
          bestStars: effectiveBestStars,
          clearSubmitError: true,
        ),
      );

      await audioService.playSlide();
      if (isClosed) return;

      try {
        final DailyChallenge updatedChallenge;
        final repo = dailyRepository;
        if (repo is VerifiedDailyChallengeRepository) {
          updatedChallenge = await repo.saveVerifiedCompletion(
            dateKey: state.dateKey,
            userMoves: currentMoves,
            solvedBoardString: nextBoard.toBoardString(),
            moveHistory: nextBoard.moveHistory,
          );
        } else {
          updatedChallenge = await repo.saveDailyCompletion(
            dateKey: state.dateKey,
            userMoves: currentMoves,
          );
        }
        if (!isClosed) {
          final savedBest = updatedChallenge.userMoves ?? effectiveBestMoves;
          emit(
            state.copyWith(
              challenge: updatedChallenge,
              bestMoves: savedBest,
              bestStars: BoardEngine.calculateStars(
                userMoves: savedBest,
                optimalMoves: updatedChallenge.optimalMoves,
              ),
            ),
          );
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
        isReviewMode: false,
      ),
    );
  }

  /// Resets the board to the day's starting layout for a fresh attempt or Replay,
  /// while preserving the player's saved best score & submission status.
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
        isReviewMode: false,
        hasSolvedBoardSnapshot: false,
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
    if (state.isSubmittingScore || state.scoreSubmitted) {
      return false;
    }

    final trimmedName = playerName.trim();
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

    if (!state.isWon) {
      emit(
        state.copyWith(
          isSubmittingScore: false,
          submitErrorMessage:
              'Complete today\'s Daily Challenge before submitting a score.',
        ),
      );
      return false;
    }

    final challenge = state.challenge;
    final currentBoard = state.boardState;

    // Always prefer the player's best recorded solution (even after a worse Replay).
    final List<Move> bestMoveHistory;
    final int bestMoveCount;

    final hasSavedBest =
        challenge != null && challenge.bestMoveHistory.isNotEmpty;
    final currentRunIsWon = currentBoard != null &&
        currentBoard.isWon &&
        currentBoard.moveHistory.isNotEmpty;
    final savedBestCount = challenge?.userMoves ??
        (hasSavedBest ? challenge.bestMoveHistory.length : null);

    if (hasSavedBest &&
        (!currentRunIsWon ||
            (savedBestCount != null &&
                savedBestCount <= currentBoard.moveCount))) {
      bestMoveHistory = challenge.bestMoveHistory;
      bestMoveCount = savedBestCount ?? challenge.bestMoveHistory.length;
    } else if (currentRunIsWon) {
      bestMoveHistory = currentBoard.moveHistory;
      bestMoveCount = currentBoard.moveCount;
    } else {
      emit(
        state.copyWith(
          isSubmittingScore: false,
          submitErrorMessage:
              'No verified move history found. Please solve the puzzle to submit.',
        ),
      );
      return false;
    }

    if (bestMoveCount <= 0 || bestMoveHistory.isEmpty) {
      emit(
        state.copyWith(
          isSubmittingScore: false,
          submitErrorMessage:
              'No verified move history found. Please solve the puzzle to submit.',
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
      DailyChallenge? updatedChallenge = state.challenge;
      final repo = dailyRepository;
      if (repo is VerifiedDailyChallengeRepository) {
        updatedChallenge = await repo.submitVerifiedScore(
          playerName: trimmedName,
          challengeDate: state.dateKey,
          moveHistory: bestMoveHistory,
        );
      } else {
        await submitScoreUseCase(
          playerName: trimmedName,
          challengeDate: state.dateKey,
          movesCount: bestMoveCount,
          moveHistory: bestMoveHistory,
        );
        try {
          updatedChallenge =
              await dailyRepository.markScoreSubmitted(state.dateKey) ??
                  updatedChallenge;
        } catch (_) {}
      }

      if (isClosed) return false;
      emit(
        state.copyWith(
          challenge: updatedChallenge,
          isSubmittingScore: false,
          scoreSubmitted: true,
          submittedMoves: bestMoveCount,
          submittedPlayerName: trimmedName,
          bestMoves: updatedChallenge?.userMoves ?? bestMoveCount,
          clearSubmitError: true,
        ),
      );
      return true;
    } on ServerException catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSubmittingScore: false,
          submitErrorMessage: e.message,
        ),
      );
      return false;
    } catch (_) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSubmittingScore: false,
          submitErrorMessage:
              'Unable to submit score right now. Please try again.',
        ),
      );
      return false;
    }
  }
}

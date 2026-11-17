import 'dart:async';
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
import '../../domain/usecases/submit_score.dart';

enum DailyViewStatus { loading, content, empty, error }

class DailyState extends Equatable {
  final DailyViewStatus status;
  final String dateKey;
  final DailyChallenge? challenge;
  final BoardState? boardState;
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
  final DateTime Function() _nowProvider;
  final bool _hasCustomInitialDateKey;

  Future<void> _dragQueue = Future<void>.value();
  Timer? _midnightTimer;
  StreamSubscription<bool>? _connectivitySub;
  bool _isLoadingChallenge = false;

  DailyCubit({
    required this.dailyRepository,
    required this.submitScoreUseCase,
    required this.audioService,
    String? initialDateKey,
    DateTime Function()? nowProvider,
    Stream<bool>? connectivityStream,
  })  : _nowProvider = nowProvider ?? DateTime.now,
        _hasCustomInitialDateKey = initialDateKey != null,
        super(
          DailyState(
            status: DailyViewStatus.loading,
            dateKey: initialDateKey ??
                formatTodayDateKey((nowProvider ?? DateTime.now)()),
          ),
        ) {
    if (!_hasCustomInitialDateKey) {
      _scheduleUtcMidnightRollover();
    }
    if (connectivityStream != null) {
      _connectivitySub = connectivityStream.listen((isConnected) {
        if (!isConnected || isClosed) return;
        if (state.status == DailyViewStatus.error ||
            state.status == DailyViewStatus.empty) {
          loadDailyChallenge();
        }
      });
    }
  }

  void _scheduleUtcMidnightRollover() {
    _midnightTimer?.cancel();
    final nowUtc = _nowProvider().toUtc();
    final nextMidnightUtc = DateTime.utc(
      nowUtc.year,
      nowUtc.month,
      nowUtc.day + 1,
      0,
      0,
      1,
    );
    final delay = nextMidnightUtc.difference(nowUtc);
    _midnightTimer = Timer(
      delay.isNegative ? const Duration(seconds: 1) : delay,
      () {
        if (isClosed) return;
        loadDailyChallenge();
        _scheduleUtcMidnightRollover();
      },
    );
  }

  /// Automatically reloads today's challenge (with loading state) when
  /// returning from an error/empty state or when the UTC date has rolled over.
  Future<void> refreshIfNeeded() async {
    if (isClosed || _isLoadingChallenge) return;
    final needsDateRollover = !_hasCustomInitialDateKey &&
        formatTodayDateKey(_nowProvider()) != state.dateKey;
    final needsRetry = state.status == DailyViewStatus.error ||
        state.status == DailyViewStatus.empty;
    if (needsDateRollover || needsRetry) {
      await loadDailyChallenge();
    }
  }

  @override
  Future<void> close() {
    _midnightTimer?.cancel();
    _connectivitySub?.cancel();
    return super.close();
  }

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
    if (_isLoadingChallenge || isClosed) return;
    _isLoadingChallenge = true;

    final targetDate = dateKey ??
        (_hasCustomInitialDateKey
            ? state.dateKey
            : formatTodayDateKey(_nowProvider()));

    emit(
      state.copyWith(
        status: DailyViewStatus.loading,
        dateKey: targetDate,
        clearError: true,
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
      final challenge = await dailyRepository.getDailyChallenge(targetDate);
      if (isClosed) return;

      if (challenge.boardString.trim().isEmpty) {
        emit(
          state.copyWith(
            status: DailyViewStatus.empty,
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
    } finally {
      _isLoadingChallenge = false;
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
      emit(
        state.copyWith(
          boardState: nextBoard,
        ),
      );
      await audioService.playSlide();
    }
  }

  void undo() {
    final currentBoard = state.boardState;
    if (currentBoard == null || !state.canUndo) return;
    final prevBoard = BoardEngine.undo(currentBoard);
    audioService.playUndoWhoosh();
    emit(
      state.copyWith(
        boardState: prevBoard,
        isWon: false,
        isReviewMode: false,
      ),
    );
  }

  /// Resets the board to the day's starting layout during an active attempt.
  /// Once the Daily Challenge is won, replaying is disallowed.
  void reset() {
    if (state.isWon) return;
    final challenge = state.challenge;
    final currentBoard = state.boardState;
    if (challenge == null || currentBoard == null) return;

    final resetBoard = BoardEngine.reset(
      currentBoard,
      initialBoardString: challenge.boardString,
    );
    audioService.playUndoWhoosh();
    emit(
      state.copyWith(
        boardState: resetBoard,
        isWon: false,
        isReviewMode: false,
        hasSolvedBoardSnapshot: false,
        earnedStars: 0,
        scoreSubmitted: state.scoreSubmitted,
        clearSubmitError: true,
      ),
    );
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

    final currentTodayKey = formatTodayDateKey(_nowProvider());
    if (state.dateKey != currentTodayKey) {
      emit(
        state.copyWith(
          isSubmittingScore: false,
          submitErrorMessage:
              'The ${state.dateKey} Daily Challenge has closed (UTC date rolled over to $currentTodayKey). Please refresh to load today\'s new challenge.',
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

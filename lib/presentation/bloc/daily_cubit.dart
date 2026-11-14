import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/error/exceptions.dart';
import '../../core/services/audio_service.dart';
import '../../core/utils/level_parser.dart';
import '../../domain/engine/board_engine.dart';
import '../../domain/entities/board_state.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/move.dart';
import '../../domain/repositories/daily_challenge_repository.dart';
import '../../domain/solver/bfs_solver.dart';
import '../../domain/usecases/submit_score.dart';

enum DailyViewStatus { loading, content, empty, error }

class DailyState extends Equatable {
  final DailyViewStatus status;
  final String dateKey;
  final DailyChallenge? challenge;
  final BoardState? boardState;
  final Move? activeHint;
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

  DailyCubit({
    required this.dailyRepository,
    required this.submitScoreUseCase,
    required this.audioService,
    String? initialDateKey,
  }) : super(
          DailyState(
            status: DailyViewStatus.loading,
            dateKey: initialDateKey ?? formatTodayDateKey(),
          ),
        );

  static String formatTodayDateKey([DateTime? now]) {
    final dt = now ?? DateTime.now();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> loadDailyChallenge({String? dateKey}) async {
    final targetDate = dateKey ?? state.dateKey;
    emit(
      state.copyWith(
        status: DailyViewStatus.loading,
        dateKey: targetDate,
        clearError: true,
        clearHint: true,
        isWon: false,
        earnedStars: 0,
        scoreSubmitted: false,
        clearSubmitError: true,
      ),
    );

    try {
      final challenge = await dailyRepository.getDailyChallenge(targetDate);
      if (challenge.boardString.trim().isEmpty) {
        emit(
          state.copyWith(
            status: DailyViewStatus.empty,
            errorMessage: 'No Daily Challenge is available for $targetDate.',
          ),
        );
        return;
      }

      final parsedBoard = LevelParser.parseToBoardState(
        challenge.boardString,
        optimalMoves: challenge.optimalMoves,
      );

      emit(
        state.copyWith(
          status: DailyViewStatus.content,
          challenge: challenge,
          boardState: parsedBoard,
          isWon: false,
          earnedStars: 0,
        ),
      );
    } on EmptyDataException catch (e) {
      emit(
        state.copyWith(
          status: DailyViewStatus.empty,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DailyViewStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> onVehicleDragEnd(
    String vehicleId, {
    required double draggedRow,
    required double draggedCol,
  }) async {
    final currentBoard = state.boardState;
    if (currentBoard == null || state.isWon) return;

    final prevMoves = currentBoard.moveCount;
    final nextBoard = BoardEngine.snapVehicle(
      currentBoard,
      vehicleId,
      draggedRow: draggedRow,
      draggedCol: draggedCol,
    );

    if (nextBoard.moveCount <= prevMoves) return;

    await audioService.playSlide();

    if (nextBoard.isWon) {
      final stars = BoardEngine.calculateStars(
        userMoves: nextBoard.moveCount,
        optimalMoves: nextBoard.optimalMoves,
      );
      DailyChallenge? updatedChallenge = state.challenge;
      try {
        updatedChallenge = await dailyRepository.saveDailyCompletion(
          dateKey: state.dateKey,
          userMoves: nextBoard.moveCount,
        );
      } catch (_) {}

      emit(
        state.copyWith(
          boardState: nextBoard,
          challenge: updatedChallenge,
          clearHint: true,
          isWon: true,
          earnedStars: stars,
        ),
      );
      await audioService.playWin();
      await audioService.playStarPop();
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
    final currentBoard = state.boardState;
    if (currentBoard == null || !state.canUndo) return;
    final prevBoard = BoardEngine.undo(currentBoard);
    audioService.playUndoWhoosh();
    emit(
      state.copyWith(
        boardState: prevBoard,
        clearHint: true,
        isWon: false,
      ),
    );
  }

  void reset() {
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
        clearHint: true,
        isWon: false,
        earnedStars: 0,
        scoreSubmitted: false,
        clearSubmitError: true,
      ),
    );
  }

  void requestHint() {
    final currentBoard = state.boardState;
    if (currentBoard == null || state.isWon) return;
    final hintMove = BfsSolver.findNextMove(currentBoard);
    if (hintMove != null) {
      audioService.playHintPing();
      emit(state.copyWith(activeHint: hintMove));
    }
  }

  Future<bool> submitPlayerScore(String playerName) async {
    final currentBoard = state.boardState;
    if (currentBoard == null) return false;
    final trimmedName = playerName.trim();
    if (trimmedName.isEmpty) return false;

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
      emit(
        state.copyWith(
          isSubmittingScore: false,
          scoreSubmitted: true,
        ),
      );
      return true;
    } catch (e) {
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

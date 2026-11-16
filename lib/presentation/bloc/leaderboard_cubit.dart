import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/error/exceptions.dart';
import '../../data/models/score_model.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../../domain/usecases/get_leaderboard.dart';
import 'daily_cubit.dart';

enum LeaderboardViewStatus { loading, content, empty, error }

class LeaderboardState extends Equatable {
  final LeaderboardViewStatus status;
  final String challengeDate;
  final List<LeaderboardEntry> entries;
  final PlayerLeaderboardRank? myRank;
  final String? currentUserId;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreErrorMessage;
  final String? errorMessage;

  const LeaderboardState({
    this.status = LeaderboardViewStatus.loading,
    required this.challengeDate,
    this.entries = const [],
    this.myRank,
    this.currentUserId,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreErrorMessage,
    this.errorMessage,
  });

  bool get canGoNextDay =>
      challengeDate.compareTo(DailyCubit.formatTodayDateKey()) < 0;

  bool isCurrentUserEntry(LeaderboardEntry entry, int rank) {
    if (entry is ScoreModel &&
        currentUserId != null &&
        entry.userId == currentUserId) {
      return true;
    }
    final mine = myRank;
    if (mine == null) return false;
    if (mine.entry.id != null && entry.id != null) {
      return entry.id == mine.entry.id;
    }
    return mine.rank == rank &&
        entry.playerName == mine.entry.playerName &&
        entry.movesCount == mine.entry.movesCount;
  }

  bool get isMyRankInLoadedList {
    if (myRank == null) return false;
    for (int i = 0; i < entries.length; i++) {
      if (isCurrentUserEntry(entries[i], i + 1)) {
        return true;
      }
    }
    return false;
  }

  LeaderboardState copyWith({
    LeaderboardViewStatus? status,
    String? challengeDate,
    List<LeaderboardEntry>? entries,
    PlayerLeaderboardRank? myRank,
    bool clearMyRank = false,
    String? currentUserId,
    bool clearCurrentUserId = false,
    bool? hasMore,
    bool? isLoadingMore,
    String? loadMoreErrorMessage,
    bool clearLoadMoreError = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LeaderboardState(
      status: status ?? this.status,
      challengeDate: challengeDate ?? this.challengeDate,
      entries: entries ?? this.entries,
      myRank: clearMyRank ? null : (myRank ?? this.myRank),
      currentUserId:
          clearCurrentUserId ? null : (currentUserId ?? this.currentUserId),
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreErrorMessage: clearLoadMoreError
          ? null
          : (loadMoreErrorMessage ?? this.loadMoreErrorMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        challengeDate,
        entries,
        myRank,
        currentUserId,
        hasMore,
        isLoadingMore,
        loadMoreErrorMessage,
        errorMessage,
      ];
}

class LeaderboardCubit extends Cubit<LeaderboardState> {
  final GetLeaderboard getLeaderboardUseCase;
  final int pageSize;
  int _requestId = 0;

  LeaderboardCubit({
    required this.getLeaderboardUseCase,
    String? initialDate,
    this.pageSize = LeaderboardRepository.defaultPageSize,
  }) : super(
          LeaderboardState(
            status: LeaderboardViewStatus.loading,
            challengeDate: initialDate ?? DailyCubit.formatTodayDateKey(),
          ),
        );

  Future<void> loadLeaderboard({String? challengeDate}) async {
    final targetDate = challengeDate ?? state.challengeDate;
    final requestId = ++_requestId;

    emit(
      state.copyWith(
        status: LeaderboardViewStatus.loading,
        challengeDate: targetDate,
        entries: const [],
        clearMyRank: true,
        clearCurrentUserId: true,
        hasMore: false,
        isLoadingMore: false,
        clearLoadMoreError: true,
        clearError: true,
      ),
    );

    try {
      final page = await getLeaderboardUseCase.repository.getLeaderboardPage(
        targetDate,
        limit: pageSize,
        offset: 0,
        includeMyRank: true,
      );
      if (isClosed || requestId != _requestId) return;

      if (page.entries.isEmpty) {
        emit(
          state.copyWith(
            status: LeaderboardViewStatus.empty,
            entries: const [],
            myRank: page.myRank,
            currentUserId: page.currentUserId,
            hasMore: false,
            isLoadingMore: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: LeaderboardViewStatus.content,
            entries: page.entries,
            myRank: page.myRank,
            currentUserId: page.currentUserId,
            hasMore: page.hasMore,
            isLoadingMore: false,
          ),
        );
      }
    } catch (e) {
      if (isClosed || requestId != _requestId) return;
      emit(
        state.copyWith(
          status: LeaderboardViewStatus.error,
          isLoadingMore: false,
          errorMessage: _friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.status != LeaderboardViewStatus.content ||
        !state.hasMore ||
        state.isLoadingMore) {
      return;
    }

    final requestId = _requestId;
    final targetDate = state.challengeDate;
    final offset = state.entries.length;

    emit(
      state.copyWith(
        isLoadingMore: true,
        clearLoadMoreError: true,
      ),
    );

    try {
      final page = await getLeaderboardUseCase.repository.getLeaderboardPage(
        targetDate,
        limit: pageSize,
        offset: offset,
        includeMyRank: false,
      );
      if (isClosed ||
          requestId != _requestId ||
          state.challengeDate != targetDate) {
        return;
      }

      emit(
        state.copyWith(
          entries: [...state.entries, ...page.entries],
          hasMore: page.hasMore,
          isLoadingMore: false,
          clearLoadMoreError: true,
        ),
      );
    } catch (e) {
      if (isClosed ||
          requestId != _requestId ||
          state.challengeDate != targetDate) {
        return;
      }
      emit(
        state.copyWith(
          isLoadingMore: false,
          loadMoreErrorMessage: _friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> previousDay() async {
    await loadLeaderboard(challengeDate: _shiftUtcDate(state.challengeDate, -1));
  }

  Future<void> nextDay() async {
    if (!state.canGoNextDay) return;
    final nextDate = _shiftUtcDate(state.challengeDate, 1);
    final todayUtc = DailyCubit.formatTodayDateKey();
    final clamped = nextDate.compareTo(todayUtc) > 0 ? todayUtc : nextDate;
    await loadLeaderboard(challengeDate: clamped);
  }

  static String _shiftUtcDate(String dateKey, int days) {
    final parsed = DateTime.tryParse('${dateKey}T00:00:00Z');
    final base = parsed?.toUtc() ?? DateTime.now().toUtc();
    final shifted = DateTime.utc(base.year, base.month, base.day + days);
    return DailyCubit.formatTodayDateKey(shifted);
  }

  static String _friendlyErrorMessage(Object error) {
    if (error is ServerException && error.message.trim().isNotEmpty) {
      return error.message.trim();
    }
    if (error is CacheException && error.message.trim().isNotEmpty) {
      return error.message.trim();
    }
    return 'Unable to load the leaderboard right now. Please try again.';
  }
}

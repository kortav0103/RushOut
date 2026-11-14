import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/usecases/submit_score.dart';
import 'daily_cubit.dart';

enum LeaderboardViewStatus { loading, content, empty, error }

class LeaderboardState extends Equatable {
  final LeaderboardViewStatus status;
  final String challengeDate;
  final List<LeaderboardEntry> entries;
  final String? errorMessage;

  const LeaderboardState({
    this.status = LeaderboardViewStatus.loading,
    required this.challengeDate,
    this.entries = const [],
    this.errorMessage,
  });

  LeaderboardState copyWith({
    LeaderboardViewStatus? status,
    String? challengeDate,
    List<LeaderboardEntry>? entries,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LeaderboardState(
      status: status ?? this.status,
      challengeDate: challengeDate ?? this.challengeDate,
      entries: entries ?? this.entries,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        challengeDate,
        entries,
        errorMessage,
      ];
}

class LeaderboardCubit extends Cubit<LeaderboardState> {
  final GetLeaderboard getLeaderboardUseCase;

  LeaderboardCubit({
    required this.getLeaderboardUseCase,
    String? initialDate,
  }) : super(
          LeaderboardState(
            status: LeaderboardViewStatus.loading,
            challengeDate: initialDate ?? DailyCubit.formatTodayDateKey(),
          ),
        );

  Future<void> loadLeaderboard({String? challengeDate}) async {
    final targetDate = challengeDate ?? state.challengeDate;
    emit(
      state.copyWith(
        status: LeaderboardViewStatus.loading,
        challengeDate: targetDate,
        clearError: true,
      ),
    );

    try {
      final scores = await getLeaderboardUseCase(targetDate);
      if (scores.isEmpty) {
        emit(
          state.copyWith(
            status: LeaderboardViewStatus.empty,
            entries: const [],
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: LeaderboardViewStatus.content,
            entries: scores,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: LeaderboardViewStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}

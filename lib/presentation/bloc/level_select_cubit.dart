import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/tutorial_service.dart';
import '../../domain/entities/level.dart';
import '../../domain/usecases/get_levels.dart';

class LevelSelectState extends Equatable {
  final bool isLoading;
  final List<Level> levels;
  final bool hasCompletedTutorial;
  final String? errorMessage;

  const LevelSelectState({
    this.isLoading = false,
    this.levels = const [],
    this.hasCompletedTutorial = true,
    this.errorMessage,
  });

  int get totalEarnedStars =>
      levels.fold<int>(0, (sum, level) => sum + level.stars);

  int get maxPossibleStars => levels.length * 3;

  bool shouldRunTutorialForLevel(int displayNumber) =>
      displayNumber == 1 && !hasCompletedTutorial;

  /// Index of the player's current frontier level:
  /// first unlocked unskipped level with 0 stars, or the highest unlocked level.
  int get frontierIndex {
    if (levels.isEmpty) return 0;
    int lastUnlocked = 0;
    for (int i = 0; i < levels.length; i++) {
      final level = levels[i];
      if (level.isUnlocked) {
        lastUnlocked = i;
        if (level.stars == 0 && !level.isSkipped) {
          return i;
        }
      }
    }
    return lastUnlocked;
  }

  Level? get frontierLevel =>
      levels.isEmpty ? null : levels[frontierIndex];

  LevelSelectState copyWith({
    bool? isLoading,
    List<Level>? levels,
    bool? hasCompletedTutorial,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LevelSelectState(
      isLoading: isLoading ?? this.isLoading,
      levels: levels ?? this.levels,
      hasCompletedTutorial: hasCompletedTutorial ?? this.hasCompletedTutorial,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        levels,
        hasCompletedTutorial,
        errorMessage,
      ];
}

class LevelSelectCubit extends Cubit<LevelSelectState> {
  final GetLevels getLevelsUseCase;
  final TutorialService? tutorialService;

  LevelSelectCubit({
    required this.getLevelsUseCase,
    this.tutorialService,
  }) : super(const LevelSelectState(isLoading: true));

  Future<void> loadLevels() async {
    emit(
      state.copyWith(
        isLoading: state.levels.isEmpty,
        clearError: true,
      ),
    );
    try {
      final levelsFuture = getLevelsUseCase();
      final tutorialFuture = tutorialService != null
          ? tutorialService!.hasCompletedTutorial()
          : Future<bool>.value(true);
      final levels = await levelsFuture;
      final completedTutorial = await tutorialFuture;
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          levels: levels,
          hasCompletedTutorial: completedTutorial,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load campaign levels: $e',
        ),
      );
    }
  }
}

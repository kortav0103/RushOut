import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/level.dart';
import '../../domain/usecases/get_levels.dart';

class LevelSelectState extends Equatable {
  final bool isLoading;
  final List<Level> allLevels;
  final Difficulty selectedDifficulty;
  final String? errorMessage;

  const LevelSelectState({
    this.isLoading = false,
    this.allLevels = const [],
    this.selectedDifficulty = Difficulty.easy,
    this.errorMessage,
  });

  List<Level> get filteredLevels =>
      allLevels.where((l) => l.difficulty == selectedDifficulty).toList();

  int get totalEarnedStars =>
      allLevels.fold<int>(0, (sum, level) => sum + level.stars);

  int get maxPossibleStars => allLevels.length * 3;

  Level? getNextLevel(int currentLevelId) {
    for (final l in allLevels) {
      if (l.id == currentLevelId + 1) return l;
    }
    return null;
  }

  LevelSelectState copyWith({
    bool? isLoading,
    List<Level>? allLevels,
    Difficulty? selectedDifficulty,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LevelSelectState(
      isLoading: isLoading ?? this.isLoading,
      allLevels: allLevels ?? this.allLevels,
      selectedDifficulty: selectedDifficulty ?? this.selectedDifficulty,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        allLevels,
        selectedDifficulty,
        errorMessage,
      ];
}

class LevelSelectCubit extends Cubit<LevelSelectState> {
  final GetLevels getLevelsUseCase;

  LevelSelectCubit({required this.getLevelsUseCase})
      : super(const LevelSelectState(isLoading: true));

  Future<void> loadLevels({Difficulty? selectDifficulty}) async {
    emit(
      state.copyWith(
        isLoading: true,
        selectedDifficulty: selectDifficulty ?? state.selectedDifficulty,
        clearError: true,
      ),
    );
    try {
      final levels = await getLevelsUseCase();
      emit(
        state.copyWith(
          isLoading: false,
          allLevels: levels,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load campaign levels: $e',
        ),
      );
    }
  }

  void selectDifficulty(Difficulty difficulty) {
    emit(state.copyWith(selectedDifficulty: difficulty));
  }
}

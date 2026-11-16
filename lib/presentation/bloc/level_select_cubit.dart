import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/level.dart';
import '../../domain/usecases/get_levels.dart';

class LevelSelectState extends Equatable {
  final bool isLoading;
  final List<Level> levels;
  final String? errorMessage;

  const LevelSelectState({
    this.isLoading = false,
    this.levels = const [],
    this.errorMessage,
  });

  int get totalEarnedStars =>
      levels.fold<int>(0, (sum, level) => sum + level.stars);

  int get maxPossibleStars => levels.length * 3;

  /// Index of the player's current frontier level:
  /// first unlocked unskipped level with 0 stars, or the highest unlocked level.
  int get frontierIndex {
    if (levels.isEmpty) return 0;
    int lastUnlocked = 0;
    for (int i = 0; i < levels.length; i++) {
      final level = levels[i];
      if (level.isUnlocked) {
        lastUnlocked = i;
        final nextUnlocked = i + 1 < levels.length && levels[i + 1].isUnlocked;
        if (level.stars == 0 && !nextUnlocked) {
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
    String? errorMessage,
    bool clearError = false,
  }) {
    return LevelSelectState(
      isLoading: isLoading ?? this.isLoading,
      levels: levels ?? this.levels,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        levels,
        errorMessage,
      ];
}

class LevelSelectCubit extends Cubit<LevelSelectState> {
  final GetLevels getLevelsUseCase;

  LevelSelectCubit({required this.getLevelsUseCase})
      : super(const LevelSelectState(isLoading: true));

  Future<void> loadLevels() async {
    emit(
      state.copyWith(
        isLoading: state.levels.isEmpty,
        clearError: true,
      ),
    );
    try {
      final levels = await getLevelsUseCase();
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          levels: levels,
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

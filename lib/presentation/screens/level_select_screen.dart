import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/audio_service.dart';
import '../../domain/entities/level.dart';
import '../../domain/usecases/get_levels.dart';
import '../../domain/usecases/save_progress.dart';
import '../bloc/level_select_cubit.dart';
import '../widgets/state_views.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  final GetLevels getLevelsUseCase;
  final SaveProgress saveProgressUseCase;
  final AudioService audioService;

  const LevelSelectScreen({
    super.key,
    required this.getLevelsUseCase,
    required this.saveProgressUseCase,
    required this.audioService,
  });

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen>
    with SingleTickerProviderStateMixin {
  late final LevelSelectCubit _cubit;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _cubit = LevelSelectCubit(getLevelsUseCase: widget.getLevelsUseCase)
      ..loadLevels();
    _tabController = TabController(
      length: Difficulty.values.length,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _cubit.selectDifficulty(Difficulty.values[_tabController.index]);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cubit.close();
    super.dispose();
  }

  Future<void> _openLevel(Level level, List<Level> allLevels) async {
    if (!level.isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the previous level to unlock this one!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          initialLevel: level,
          allLevels: allLevels,
          audioService: widget.audioService,
          saveProgressUseCase: widget.saveProgressUseCase,
        ),
      ),
    );

    if (mounted) {
      await _cubit.loadLevels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LevelSelectCubit>.value(
      value: _cubit,
      child: BlocBuilder<LevelSelectCubit, LevelSelectState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: const Color(0xFF141619),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1B1E23),
              title: const Text(
                'Select Level',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.amberAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amberAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${state.totalEarnedStars} / ${state.maxPossibleStars}',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFE53935),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'EASY (5–10)'),
                  Tab(text: 'MEDIUM (11–18)'),
                  Tab(text: 'HARD (19–25)'),
                ],
              ),
            ),
            body: state.isLoading
                ? const ShimmerLoadingView(isBoardLayout: false, itemCount: 6)
                : state.errorMessage != null
                    ? ErrorStateView(
                        title: 'Failed to Load Levels',
                        message: state.errorMessage!,
                        onRetry: () => _cubit.loadLevels(),
                      )
                    : state.allLevels.isEmpty
                        ? EmptyStateView(
                            title: 'No Campaign Levels Found',
                            message:
                                'Could not find any valid levels in assets/levels/rush1000.txt.',
                            actionLabel: 'Reload',
                            onAction: () => _cubit.loadLevels(),
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: Difficulty.values.map((difficulty) {
                              final levels = state.allLevels
                                  .where((l) => l.difficulty == difficulty)
                                  .toList();
                              return GridView.builder(
                                padding: const EdgeInsets.all(20),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 170,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.92,
                                ),
                                itemCount: levels.length,
                                itemBuilder: (context, index) {
                                  final level = levels[index];
                                  return _LevelCard(
                                    level: level,
                                    onTap: () =>
                                        _openLevel(level, state.allLevels),
                                  );
                                },
                              );
                            }).toList(),
                          ),
          );
        },
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final Level level;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = level.isUnlocked;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unlocked ? const Color(0xFF21252B) : const Color(0xFF181A1E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: level.stars == 3
                ? Colors.amberAccent.withValues(alpha: 0.6)
                : unlocked
                    ? Colors.white12
                    : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${level.id}',
                  style: TextStyle(
                    color: unlocked ? Colors.white : Colors.white38,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Icon(
                  unlocked
                      ? (level.stars > 0
                          ? Icons.check_circle_rounded
                          : Icons.play_circle_fill_rounded)
                      : Icons.lock_rounded,
                  color: unlocked
                      ? (level.stars > 0
                          ? Colors.greenAccent
                          : const Color(0xFFE53935))
                      : Colors.white24,
                  size: 22,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final earned = i < level.stars;
                return Icon(
                  earned ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: earned ? Colors.amberAccent : Colors.white24,
                  size: 24,
                );
              }),
            ),
            Text(
              level.bestMoves != null
                  ? 'Best: ${level.bestMoves} (Opt: ${level.optimalMoves})'
                  : 'Optimal: ${level.optimalMoves} moves',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: unlocked ? Colors.white60 : Colors.white24,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

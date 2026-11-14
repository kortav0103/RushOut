import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/audio_service.dart';
import '../../domain/entities/level.dart';
import '../../domain/usecases/save_progress.dart';
import '../bloc/game_cubit.dart';
import '../widgets/game_controls.dart';
import '../widgets/how_to_play_dialog.dart';
import '../widgets/parking_board_widget.dart';
import '../widgets/win_dialog.dart';

class GameScreen extends StatefulWidget {
  final Level initialLevel;
  final List<Level> allLevels;
  final AudioService audioService;
  final SaveProgress? saveProgressUseCase;

  const GameScreen({
    super.key,
    required this.initialLevel,
    required this.allLevels,
    required this.audioService,
    this.saveProgressUseCase,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameCubit _gameCubit;
  bool _winDialogShown = false;

  @override
  void initState() {
    super.initState();
    _gameCubit = GameCubit(
      level: widget.initialLevel,
      audioService: widget.audioService,
      saveProgressUseCase: widget.saveProgressUseCase,
    );
  }

  @override
  void dispose() {
    _gameCubit.close();
    super.dispose();
  }

  Level? _findNextLevel(int currentId) {
    for (final level in widget.allLevels) {
      if (level.id == currentId + 1) return level;
    }
    return null;
  }

  void _showWinModal(GameState state) {
    if (_winDialogShown || !mounted) return;
    _winDialogShown = true;

    final nextLevel = _findNextLevel(state.level.id);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return WinDialog(
          levelId: state.level.id,
          difficultyLabel: state.level.difficulty.label,
          userMoves: state.boardState.moveCount,
          optimalMoves: state.boardState.optimalMoves,
          earnedStars: state.earnedStars,
          hasNextLevel: nextLevel != null,
          onBackToLevels: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pop(true);
          },
          onReplay: () {
            Navigator.of(dialogContext).pop();
            setState(() {
              _winDialogShown = false;
            });
            _gameCubit.reset();
          },
          onNextLevel: () {
            Navigator.of(dialogContext).pop();
            if (nextLevel != null) {
              setState(() {
                _winDialogShown = false;
              });
              _gameCubit.loadLevel(nextLevel);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GameCubit>.value(
      value: _gameCubit,
      child: BlocBuilder<GameCubit, GameState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: const Color(0xFF141619),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).pop(true),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level ${state.level.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    state.level.difficulty.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: _difficultyColor(state.level.difficulty),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'How to Play',
                  icon: const Icon(Icons.help_outline_rounded),
                  onPressed: () => HowToPlayDialog.show(context),
                ),
                IconButton(
                  tooltip: state.isMuted ? 'Unmute Sound' : 'Mute Sound',
                  icon: Icon(
                    state.isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                  ),
                  onPressed: () => _gameCubit.toggleMute(),
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    // Moves / Optimal Moves Status Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2024),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.swipe_rounded,
                                color: Colors.cyanAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Moves: ${state.boardState.moveCount} / Optimal: ${state.boardState.optimalMoves}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          if (state.level.bestMoves != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Best: ${state.level.bestMoves}',
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (state.activeHint != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amberAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          'Hint: Slide vehicle "${state.activeHint!.vehicleId}" '
                          'to (${state.activeHint!.toRow + 1}, ${state.activeHint!.toCol + 1})',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    // Center 6x6 Parking Board
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: ParkingBoardWidget(
                            boardState: state.boardState,
                            activeHint: state.activeHint,
                            isWon: state.isWon,
                            audioService: widget.audioService,
                            onMoveCommitted: _gameCubit.onVehicleDragEnd,
                            onEscapeAnimationComplete: () =>
                                _showWinModal(state),
                          ),
                        ),
                      ),
                    ),

                    // Bottom Controls: Undo, Reset, Hint
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: GameControls(
                        canUndo: state.canUndo,
                        canReset: state.canReset,
                        hasActiveHint: state.activeHint != null,
                        onUndo: _gameCubit.undo,
                        onReset: () {
                          setState(() {
                            _winDialogShown = false;
                          });
                          _gameCubit.reset();
                        },
                        onHint: _gameCubit.requestHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _difficultyColor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return Colors.greenAccent;
      case Difficulty.medium:
        return Colors.amberAccent;
      case Difficulty.hard:
        return Colors.redAccent;
    }
  }
}

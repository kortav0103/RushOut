import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/tutorial_service.dart';
import '../../domain/entities/level.dart';
import '../../domain/usecases/save_progress.dart';
import '../bloc/game_cubit.dart';
import '../theme/daylight_theme.dart';
import '../widgets/game_controls.dart';
import '../widgets/how_to_play_dialog.dart';
import '../widgets/parking_board_widget.dart';
import '../widgets/tactile_widgets.dart';
import '../widgets/win_dialog.dart';

class GameScreen extends StatefulWidget {
  static const String backToLevelsResult = 'back_to_levels';

  final Level initialLevel;
  final List<Level> allLevels;
  final AudioService audioService;
  final SaveProgress? saveProgressUseCase;
  final TutorialService? tutorialService;
  final bool initialTutorialMode;

  const GameScreen({
    super.key,
    required this.initialLevel,
    required this.allLevels,
    required this.audioService,
    this.saveProgressUseCase,
    this.tutorialService,
    this.initialTutorialMode = false,
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
      initialLevels: widget.allLevels,
      audioService: widget.audioService,
      saveProgressUseCase: widget.saveProgressUseCase,
      tutorialService: widget.tutorialService,
      isTutorialMode: widget.initialTutorialMode,
    );

    if (widget.initialTutorialMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTutorialWelcomeDialog();
        }
      });
    }
  }

  Future<void> _showTutorialWelcomeDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: DaylightColors.surfaceWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: DaylightColors.surfaceLip, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: DaylightColors.brandRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: DaylightColors.brandRed,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Welcome to RushOut!',
                        style: DaylightTypography.rounded(
                          color: DaylightColors.inkPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _welcomePoint(
                  icon: Icons.directions_car_filled_rounded,
                  color: const Color(0xFFE91E63),
                  text:
                      'Goal: Slide the pink car (↔) out through the hazard exit gate on the right.',
                ),
                const SizedBox(height: 12),
                _welcomePoint(
                  icon: Icons.open_with_rounded,
                  color: DaylightColors.completedMintLip,
                  text:
                      'Cars marked ↔ slide left/right only. Cars marked ↕ slide up/down only.',
                ),
                const SizedBox(height: 12),
                _welcomePoint(
                  icon: Icons.touch_app_rounded,
                  color: DaylightColors.frontierAmberLip,
                  text:
                      'Follow the glowing arrow and drag each highlighted vehicle into the target slot!',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TactileKeycap(
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          _gameCubit.skipTutorial();
                        },
                        surfaceColor: DaylightColors.canvasBg,
                        lipColor: DaylightColors.surfaceLip,
                        borderColor: DaylightColors.surfaceLip,
                        borderRadius: 12,
                        lipHeight: 3,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Center(
                          child: Text(
                            'Skip',
                            style: DaylightTypography.rounded(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: DaylightColors.inkSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TactileKeycap(
                        onTap: () => Navigator.of(dialogContext).pop(),
                        surfaceColor: DaylightColors.brandRed,
                        lipColor: DaylightColors.brandRedLip,
                        borderRadius: 12,
                        lipHeight: 3,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Center(
                          child: Text(
                            "Let's Drive!",
                            style: DaylightTypography.rounded(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _welcomePoint({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: DaylightTypography.rounded(
              color: DaylightColors.inkPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ).copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }

  void _onLockedVehicleTapped() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: DaylightColors.inkPrimary,
        duration: const Duration(milliseconds: 1400),
        content: Text(
          'Move the glowing vehicle into the highlighted slot first!',
          style: DaylightTypography.rounded(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _replayLevel1Tutorial() {
    setState(() {
      _winDialogShown = false;
    });
    _gameCubit.replayTutorial();
  }

  void _handleEscapeComplete(GameState state) {
    if (!mounted || !state.isWon) return;
    _showWinModal(state, isTutorialComplete: state.isTutorialMode);
  }

  void _showSnackBar(
    String message, {
    Color backgroundColor = DaylightColors.inkPrimary,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: backgroundColor,
          duration: duration,
          content: Text(
            message,
            style: DaylightTypography.rounded(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
  }

  Future<void> _confirmAndSkipLevel(GameState state) async {
    if (!state.canShowSkipButton) return;
    if (!state.canSkipLevel) {
      _showSnackBar(
        state.skipLockedReason ?? 'Make more moves before skipping!',
      );
      return;
    }

    final nextLevel = state.nextLevel;
    if (nextLevel == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: DaylightColors.surfaceWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: DaylightColors.surfaceLip, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DaylightColors.frontierFill,
                    shape: BoxShape.circle,
                    border: Border.all(color: DaylightColors.frontierAmber),
                  ),
                  child: const Icon(
                    Icons.skip_next_rounded,
                    color: DaylightColors.frontierAmberLip,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Skip Level #${state.level.id}?',
                  textAlign: TextAlign.center,
                  style: DaylightTypography.rounded(
                    color: DaylightColors.inkPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This level will stay at 0★ and Level #${nextLevel.id} will unlock. You can come back anytime!',
                  textAlign: TextAlign.center,
                  style: DaylightTypography.rounded(
                    color: DaylightColors.inkSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ).copyWith(height: 1.35),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TactileKeycap(
                        onTap: () => Navigator.of(dialogContext).pop(false),
                        surfaceColor: DaylightColors.canvasBg,
                        lipColor: DaylightColors.surfaceLip,
                        borderColor: DaylightColors.surfaceLip,
                        borderRadius: 12,
                        lipHeight: 3,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Center(
                          child: Text(
                            'Keep Trying',
                            style: DaylightTypography.rounded(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: DaylightColors.inkPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TactileKeycap(
                        onTap: () => Navigator.of(dialogContext).pop(true),
                        surfaceColor: DaylightColors.frontierAmber,
                        lipColor: DaylightColors.frontierAmberLip,
                        borderRadius: 12,
                        lipHeight: 3,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Center(
                          child: Text(
                            'Skip Level',
                            style: DaylightTypography.rounded(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;
    final skipped = await _gameCubit.skipCurrentLevel();
    if (!mounted) return;
    if (skipped) {
      setState(() {
        _winDialogShown = false;
      });
    } else {
      _showSnackBar(
        _gameCubit.state.skipLockedReason ?? 'Unable to skip this level.',
      );
    }
  }

  @override
  void dispose() {
    _gameCubit.close();
    super.dispose();
  }

  void _showWinModal(GameState state, {bool isTutorialComplete = false}) {
    if (_winDialogShown || !mounted) return;
    _winDialogShown = true;

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
          hasNextLevel: state.hasNextLevel,
          isTutorialComplete: isTutorialComplete,
          onBackToLevels: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pop(GameScreen.backToLevelsResult);
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
            if (state.hasNextLevel) {
              setState(() {
                _winDialogShown = false;
              });
              _gameCubit.loadNextLevel();
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
      child: BlocListener<GameCubit, GameState>(
        listenWhen: (previous, current) =>
            current.saveErrorMessage != null &&
            current.saveErrorMessage != previous.saveErrorMessage,
        listener: (context, state) {
          final message = state.saveErrorMessage;
          if (message != null) {
            _showSnackBar(
              message,
              backgroundColor: DaylightColors.frontierAmberLip,
              duration: const Duration(seconds: 3),
            );
          }
        },
        child: BlocBuilder<GameCubit, GameState>(
          builder: (context, state) {
          return Scaffold(
            backgroundColor: DaylightColors.canvasBg,
            appBar: AppBar(
              backgroundColor: DaylightColors.canvasBg,
              elevation: 0,
              scrolledUnderElevation: 0,
              leadingWidth: 64,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
                child: TactileKeycap(
                  onTap: () => Navigator.of(context).pop(true),
                  borderRadius: 22,
                  lipHeight: 2.5,
                  borderColor: DaylightColors.surfaceLip,
                  padding: EdgeInsets.zero,
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: DaylightColors.inkPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              title: Text(
                'Level #${state.level.id}',
                style: DaylightTypography.rounded(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: DaylightColors.inkPrimary,
                  tabular: true,
                ),
              ),
              actions: [
                if (state.canShowSkipButton)
                  IconButton(
                    tooltip: state.canSkipLevel
                        ? 'Skip Level'
                        : (state.skipLockedReason ?? 'Skip Level Locked'),
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: state.canSkipLevel
                          ? DaylightColors.inkPrimary
                          : DaylightColors.lockedInk,
                    ),
                    onPressed: () => _confirmAndSkipLevel(state),
                  ),
                IconButton(
                  tooltip: 'How to Play',
                  icon: const Icon(
                    Icons.help_outline_rounded,
                    color: DaylightColors.inkPrimary,
                  ),
                  onPressed: () => HowToPlayDialog.show(
                    context,
                    onReplayTutorial:
                        state.isTutorialMode ? null : _replayLevel1Tutorial,
                  ),
                ),
                IconButton(
                  tooltip: state.isMuted ? 'Unmute Sound' : 'Mute Sound',
                  icon: Icon(
                    state.isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: state.isMuted
                        ? DaylightColors.brandRed
                        : DaylightColors.inkPrimary,
                  ),
                  onPressed: () => _gameCubit.toggleMute(),
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: DaylightDotGridPainter(),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Column(
                      children: [
                        if (state.isTutorialMode &&
                            state.isLoadingTutorial) ...[
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: DaylightColors.surfaceWhite,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: DaylightColors.brandRed,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: DaylightColors.brandRed,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Preparing tutorial guide...',
                                    style: DaylightTypography.rounded(
                                      color: DaylightColors.inkPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else if (state.isTutorialMode &&
                            state.tutorialInstruction != null) ...[
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: DaylightColors.surfaceWhite,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: DaylightColors.brandRed,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: DaylightColors.brandRed,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Step ${state.tutorialStepIndex + 1}/${state.tutorialSteps.length}',
                                          style: DaylightTypography.rounded(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            tabular: true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          state.tutorialInstruction!,
                                          style: DaylightTypography.rounded(
                                            color: DaylightColors.inkPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _gameCubit.skipTutorial,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Skip',
                                          style: DaylightTypography.rounded(
                                            color: DaylightColors.inkSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (state.tutorialDetailInstruction !=
                                      null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      state.tutorialDetailInstruction!,
                                      style: DaylightTypography.rounded(
                                        color: DaylightColors.inkSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ] else if (state.activeHint != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: DaylightColors.frontierFill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: DaylightColors.frontierAmber,
                                width: 1.4,
                              ),
                            ),
                            child: Text(
                              'Hint: Slide vehicle "${state.activeHint!.vehicleId}" '
                              'to (${state.activeHint!.toRow + 1}, ${state.activeHint!.toCol + 1})',
                              style: DaylightTypography.rounded(
                                color: DaylightColors.frontierAmberLip,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],

                        // Center 6x6 Parking Board
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: Builder(
                                builder: (context) {
                                  final tutorialMove =
                                      state.currentTutorialMove;
                                  final activeTutorialVehicle =
                                      tutorialMove != null
                                          ? state.boardState.getVehicleById(
                                              tutorialMove.vehicleId,
                                            )
                                          : null;

                                  return ParkingBoardWidget(
                                    boardState: state.boardState,
                                    activeHint: state.activeHint,
                                    isWon: state.isWon,
                                    unlockedVehicleIds:
                                        state.unlockedVehicleIds,
                                    customDragBounds:
                                        state.isTutorialMode
                                            ? _gameCubit
                                                .dragBoundsForTutorialVehicle
                                            : null,
                                    tutorialTargetSlot: (state.isTutorialMode &&
                                            tutorialMove != null &&
                                            activeTutorialVehicle != null)
                                        ? (
                                            row: tutorialMove.toRow,
                                            col: tutorialMove.toCol,
                                            length:
                                                activeTutorialVehicle.length,
                                            isHorizontal:
                                                activeTutorialVehicle
                                                    .isHorizontal,
                                          )
                                        : null,
                                    audioService: widget.audioService,
                                    onLockedVehicleTapped: state.isTutorialMode
                                        ? _onLockedVehicleTapped
                                        : null,
                                    onDragStart: (vehicleId) {
                                      final bounds = _gameCubit
                                          .onVehicleDragStart(vehicleId);
                                      return (
                                        minRow: bounds.minRow,
                                        maxRow: bounds.maxRow,
                                        minCol: bounds.minCol,
                                        maxCol: bounds.maxCol,
                                      );
                                    },
                                    onMoveCommitted: _gameCubit.onVehicleDragEnd,
                                    onEscapeAnimationComplete: () =>
                                        _handleEscapeComplete(_gameCubit.state),
                                  );
                                },
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
                            hintEnabled: !state.isTutorialMode,
                            hasActiveHint: state.activeHint != null,
                            isComputingHint: state.isComputingHint,
                            remainingHints: state.remainingHints,
                            onUndo: _gameCubit.undo,
                            onReset: () {
                              setState(() {
                                _winDialogShown = false;
                              });
                              _gameCubit.reset();
                            },
                            onHint: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final found = await _gameCubit.requestHint();
                              if (!found && mounted) {
                                messenger
                                  ..clearSnackBars()
                                  ..showSnackBar(
                                    SnackBar(
                                      backgroundColor:
                                          DaylightColors.inkPrimary,
                                      duration: const Duration(seconds: 2),
                                      content: Text(
                                        'No hint found from this position. Try Undo or Reset!',
                                        style: DaylightTypography.rounded(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }
}

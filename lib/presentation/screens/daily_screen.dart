import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/audio_service.dart';
import '../../domain/repositories/daily_challenge_repository.dart';
import '../../domain/repositories/level_repository.dart';
import '../../domain/usecases/get_leaderboard.dart';
import '../../domain/usecases/submit_score.dart';
import '../bloc/daily_cubit.dart';
import '../theme/daylight_theme.dart';
import '../widgets/daily_win_dialog.dart';
import '../widgets/game_controls.dart';
import '../widgets/how_to_play_dialog.dart';
import '../widgets/parking_board_widget.dart';
import '../widgets/state_views.dart';
import '../widgets/tactile_widgets.dart';
import 'leaderboard_screen.dart';

class DailyScreen extends StatefulWidget {
  final DailyChallengeRepository dailyRepository;
  final SubmitScore submitScoreUseCase;
  final GetLeaderboard? getLeaderboardUseCase;
  final AudioService audioService;
  final LevelRepository? levelRepository;
  final String? defaultPlayerName;
  final String? initialDateKey;

  const DailyScreen({
    super.key,
    required this.dailyRepository,
    required this.submitScoreUseCase,
    this.getLeaderboardUseCase,
    required this.audioService,
    this.levelRepository,
    this.defaultPlayerName,
    this.initialDateKey,
  });

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  late final DailyCubit _dailyCubit;
  bool _winDialogShown = false;

  @override
  void initState() {
    super.initState();
    _dailyCubit = DailyCubit(
      dailyRepository: widget.dailyRepository,
      submitScoreUseCase: widget.submitScoreUseCase,
      audioService: widget.audioService,
      levelRepository: widget.levelRepository,
      initialDateKey: widget.initialDateKey,
    )..loadDailyChallenge();
  }

  @override
  void dispose() {
    _dailyCubit.close();
    super.dispose();
  }

  void _openLeaderboard() {
    final getLeaderboard = widget.getLeaderboardUseCase;
    if (getLeaderboard == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeaderboardScreen(
          getLeaderboardUseCase: getLeaderboard,
          initialDateKey: _dailyCubit.state.dateKey,
        ),
      ),
    );
  }

  void _replayPuzzle() {
    setState(() {
      _winDialogShown = false;
    });
    _dailyCubit.reset();
  }

  void _openDailyWinDialog(DailyState state, {bool fromEscape = false}) {
    if (!mounted || !state.isWon) return;
    if (fromEscape) {
      if (_winDialogShown) return;
      _winDialogShown = true;
    }

    DailyWinDialog.show(
      context,
      dailyCubit: _dailyCubit,
      defaultPlayerName: widget.defaultPlayerName,
      onReplay: _replayPuzzle,
      onOpenLeaderboard:
          widget.getLeaderboardUseCase != null ? _openLeaderboard : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DailyCubit>.value(
      value: _dailyCubit,
      child: BlocBuilder<DailyCubit, DailyState>(
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
                  onTap: () => Navigator.of(context).pop(),
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
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Challenge',
                    style: DaylightTypography.rounded(
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      color: DaylightColors.inkPrimary,
                    ),
                  ),
                  Text(
                    '${state.dateKey} (UTC)',
                    style: DaylightTypography.rounded(
                      color: DaylightColors.frontierAmberLip,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      tabular: true,
                    ),
                  ),
                ],
              ),
              actions: [
                if (widget.getLeaderboardUseCase != null)
                  IconButton(
                    tooltip: 'Leaderboard',
                    icon: const Icon(
                      Icons.emoji_events_rounded,
                      color: DaylightColors.starGold,
                    ),
                    onPressed: _openLeaderboard,
                  ),
                IconButton(
                  tooltip: 'How to Play',
                  icon: const Icon(
                    Icons.help_outline_rounded,
                    color: DaylightColors.inkPrimary,
                  ),
                  onPressed: () => HowToPlayDialog.show(context),
                ),
                IconButton(
                  tooltip: 'Refresh Daily Puzzle',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: DaylightColors.inkPrimary,
                  ),
                  onPressed: () {
                    setState(() {
                      _winDialogShown = false;
                    });
                    _dailyCubit.loadDailyChallenge();
                  },
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
                  child: _buildBodyForState(state),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Explicitly handles all 4 UI states: Loading, Content, Empty, Error.
  Widget _buildBodyForState(DailyState state) {
    switch (state.status) {
      case DailyViewStatus.loading:
        return const ShimmerLoadingView(isBoardLayout: true);

      case DailyViewStatus.empty:
        return EmptyStateView(
          icon: Icons.event_busy_rounded,
          title: 'No Daily Challenge Today',
          message: state.errorMessage ??
              'No puzzle has been published for ${state.dateKey} yet. Please check back later!',
          actionLabel: 'Check Again',
          onAction: () => _dailyCubit.loadDailyChallenge(),
        );

      case DailyViewStatus.error:
        return ErrorStateView(
          title: 'Could Not Load Daily Challenge',
          message: state.errorMessage ??
              'Unable to reach server and no cached puzzle was found for today.',
          onRetry: () => _dailyCubit.loadDailyChallenge(),
        );

      case DailyViewStatus.content:
        final boardState = state.boardState;
        if (boardState == null) {
          return ErrorStateView(
            title: 'Could Not Load Daily Challenge',
            message: 'Puzzle data is unavailable. Please tap Retry.',
            onRetry: () => _dailyCubit.loadDailyChallenge(),
          );
        }

        // Completed via server sync without a local solved board snapshot:
        // render a clean Review summary card rather than a broken starting board.
        if (state.isWon && !(state.hasSolvedBoardSnapshot && boardState.isWon)) {
          return _buildSyncedCompletionCard(state);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              if (state.isWon)
                _buildCompletedBanner(state, boardState.moveCount)
              else if (state.bestMoves != null)
                _buildReplayingBanner(state),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: ParkingBoardWidget(
                      boardState: boardState,
                      activeHint: state.activeHint,
                      isWon: state.isWon,
                      audioService: widget.audioService,
                      onDragStart: (vehicleId) {
                        final bounds =
                            _dailyCubit.onVehicleDragStart(vehicleId);
                        return (
                          minRow: bounds.minRow,
                          maxRow: bounds.maxRow,
                          minCol: bounds.minCol,
                          maxCol: bounds.maxCol,
                        );
                      },
                      onMoveCommitted: _dailyCubit.onVehicleDragEnd,
                      onEscapeAnimationComplete: () => _openDailyWinDialog(
                        _dailyCubit.state,
                        fromEscape: true,
                      ),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: GameControls(
                  canUndo: state.canUndo,
                  canReset: state.canReset,
                  hasActiveHint: state.activeHint != null,
                  isComputingHint: state.isComputingHint,
                  remainingHints: state.remainingHints,
                  onUndo: _dailyCubit.undo,
                  onReset: _replayPuzzle,
                  onHint: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final found = await _dailyCubit.requestHint();
                    if (!found && mounted) {
                      messenger
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            backgroundColor: DaylightColors.inkPrimary,
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
        );
    }
  }

  Widget _buildCompletedBanner(DailyState state, int currentMoves) {
    final displayMoves = state.bestMoves ?? currentMoves;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DaylightColors.completedMint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: DaylightColors.completedMint.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: DaylightColors.completedMintLip,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.scoreSubmitted
                      ? 'Best: $displayMoves moves • Submitted'
                      : 'Completed • Best: $displayMoves moves',
                  style: DaylightTypography.rounded(
                    color: DaylightColors.inkPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    tabular: true,
                  ),
                ),
                Text(
                  'Review mode — tap Replay to play again',
                  style: DaylightTypography.rounded(
                    color: DaylightColors.inkSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _replayPuzzle,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Replay',
              style: DaylightTypography.rounded(
                color: DaylightColors.inkPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => _openDailyWinDialog(_dailyCubit.state),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              state.scoreSubmitted ? 'Summary' : 'Submit',
              style: DaylightTypography.rounded(
                color: DaylightColors.brandRed,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplayingBanner(DailyState state) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: DaylightColors.frontierFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DaylightColors.frontierAmber.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: DaylightColors.frontierAmberLip,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.scoreSubmitted
                  ? 'Replaying • Best today: ${state.bestMoves} moves • Score submitted'
                  : 'Replaying • Best today: ${state.bestMoves} moves (preserved)',
              style: DaylightTypography.rounded(
                color: DaylightColors.inkPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                tabular: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncedCompletionCard(DailyState state) {
    final bestMoves = state.bestMoves ?? state.submittedMoves ?? 0;
    final stars = state.bestStars;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DaylightColors.surfaceWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: DaylightColors.surfaceLip, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: DaylightColors.completedMintLip,
                  size: 54,
                ),
                const SizedBox(height: 12),
                Text(
                  'DAILY CHALLENGE COMPLETED',
                  textAlign: TextAlign.center,
                  style: DaylightTypography.rounded(
                    color: DaylightColors.inkPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.dateKey,
                  style: DaylightTypography.rounded(
                    color: DaylightColors.frontierAmberLip,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    tabular: true,
                  ),
                ),
                const SizedBox(height: 14),
                if (stars > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return Icon(
                        Icons.star_rounded,
                        size: i == 1 ? 44 : 36,
                        color: i < stars
                            ? DaylightColors.starGold
                            : DaylightColors.emptyStar,
                      );
                    }),
                  ),
                const SizedBox(height: 14),
                if (bestMoves > 0)
                  Text(
                    state.scoreSubmitted
                        ? 'Submitted score: $bestMoves moves'
                        : 'Best score: $bestMoves moves',
                    style: DaylightTypography.rounded(
                      color: DaylightColors.inkPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      tabular: true,
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TactileKeycap(
                        onTap: _replayPuzzle,
                        surfaceColor: DaylightColors.canvasBg,
                        lipColor: DaylightColors.surfaceLip,
                        borderColor: DaylightColors.surfaceLip,
                        borderRadius: 14,
                        lipHeight: 3,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'Replay Puzzle',
                            style: DaylightTypography.rounded(
                              color: DaylightColors.inkPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.getLeaderboardUseCase != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: TactileKeycap(
                          onTap: _openLeaderboard,
                          surfaceColor: DaylightColors.brandRed,
                          lipColor: DaylightColors.brandRedLip,
                          borderRadius: 14,
                          lipHeight: 3,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'Leaderboard',
                              style: DaylightTypography.rounded(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/audio_service.dart';
import '../../domain/repositories/daily_challenge_repository.dart';
import '../../domain/usecases/submit_score.dart';
import '../bloc/daily_cubit.dart';
import '../theme/daylight_theme.dart';
import '../widgets/game_controls.dart';
import '../widgets/how_to_play_dialog.dart';
import '../widgets/parking_board_widget.dart';
import '../widgets/state_views.dart';
import '../widgets/tactile_widgets.dart';

class DailyScreen extends StatefulWidget {
  final DailyChallengeRepository dailyRepository;
  final SubmitScore submitScoreUseCase;
  final AudioService audioService;
  final VoidCallback? onOpenLeaderboard;
  final String? defaultPlayerName;

  const DailyScreen({
    super.key,
    required this.dailyRepository,
    required this.submitScoreUseCase,
    required this.audioService,
    this.onOpenLeaderboard,
    this.defaultPlayerName,
  });

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  late final DailyCubit _dailyCubit;
  final TextEditingController _nameController = TextEditingController();
  bool _winDialogShown = false;

  @override
  void initState() {
    super.initState();
    if (widget.defaultPlayerName != null &&
        widget.defaultPlayerName!.trim().isNotEmpty) {
      _nameController.text = widget.defaultPlayerName!.trim();
    }
    _dailyCubit = DailyCubit(
      dailyRepository: widget.dailyRepository,
      submitScoreUseCase: widget.submitScoreUseCase,
      audioService: widget.audioService,
    )..loadDailyChallenge();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dailyCubit.close();
    super.dispose();
  }

  void _showDailyWinDialog(DailyState state) {
    if (_winDialogShown || !mounted || state.boardState == null) return;
    _winDialogShown = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BlocProvider<DailyCubit>.value(
          value: _dailyCubit,
          child: BlocBuilder<DailyCubit, DailyState>(
            builder: (ctx, liveState) {
              final moves = liveState.boardState?.moveCount ?? 0;
              final optimal = liveState.boardState?.optimalMoves ?? 0;
              final stars = liveState.earnedStars;

              return Dialog(
                backgroundColor: DaylightColors.surfaceWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(
                    color: DaylightColors.surfaceLip,
                    width: 2,
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: DaylightColors.frontierFill,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: DaylightColors.frontierAmber,
                          ),
                        ),
                        child: Text(
                          'DAILY CHALLENGE • ${liveState.dateKey}',
                          style: DaylightTypography.rounded(
                            color: DaylightColors.frontierAmberLip,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            tabular: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'CHALLENGE COMPLETED!',
                        textAlign: TextAlign.center,
                        style: DaylightTypography.rounded(
                          color: DaylightColors.inkPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final earned = i < stars;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.star_rounded,
                              color: earned
                                  ? DaylightColors.starGold
                                  : DaylightColors.emptyStar,
                              size: i == 1 ? 48 : 40,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: DaylightColors.canvasBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: DaylightColors.surfaceLip),
                        ),
                        child: Text(
                          'Cleared in $moves moves (Optimal: $optimal)',
                          style: DaylightTypography.rounded(
                            color: DaylightColors.inkPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            tabular: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (!liveState.scoreSubmitted) ...[
                        TextField(
                          controller: _nameController,
                          maxLength: 24,
                          style: DaylightTypography.rounded(
                            color: DaylightColors.inkPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Your Name for Leaderboard',
                            labelStyle: DaylightTypography.rounded(
                              color: DaylightColors.inkSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            hintText: 'Enter nickname...',
                            hintStyle: DaylightTypography.rounded(
                              color: DaylightColors.lockedInk,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            filled: true,
                            fillColor: DaylightColors.canvasBg,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: DaylightColors.surfaceLip,
                                width: 1.4,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: DaylightColors.frontierAmber,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                        if (liveState.submitErrorMessage != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            liveState.submitErrorMessage!,
                            style: DaylightTypography.rounded(
                              color: DaylightColors.brandRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 10),
                        TactileKeycap(
                          enabled: !liveState.isSubmittingScore,
                          onTap: liveState.isSubmittingScore
                              ? null
                              : () async {
                                  final name = _nameController.text.trim();
                                  if (name.isEmpty) return;
                                  await _dailyCubit.submitPlayerScore(name);
                                },
                          surfaceColor: DaylightColors.frontierAmber,
                          lipColor: DaylightColors.frontierAmberLip,
                          borderRadius: 14,
                          lipHeight: 3.5,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (liveState.isSubmittingScore)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.cloud_upload_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                liveState.isSubmittingScore
                                    ? 'Submitting...'
                                    : 'Submit Score',
                                style: DaylightTypography.rounded(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: DaylightColors.completedMint
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: DaylightColors.completedMint
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: DaylightColors.completedMintLip,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Score submitted to Leaderboard!',
                                style: DaylightTypography.rounded(
                                  color: DaylightColors.completedMintLip,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TactileKeycap(
                              onTap: () {
                                Navigator.of(dialogContext).pop();
                                setState(() {
                                  _winDialogShown = false;
                                });
                                _dailyCubit.reset();
                              },
                              surfaceColor: DaylightColors.canvasBg,
                              lipColor: DaylightColors.surfaceLip,
                              borderColor: DaylightColors.surfaceLip,
                              borderRadius: 12,
                              lipHeight: 3,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Center(
                                child: Text(
                                  'Replay',
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
                              onTap: () {
                                Navigator.of(dialogContext).pop();
                                if (widget.onOpenLeaderboard != null) {
                                  widget.onOpenLeaderboard!();
                                }
                              },
                              surfaceColor: DaylightColors.brandRed,
                              lipColor: DaylightColors.brandRedLip,
                              borderRadius: 12,
                              lipHeight: 3,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Center(
                                child: Text(
                                  'Leaderboard',
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
          ),
        );
      },
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
                    state.dateKey,
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

  /// Explicitly handles all 4 UI states: Loading (Shimmer), Content, Empty, Error (with Retry).
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              if (state.isWon)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                        child: Text(
                          state.scoreSubmitted
                              ? 'Completed in ${boardState.moveCount} moves • Score submitted'
                              : 'Completed in ${boardState.moveCount} moves',
                          style: DaylightTypography.rounded(
                            color: DaylightColors.inkPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showDailyWinDialog(state),
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
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: ParkingBoardWidget(
                      boardState: boardState,
                      activeHint: state.activeHint,
                      isWon: state.isWon,
                      audioService: widget.audioService,
                      onMoveCommitted: _dailyCubit.onVehicleDragEnd,
                      onEscapeAnimationComplete: () =>
                          _showDailyWinDialog(state),
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
                  onReset: () {
                    setState(() {
                      _winDialogShown = false;
                    });
                    _dailyCubit.reset();
                  },
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
}

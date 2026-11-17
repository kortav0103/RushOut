import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/audio_service.dart';
import '../../domain/repositories/daily_challenge_repository.dart';
import '../../domain/repositories/level_repository.dart';
import '../../domain/usecases/get_leaderboard.dart';
import '../../domain/usecases/submit_score.dart';
import '../bloc/daily_cubit.dart';
import '../bloc/profile_cubit.dart';
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
  final ProfileCubit? profileCubit;
  final String? defaultPlayerName;
  final String? initialDateKey;

  const DailyScreen({
    super.key,
    required this.dailyRepository,
    required this.submitScoreUseCase,
    this.getLeaderboardUseCase,
    required this.audioService,
    this.levelRepository,
    this.profileCubit,
    this.defaultPlayerName,
    this.initialDateKey,
  });

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> with WidgetsBindingObserver {
  late final DailyCubit _dailyCubit;
  bool _winDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dailyCubit = DailyCubit(
      dailyRepository: widget.dailyRepository,
      submitScoreUseCase: widget.submitScoreUseCase,
      audioService: widget.audioService,
      initialDateKey: widget.initialDateKey,
      connectivityStream: Connectivity().onConnectivityChanged.map(
            (results) => results.any((r) => r != ConnectivityResult.none),
          ),
    )..loadDailyChallenge();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _dailyCubit.refreshIfNeeded();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  void _openDailyWinDialog(DailyState state, {bool fromEscape = false}) {
    if (!mounted || !state.isWon) return;
    if (fromEscape) {
      if (_winDialogShown) return;
      _winDialogShown = true;
    }

    DailyWinDialog.show(
      context,
      dailyCubit: _dailyCubit,
      defaultPlayerName:
          widget.defaultPlayerName ?? widget.profileCubit?.state.username,
      onOpenLeaderboard:
          widget.getLeaderboardUseCase != null ? _openLeaderboard : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DailyCubit>.value(
      value: _dailyCubit,
      child: BlocListener<DailyCubit, DailyState>(
        listenWhen: (previous, current) =>
            (previous.status != DailyViewStatus.loading &&
                current.status == DailyViewStatus.loading) ||
            (previous.isSubmittingScore &&
                !current.isSubmittingScore &&
                current.scoreSubmitted),
        listener: (context, state) {
          if (state.status == DailyViewStatus.loading && _winDialogShown) {
            setState(() {
              _winDialogShown = false;
            });
          }
          if (state.scoreSubmitted) {
            final profileCubit = widget.profileCubit;
            final submittedName = state.submittedPlayerName?.trim();
            if (profileCubit != null &&
                !profileCubit.isClosed &&
                !profileCubit.state.hasUsername &&
                submittedName != null &&
                submittedName.isNotEmpty) {
              profileCubit.saveUsername(submittedName);
            }
          }
        },
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
      ),
    );
  }

  /// Explicitly handles all 4 UI states: Loading, Content, Empty, Error.
  Widget _buildBodyForState(DailyState state) {
    switch (state.status) {
      case DailyViewStatus.loading:
        return const ShimmerLoadingView(
          isBoardLayout: true,
          label: 'Loading Daily Challenge',
          subtitle: 'Fetching today\'s puzzle...',
          icon: Icons.calendar_today_rounded,
        );

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

        // When reopening a completed Daily Challenge (review mode) or when
        // synced from server without a local solved snapshot, show a clean
        // completion notification card and disallow replaying.
        if (state.isWon &&
            (state.isReviewMode ||
                !(state.hasSolvedBoardSnapshot && boardState.isWon))) {
          return _buildCompletedNotificationCard(state);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              if (state.isWon)
                _buildCompletedBanner(state, boardState.moveCount),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: ParkingBoardWidget(
                      boardState: boardState,
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
                  showHint: false,
                  onUndo: _dailyCubit.undo,
                  onReset: _dailyCubit.reset,
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
                  'Today\'s Daily Challenge is completed',
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

  Widget _buildCompletedNotificationCard(DailyState state) {
    final bestMoves = state.bestMoves ?? state.submittedMoves ?? 0;
    final stars = state.bestStars;
    final optimalMoves = state.challenge?.optimalMoves;
    final submittedName = state.submittedPlayerName?.trim();
    final hasSubmittedName = submittedName != null && submittedName.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: DaylightColors.surfaceWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: DaylightColors.surfaceLip, width: 2),
              boxShadow: [
                BoxShadow(
                  color: DaylightColors.surfaceLip.withValues(alpha: 0.45),
                  offset: const Offset(0, 6),
                  blurRadius: 0,
                ),
              ],
            ),
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DaylightColors.frontierAmber),
                  ),
                  child: Text(
                    'DAILY • ${state.dateKey} (UTC)',
                    style: DaylightTypography.rounded(
                      color: DaylightColors.frontierAmberLip,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      tabular: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DaylightColors.completedMint.withValues(alpha: 0.16),
                    border: Border.all(
                      color:
                          DaylightColors.completedMint.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: DaylightColors.completedMintLip,
                    size: 36,
                  ),
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
                  'You have already completed today\'s challenge.\nCome back tomorrow for a new puzzle!',
                  textAlign: TextAlign.center,
                  style: DaylightTypography.rounded(
                    color: DaylightColors.inkSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (stars > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.star_rounded,
                          size: i == 1 ? 38 : 32,
                          color: i < stars
                              ? DaylightColors.starGold
                              : DaylightColors.emptyStar,
                        ),
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: DaylightColors.canvasBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DaylightColors.surfaceLip),
                  ),
                  child: Column(
                    children: [
                      if (bestMoves > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your Score',
                              style: DaylightTypography.rounded(
                                color: DaylightColors.inkSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$bestMoves moves',
                              style: DaylightTypography.rounded(
                                color: DaylightColors.inkPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                tabular: true,
                              ),
                            ),
                          ],
                        ),
                      if (optimalMoves != null && optimalMoves > 0) ...[
                        if (bestMoves > 0) const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Optimal',
                              style: DaylightTypography.rounded(
                                color: DaylightColors.inkSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$optimalMoves moves',
                              style: DaylightTypography.rounded(
                                color: DaylightColors.inkPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                tabular: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Leaderboard',
                            style: DaylightTypography.rounded(
                              color: DaylightColors.inkSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  state.scoreSubmitted
                                      ? Icons.check_circle_rounded
                                      : Icons.schedule_rounded,
                                  size: 16,
                                  color: state.scoreSubmitted
                                      ? DaylightColors.completedMintLip
                                      : DaylightColors.frontierAmberLip,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    state.scoreSubmitted
                                        ? (hasSubmittedName
                                            ? 'Submitted ($submittedName)'
                                            : 'Submitted')
                                        : 'Not submitted yet',
                                    overflow: TextOverflow.ellipsis,
                                    style: DaylightTypography.rounded(
                                      color: state.scoreSubmitted
                                          ? DaylightColors.completedMintLip
                                          : DaylightColors.frontierAmberLip,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!state.scoreSubmitted) ...[
                  TactileKeycap(
                    onTap: () => _openDailyWinDialog(state),
                    surfaceColor: DaylightColors.brandRed,
                    lipColor: DaylightColors.brandRedLip,
                    borderRadius: 14,
                    lipHeight: 3,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_upload_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Submit Score',
                            style: DaylightTypography.rounded(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TactileKeycap(
                        onTap: () => Navigator.of(context).pop(),
                        surfaceColor: DaylightColors.canvasBg,
                        lipColor: DaylightColors.surfaceLip,
                        borderColor: DaylightColors.surfaceLip,
                        borderRadius: 14,
                        lipHeight: 3,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Center(
                          child: Text(
                            'Back',
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
                          surfaceColor: state.scoreSubmitted
                              ? DaylightColors.brandRed
                              : DaylightColors.frontierFill,
                          lipColor: state.scoreSubmitted
                              ? DaylightColors.brandRedLip
                              : DaylightColors.frontierAmber,
                          borderColor: state.scoreSubmitted
                              ? null
                              : DaylightColors.frontierAmber,
                          borderRadius: 14,
                          lipHeight: 3,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Center(
                            child: Text(
                              'Leaderboard',
                              style: DaylightTypography.rounded(
                                color: state.scoreSubmitted
                                    ? Colors.white
                                    : DaylightColors.inkPrimary,
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

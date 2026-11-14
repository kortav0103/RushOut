import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/audio_service.dart';
import '../../domain/repositories/daily_challenge_repository.dart';
import '../../domain/usecases/submit_score.dart';
import '../bloc/daily_cubit.dart';
import '../widgets/game_controls.dart';
import '../widgets/how_to_play_dialog.dart';
import '../widgets/parking_board_widget.dart';
import '../widgets/state_views.dart';

class DailyScreen extends StatefulWidget {
  final DailyChallengeRepository dailyRepository;
  final SubmitScore submitScoreUseCase;
  final AudioService audioService;
  final VoidCallback? onOpenLeaderboard;

  const DailyScreen({
    super.key,
    required this.dailyRepository,
    required this.submitScoreUseCase,
    required this.audioService,
    this.onOpenLeaderboard,
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
                backgroundColor: const Color(0xFF1E2126),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Colors.white12, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DAILY CHALLENGE • ${liveState.dateKey}',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'CHALLENGE COMPLETED!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return Icon(
                            i < stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: i < stars
                                ? Colors.amberAccent
                                : Colors.white24,
                            size: 40,
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Cleared in $moves moves (Optimal: $optimal)',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (!liveState.scoreSubmitted) ...[
                        TextField(
                          controller: _nameController,
                          maxLength: 24,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Your Name for Leaderboard',
                            labelStyle: const TextStyle(color: Colors.white60),
                            hintText: 'Enter nickname...',
                            hintStyle: const TextStyle(color: Colors.white30),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        if (liveState.submitErrorMessage != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            liveState.submitErrorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: liveState.isSubmittingScore
                                ? null
                                : () async {
                                    final name = _nameController.text.trim();
                                    if (name.isEmpty) return;
                                    await _dailyCubit.submitPlayerScore(name);
                                  },
                            icon: liveState.isSubmittingScore
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload_rounded),
                            label: Text(
                              liveState.isSubmittingScore
                                  ? 'Submitting...'
                                  : 'Submit Score to Leaderboard',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.greenAccent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Colors.greenAccent,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Score submitted to Leaderboard!',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
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
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                setState(() {
                                  _winDialogShown = false;
                                });
                                _dailyCubit.reset();
                              },
                              child: const Text('Replay'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE53935),
                              ),
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                if (widget.onOpenLeaderboard != null) {
                                  widget.onOpenLeaderboard!();
                                }
                              },
                              child: const Text('Leaderboard'),
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
            backgroundColor: const Color(0xFF141619),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1B1E23),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Challenge',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  Text(
                    state.dateKey,
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
                  tooltip: 'Refresh Daily Puzzle',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    setState(() {
                      _winDialogShown = false;
                    });
                    _dailyCubit.loadDailyChallenge();
                  },
                ),
              ],
            ),
            body: SafeArea(
              child: _buildBodyForState(state),
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
        final boardState = state.boardState!;
        final challenge = state.challenge!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
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
                    Text(
                      'Moves: ${boardState.moveCount} / Optimal: ${boardState.optimalMoves}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (challenge.isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Solved (Best: ${challenge.userMoves})',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
                  onUndo: _dailyCubit.undo,
                  onReset: () {
                    setState(() {
                      _winDialogShown = false;
                    });
                    _dailyCubit.reset();
                  },
                  onHint: _dailyCubit.requestHint,
                ),
              ),
            ],
          ),
        );
    }
  }
}

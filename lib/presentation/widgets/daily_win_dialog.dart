import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/daily_cubit.dart';
import '../theme/daylight_theme.dart';
import 'tactile_widgets.dart';

class DailyWinDialog extends StatefulWidget {
  final String? defaultPlayerName;
  final VoidCallback? onOpenLeaderboard;

  const DailyWinDialog({
    super.key,
    this.defaultPlayerName,
    this.onOpenLeaderboard,
  });

  static Future<void> show(
    BuildContext context, {
    required DailyCubit dailyCubit,
    String? defaultPlayerName,
    VoidCallback? onOpenLeaderboard,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider<DailyCubit>.value(
        value: dailyCubit,
        child: DailyWinDialog(
          defaultPlayerName: defaultPlayerName,
          onOpenLeaderboard: onOpenLeaderboard,
        ),
      ),
    );
  }

  @override
  State<DailyWinDialog> createState() => _DailyWinDialogState();
}

class _DailyWinDialogState extends State<DailyWinDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.defaultPlayerName?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DailyCubit, DailyState>(
      builder: (ctx, liveState) {
        final currentMoves =
            liveState.boardState?.moveCount ?? liveState.bestMoves ?? 0;
        final bestMoves = liveState.bestMoves ?? currentMoves;
        final optimal =
            liveState.boardState?.optimalMoves ??
            liveState.challenge?.optimalMoves ??
            0;
        final stars = liveState.earnedStars;
        final hasBetterPreviousBest =
            bestMoves > 0 && currentMoves > 0 && bestMoves < currentMoves;

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
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
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
                        'DAILY • ${liveState.dateKey}',
                        style: DaylightTypography.rounded(
                          color: DaylightColors.frontierAmberLip,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                          tabular: true,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: DaylightColors.inkSecondary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: DaylightColors.canvasBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DaylightColors.surfaceLip),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Cleared in $currentMoves moves (Optimal: $optimal)',
                        textAlign: TextAlign.center,
                        style: DaylightTypography.rounded(
                          color: DaylightColors.inkPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          tabular: true,
                        ),
                      ),
                      if (hasBetterPreviousBest) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Best today: $bestMoves moves (kept for Leaderboard)',
                          textAlign: TextAlign.center,
                          style: DaylightTypography.rounded(
                            color: DaylightColors.completedMintLip,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            tabular: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (!liveState.scoreSubmitted) ...[
                  TextField(
                    controller: _nameController,
                    maxLength: 24,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!liveState.isSubmittingScore) {
                        ctx
                            .read<DailyCubit>()
                            .submitPlayerScore(_nameController.text);
                      }
                    },
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
                        borderSide: BorderSide(
                          color: liveState.submitErrorMessage != null
                              ? DaylightColors.brandRed
                              : DaylightColors.surfaceLip,
                          width: 1.4,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: liveState.submitErrorMessage != null
                              ? DaylightColors.brandRed
                              : DaylightColors.frontierAmber,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                  if (liveState.submitErrorMessage != null) ...[
                    const SizedBox(height: 6),
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
                  const SizedBox(height: 12),
                  TactileKeycap(
                    enabled: !liveState.isSubmittingScore,
                    onTap: liveState.isSubmittingScore
                        ? null
                        : () => ctx
                            .read<DailyCubit>()
                            .submitPlayerScore(_nameController.text),
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
                              : 'Submit Score ($bestMoves moves)',
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
                        Flexible(
                          child: Text(
                            liveState.submittedMoves != null
                                ? 'Score submitted (${liveState.submittedMoves} moves)!'
                                : 'Score submitted to Leaderboard!',
                            style: DaylightTypography.rounded(
                              color: DaylightColors.completedMintLip,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
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
                        onTap: () => Navigator.of(ctx).pop(),
                        surfaceColor: DaylightColors.canvasBg,
                        lipColor: DaylightColors.surfaceLip,
                        borderColor: DaylightColors.surfaceLip,
                        borderRadius: 12,
                        lipHeight: 3,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Center(
                          child: Text(
                            'Close',
                            style: DaylightTypography.rounded(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: DaylightColors.inkPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.onOpenLeaderboard != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: TactileKeycap(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            widget.onOpenLeaderboard!();
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
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

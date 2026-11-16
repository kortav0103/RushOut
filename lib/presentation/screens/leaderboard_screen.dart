import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/usecases/get_leaderboard.dart';
import '../bloc/leaderboard_cubit.dart';
import '../theme/daylight_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/tactile_widgets.dart';

class LeaderboardScreen extends StatefulWidget {
  final GetLeaderboard getLeaderboardUseCase;
  final String? initialDateKey;

  const LeaderboardScreen({
    super.key,
    required this.getLeaderboardUseCase,
    this.initialDateKey,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = LeaderboardCubit(
      getLeaderboardUseCase: widget.getLeaderboardUseCase,
      initialDate: widget.initialDateKey,
    )..loadLeaderboard();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LeaderboardCubit>.value(
      value: _cubit,
      child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
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
                    'Daily Leaderboard',
                    style: DaylightTypography.rounded(
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      color: DaylightColors.inkPrimary,
                    ),
                  ),
                  Text(
                    'Top 20 • ${state.challengeDate}',
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
                  tooltip: 'Refresh Leaderboard',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: DaylightColors.inkPrimary,
                  ),
                  onPressed: () => _cubit.loadLeaderboard(),
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildBodyForState(state),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Explicitly handles all 4 UI states: Loading (Shimmer), Content, Empty, Error (with Retry).
  Widget _buildBodyForState(LeaderboardState state) {
    switch (state.status) {
      case LeaderboardViewStatus.loading:
        return const ShimmerLoadingView(
          isBoardLayout: false,
          itemCount: 8,
        );

      case LeaderboardViewStatus.empty:
        return EmptyStateView(
          icon: Icons.emoji_events_outlined,
          title: 'No Scores Yet for ${state.challengeDate}',
          message:
              'Be the first player to complete today\'s Daily Challenge and claim the #1 spot on the leaderboard!',
          actionLabel: 'Refresh',
          onAction: () => _cubit.loadLeaderboard(),
        );

      case LeaderboardViewStatus.error:
        return ErrorStateView(
          title: 'Unable to Load Leaderboard',
          message: state.errorMessage ??
              'Network error occurred while fetching top scores.',
          onRetry: () => _cubit.loadLeaderboard(),
        );

      case LeaderboardViewStatus.content:
        return RefreshIndicator(
          color: DaylightColors.brandRed,
          onRefresh: () => _cubit.loadLeaderboard(),
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: state.entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = state.entries[index];
              return _LeaderboardRowCard(
                rank: index + 1,
                entry: entry,
              );
            },
          ),
        );
    }
  }
}

class _LeaderboardRowCard extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;

  const _LeaderboardRowCard({
    required this.rank,
    required this.entry,
  });

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFD97706); // Rich Gold
    if (rank == 2) return const Color(0xFF64748B); // Cool Silver
    if (rank == 3) return const Color(0xFFB45309); // Warm Bronze
    return DaylightColors.inkSecondary;
  }

  Color get _rankBg {
    if (rank == 1) return const Color(0xFFFEF3C7);
    if (rank == 2) return const Color(0xFFF1F5F9);
    if (rank == 3) return const Color(0xFFFFEDD5);
    return DaylightColors.canvasBg;
  }

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: DaylightColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTop3
              ? _rankColor.withValues(alpha: 0.5)
              : DaylightColors.surfaceLip,
          width: isTop3 ? 1.8 : 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: DaylightColors.inkPrimary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _rankBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: isTop3
                    ? _rankColor.withValues(alpha: 0.45)
                    : DaylightColors.surfaceLip,
              ),
            ),
            child: isTop3
                ? Icon(Icons.emoji_events_rounded, color: _rankColor, size: 22)
                : Text(
                    '#$rank',
                    style: DaylightTypography.rounded(
                      color: DaylightColors.inkSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      tabular: true,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DaylightTypography.rounded(
                    color: DaylightColors.inkPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Challenge Date: ${entry.challengeDate}',
                  style: DaylightTypography.rounded(
                    color: DaylightColors.inkSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    tabular: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: DaylightColors.completedMint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DaylightColors.completedMint.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              '${entry.movesCount} moves',
              style: DaylightTypography.rounded(
                color: DaylightColors.completedMintLip,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                tabular: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

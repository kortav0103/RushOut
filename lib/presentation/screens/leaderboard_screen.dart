import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
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
                    '${state.challengeDate} (UTC)',
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
                      child: Column(
                        children: [
                          _UtcDateSwitcherBar(
                            challengeDate: state.challengeDate,
                            canGoNext: state.canGoNextDay,
                            onPrevious: _cubit.previousDay,
                            onNext: _cubit.nextDay,
                          ),
                          Expanded(child: _buildBodyForState(state)),
                        ],
                      ),
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
          label: 'Loading Leaderboard',
          subtitle: 'Fetching top scores...',
          icon: Icons.emoji_events_rounded,
        );

      case LeaderboardViewStatus.empty:
        return EmptyStateView(
          icon: Icons.emoji_events_outlined,
          title: 'No Scores Yet for ${state.challengeDate} (UTC)',
          message:
              'Be the first player to complete today\'s Daily Challenge and claim the #1 spot on the leaderboard!',
          actionLabel: 'Refresh',
          onAction: () => _cubit.loadLeaderboard(),
        );

      case LeaderboardViewStatus.error:
        return ErrorStateView(
          title: 'Unable to Load Leaderboard',
          message: state.errorMessage ??
              'Unable to load the leaderboard right now. Please try again.',
          onRetry: () => _cubit.loadLeaderboard(),
        );

      case LeaderboardViewStatus.content:
        final myRank = state.myRank;
        final hasFooter = state.hasMore ||
            state.isLoadingMore ||
            state.loadMoreErrorMessage != null;
        final itemCount = state.entries.length + (hasFooter ? 1 : 0);

        return RefreshIndicator(
          color: DaylightColors.brandRed,
          onRefresh: () => _cubit.loadLeaderboard(),
          child: Column(
            children: [
              if (myRank != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: _MyRankCard(
                    myRank: myRank,
                    isOutsideLoadedTop: !state.isMyRankInLoadedList,
                    loadedCount: state.entries.length,
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: itemCount,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index >= state.entries.length) {
                      return _PaginationFooter(
                        isLoadingMore: state.isLoadingMore,
                        errorMessage: state.loadMoreErrorMessage,
                        onLoadMore: _cubit.loadMore,
                      );
                    }
                    final entry = state.entries[index];
                    final rank = index + 1;
                    return _LeaderboardRowCard(
                      rank: rank,
                      entry: entry,
                      isCurrentUser: state.isCurrentUserEntry(entry, rank),
                    );
                  },
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _UtcDateSwitcherBar extends StatelessWidget {
  final String challengeDate;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _UtcDateSwitcherBar({
    required this.challengeDate,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        children: [
          TactileKeycap(
            onTap: onPrevious,
            borderRadius: 14,
            lipHeight: 2.5,
            borderColor: DaylightColors.surfaceLip,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: DaylightColors.inkPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: DaylightColors.surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DaylightColors.surfaceLip),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.public_rounded,
                    size: 16,
                    color: DaylightColors.frontierAmberLip,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$challengeDate (UTC)',
                      overflow: TextOverflow.ellipsis,
                      style: DaylightTypography.rounded(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: DaylightColors.inkPrimary,
                        tabular: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          TactileKeycap(
            onTap: canGoNext ? onNext : null,
            enabled: canGoNext,
            surfaceColor: canGoNext
                ? DaylightColors.surfaceWhite
                : DaylightColors.lockedSurface,
            lipColor:
                canGoNext ? DaylightColors.surfaceLip : DaylightColors.lockedLip,
            borderColor:
                canGoNext ? DaylightColors.surfaceLip : DaylightColors.lockedLip,
            borderRadius: 14,
            lipHeight: 2.5,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Icon(
              Icons.chevron_right_rounded,
              color: canGoNext
                  ? DaylightColors.inkPrimary
                  : DaylightColors.lockedInk,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRankCard extends StatelessWidget {
  final PlayerLeaderboardRank myRank;
  final bool isOutsideLoadedTop;
  final int loadedCount;

  const _MyRankCard({
    required this.myRank,
    required this.isOutsideLoadedTop,
    required this.loadedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('my_rank_card'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DaylightColors.frontierFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: DaylightColors.frontierAmber,
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: DaylightColors.frontierAmber.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: DaylightColors.brandRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '#${myRank.rank}',
              style: DaylightTypography.rounded(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                tabular: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'My Rank',
                      style: DaylightTypography.rounded(
                        color: DaylightColors.frontierAmberLip,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (isOutsideLoadedTop) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '• Outside Top $loadedCount',
                          overflow: TextOverflow.ellipsis,
                          style: DaylightTypography.rounded(
                            color: DaylightColors.inkSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  myRank.entry.playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DaylightTypography.rounded(
                    color: DaylightColors.inkPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: DaylightColors.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DaylightColors.frontierAmber.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              '${myRank.entry.movesCount} moves',
              style: DaylightTypography.rounded(
                color: DaylightColors.inkPrimary,
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

class _PaginationFooter extends StatelessWidget {
  final bool isLoadingMore;
  final String? errorMessage;
  final VoidCallback onLoadMore;

  const _PaginationFooter({
    required this.isLoadingMore,
    required this.errorMessage,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: DaylightColors.brandRed,
            ),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: DaylightTypography.rounded(
                color: DaylightColors.brandRedLip,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TactileKeycap(
              onTap: onLoadMore,
              borderRadius: 14,
              lipHeight: 3,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Retry Load More',
                style: DaylightTypography.rounded(
                  color: DaylightColors.inkPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: TactileKeycap(
          onTap: onLoadMore,
          borderRadius: 16,
          lipHeight: 3,
          borderColor: DaylightColors.surfaceLip,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            'Load More',
            style: DaylightTypography.rounded(
              color: DaylightColors.inkPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRowCard extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isCurrentUser;

  const _LeaderboardRowCard({
    required this.rank,
    required this.entry,
    this.isCurrentUser = false,
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
        color: isCurrentUser
            ? DaylightColors.frontierFill
            : DaylightColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentUser
              ? DaylightColors.brandRed
              : (isTop3
                  ? _rankColor.withValues(alpha: 0.5)
                  : DaylightColors.surfaceLip),
          width: isCurrentUser ? 2.0 : (isTop3 ? 1.8 : 1.3),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.playerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DaylightTypography.rounded(
                          color: DaylightColors.inkPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: DaylightColors.brandRed,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'YOU',
                          style: DaylightTypography.rounded(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Challenge Date: ${entry.challengeDate} (UTC)',
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

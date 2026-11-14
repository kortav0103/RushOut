import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/usecases/submit_score.dart';
import '../bloc/leaderboard_cubit.dart';
import '../widgets/state_views.dart';

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
            backgroundColor: const Color(0xFF141619),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1B1E23),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Leaderboard',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  Text(
                    'Top 20 • ${state.challengeDate}',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh Leaderboard',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => _cubit.loadLeaderboard(),
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
    if (rank == 1) return const Color(0xFFFFD700); // Gold
    if (rank == 2) return const Color(0xFFC0C0C0); // Silver
    if (rank == 3) return const Color(0xFFCD7F32); // Bronze
    return Colors.white54;
  }

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isTop3 ? const Color(0xFF232730) : const Color(0xFF1C1F25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop3
              ? _rankColor.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
          width: isTop3 ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _rankColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: isTop3
                ? Icon(Icons.emoji_events_rounded, color: _rankColor, size: 22)
                : Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Challenge Date: ${entry.challengeDate}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${entry.movesCount} moves',
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

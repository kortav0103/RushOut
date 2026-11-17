import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/tutorial_service.dart';
import '../../domain/entities/level.dart';
import '../../domain/usecases/get_levels.dart';
import '../../domain/usecases/save_progress.dart';
import '../bloc/level_select_cubit.dart';
import '../theme/daylight_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/tactile_widgets.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  final GetLevels getLevelsUseCase;
  final SaveProgress saveProgressUseCase;
  final AudioService audioService;
  final TutorialService? tutorialService;
  final bool autoStartTutorial;

  const LevelSelectScreen({
    super.key,
    required this.getLevelsUseCase,
    required this.saveProgressUseCase,
    required this.audioService,
    this.tutorialService,
    this.autoStartTutorial = false,
  });

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  static const int _crossAxisCount = 5;
  static const double _gridSpacing = 12.0;
  static const double _tileAspectRatio = 1.05;
  static const double _horizontalPadding = 16.0;
  static const double _heroCardApproxHeight = 114.0;

  late final LevelSelectCubit _cubit;
  final ScrollController _scrollController = ScrollController();
  bool _hasAutoScrolledOnOpen = false;
  bool _hasAutoStartedTutorial = false;
  double _lastGridContentWidth = 400.0;

  @override
  void initState() {
    super.initState();
    _cubit = LevelSelectCubit(
      getLevelsUseCase: widget.getLevelsUseCase,
      tutorialService: widget.tutorialService,
    )..loadLevels();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cubit.close();
    super.dispose();
  }

  void _scrollToLevelIndex(int index, {bool animate = true}) {
    if (!_scrollController.hasClients) return;

    final usableWidth = _lastGridContentWidth -
        (_horizontalPadding * 2) -
        (_gridSpacing * (_crossAxisCount - 1));
    if (usableWidth <= 0) return;

    final tileWidth = usableWidth / _crossAxisCount;
    final tileHeight = tileWidth / _tileAspectRatio;
    final rowExtent = tileHeight + _gridSpacing;
    final row = index ~/ _crossAxisCount;

    final viewportHeight = _scrollController.position.viewportDimension;
    final rawOffset =
        _heroCardApproxHeight + (row * rowExtent) - (viewportHeight * 0.35);
    final clampedOffset = rawOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(clampedOffset);
    }
  }

  Future<void> _openLevel(
    Level level,
    int displayNumber,
    List<Level> allLevels,
  ) async {
    if (!level.isUnlocked) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DaylightColors.inkPrimary,
          content: Text(
            'Complete Level #${displayNumber - 1} to unlock!',
            style: DaylightTypography.rounded(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final shouldRunTutorial = _cubit.state.shouldRunTutorialForLevel(displayNumber);

    await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          initialLevel: level,
          allLevels: allLevels,
          audioService: widget.audioService,
          saveProgressUseCase: widget.saveProgressUseCase,
          tutorialService: widget.tutorialService,
          initialTutorialMode: shouldRunTutorial,
        ),
      ),
    );

    if (mounted) {
      await _cubit.loadLevels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LevelSelectCubit>.value(
      value: _cubit,
      child: BlocConsumer<LevelSelectCubit, LevelSelectState>(
        listener: (context, state) {
          if (!state.isLoading && state.levels.isNotEmpty) {
            if (!_hasAutoScrolledOnOpen) {
              _hasAutoScrolledOnOpen = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _scrollToLevelIndex(state.frontierIndex, animate: false);
                }
              });
            }
            if (widget.autoStartTutorial &&
                !_hasAutoStartedTutorial &&
                state.shouldRunTutorialForLevel(1)) {
              _hasAutoStartedTutorial = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _openLevel(state.levels.first, 1, state.levels);
                }
              });
            }
          }
        },
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
              title: Text(
                'Select Level',
                style: DaylightTypography.rounded(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: DaylightColors.inkPrimary,
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: DaylightColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: DaylightColors.surfaceLip,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: DaylightColors.inkPrimary.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: DaylightColors.starGold,
                        size: 19,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${state.totalEarnedStars} / ${state.maxPossibleStars}',
                        style: DaylightTypography.rounded(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: DaylightColors.inkPrimary,
                          tabular: true,
                        ),
                      ),
                    ],
                  ),
                ),
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
                  child: state.isLoading
                      ? const ShimmerLoadingView(
                          isBoardLayout: false,
                          itemCount: 6,
                          label: 'Loading Levels',
                          subtitle: 'Preparing campaign stages...',
                          icon: Icons.grid_view_rounded,
                        )
                      : state.errorMessage != null
                          ? ErrorStateView(
                              title: 'Failed to Load Levels',
                              message: state.errorMessage!,
                              onRetry: () => _cubit.loadLevels(),
                            )
                          : state.levels.isEmpty
                              ? EmptyStateView(
                                  title: 'No Campaign Levels Found',
                                  message:
                                      'Could not find any valid levels in assets/levels/rush1000.txt.',
                                  actionLabel: 'Reload',
                                  onAction: () => _cubit.loadLevels(),
                                )
                              : _buildLinearGridBody(context, state),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLinearGridBody(BuildContext context, LevelSelectState state) {
    final frontierIndex = state.frontierIndex;
    final frontierLevel = state.frontierLevel!;
    final frontierNumber = frontierIndex + 1;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _lastGridContentWidth = constraints.maxWidth;

            return CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. Hero "Continue" Card
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    _horizontalPadding,
                    14,
                    _horizontalPadding,
                    18,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _ContinueHeroCard(
                      levelNumber: frontierNumber,
                      onTapCard: () =>
                          _scrollToLevelIndex(frontierIndex, animate: true),
                      onPlay: () => _openLevel(
                        frontierLevel,
                        frontierNumber,
                        state.levels,
                      ),
                    ),
                  ),
                ),

                // 2. Continuous 5-Column Linear Grid (#1 to #4050)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    _horizontalPadding,
                    0,
                    _horizontalPadding,
                    28,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _crossAxisCount,
                      mainAxisSpacing: _gridSpacing,
                      crossAxisSpacing: _gridSpacing,
                      childAspectRatio: _tileAspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final level = state.levels[index];
                        final displayNumber = index + 1;
                        final isCurrent = index == frontierIndex;
                        return _TactileLevelTile(
                          displayNumber: displayNumber,
                          level: level,
                          isCurrent: isCurrent,
                          isSkipped: level.isSkipped,
                          onTap: () => _openLevel(
                            level,
                            displayNumber,
                            state.levels,
                          ),
                        );
                      },
                      childCount: state.levels.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ContinueHeroCard extends StatelessWidget {
  final int levelNumber;
  final VoidCallback onTapCard;
  final VoidCallback onPlay;

  const _ContinueHeroCard({
    required this.levelNumber,
    required this.onTapCard,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapCard,
      child: Container(
        padding: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: DaylightColors.surfaceLip,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: DaylightColors.inkPrimary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: DaylightColors.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: DaylightColors.surfaceLip,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              // Left: Mini road-lane badge
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: DaylightColors.asphaltBadge,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 6,
                      right: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          4,
                          (_) => Container(
                            width: 5,
                            height: 2,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.directions_car_filled_rounded,
                      color: DaylightColors.brandRed,
                      size: 26,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Middle: CONTINUE + Level #X
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTINUE',
                      style: DaylightTypography.rounded(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: DaylightColors.brandRed,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Level #$levelNumber',
                      style: DaylightTypography.rounded(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: DaylightColors.inkPrimary,
                        tabular: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right: Vibrant 3D PLAY button
              TactileKeycap(
                onTap: onPlay,
                surfaceColor: DaylightColors.brandRed,
                lipColor: DaylightColors.brandRedLip,
                borderRadius: 14,
                lipHeight: 3.5,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'PLAY',
                      style: DaylightTypography.rounded(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TactileLevelTile extends StatelessWidget {
  final int displayNumber;
  final Level level;
  final bool isCurrent;
  final bool isSkipped;
  final VoidCallback onTap;

  const _TactileLevelTile({
    required this.displayNumber,
    required this.level,
    required this.isCurrent,
    this.isSkipped = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stars = level.stars;
    final isLocked = !level.isUnlocked;
    final isThreeStars = stars == 3;
    final isCompleted = stars > 0;

    final Color surfaceColor;
    final Color lipColor;
    final Color? borderColor;
    final double borderWidth;
    final double lipHeight;

    if (isLocked) {
      surfaceColor = DaylightColors.lockedSurface;
      lipColor = DaylightColors.lockedLip;
      borderColor = DaylightColors.lockedLip;
      borderWidth = 1.0;
      lipHeight = 2.0;
    } else if (isCurrent && !isCompleted) {
      surfaceColor = DaylightColors.frontierFill;
      lipColor = DaylightColors.frontierAmberLip;
      borderColor = DaylightColors.frontierAmber;
      borderWidth = 2.5;
      lipHeight = 3.5;
    } else if (isThreeStars) {
      surfaceColor = DaylightColors.surfaceWhite;
      lipColor = DaylightColors.completedMintLip;
      borderColor = DaylightColors.completedMint;
      borderWidth = 2.0;
      lipHeight = 3.5;
    } else {
      surfaceColor = DaylightColors.surfaceWhite;
      lipColor = DaylightColors.surfaceLip;
      borderColor = DaylightColors.surfaceLip;
      borderWidth = 1.2;
      lipHeight = 3.5;
    }

    return TactileKeycap(
      onTap: onTap,
      surfaceColor: surfaceColor,
      lipColor: lipColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      borderRadius: 16,
      lipHeight: lipHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '#$displayNumber',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DaylightTypography.rounded(
                fontSize: displayNumber >= 1000 ? 13 : 15,
                fontWeight: FontWeight.w900,
                color: isLocked
                    ? DaylightColors.lockedInk
                    : DaylightColors.inkPrimary,
                height: 1.1,
                tabular: true,
              ),
            ),
            const SizedBox(height: 5),
            if (isLocked)
              const Icon(
                Icons.lock_rounded,
                size: 14,
                color: DaylightColors.lockedInk,
              )
            else if (stars == 0 && !isSkipped)
              Icon(
                Icons.play_arrow_rounded,
                size: 17,
                color: isCurrent
                    ? DaylightColors.frontierAmberLip
                    : DaylightColors.brandRed,
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final earned = i < stars;
                  return Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: earned
                        ? DaylightColors.starGold
                        : const Color(0xFFD5CEC0),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}

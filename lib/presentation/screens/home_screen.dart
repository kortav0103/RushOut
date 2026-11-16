import 'package:flutter/material.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/player_identity_service.dart';
import '../../core/services/tutorial_service.dart';
import '../../domain/repositories/daily_challenge_repository.dart';
import '../../domain/usecases/get_levels.dart';
import '../../domain/usecases/save_progress.dart';
import '../../domain/usecases/get_leaderboard.dart';
import '../../domain/usecases/submit_score.dart';
import '../theme/daylight_theme.dart';
import '../widgets/dialogs/privacy_policy_dialog.dart';
import '../widgets/dialogs/profile_dialog.dart';
import '../widgets/dialogs/settings_dialog.dart';
import '../widgets/dialogs/username_prompt_dialog.dart';
import '../widgets/how_to_play_dialog.dart';
import '../widgets/tactile_widgets.dart';
import 'daily_screen.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'level_select_screen.dart';

class HomeScreen extends StatefulWidget {
  final AudioService audioService;
  final TutorialService? tutorialService;
  final PlayerIdentityService? playerIdentityService;
  final GetLevels getLevelsUseCase;
  final SaveProgress saveProgressUseCase;
  final DailyChallengeRepository dailyRepository;
  final SubmitScore submitScoreUseCase;
  final GetLeaderboard getLeaderboardUseCase;

  const HomeScreen({
    super.key,
    required this.audioService,
    this.tutorialService,
    this.playerIdentityService,
    required this.getLevelsUseCase,
    required this.saveProgressUseCase,
    required this.dailyRepository,
    required this.submitScoreUseCase,
    required this.getLeaderboardUseCase,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TutorialService _tutorialService;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _tutorialService = widget.tutorialService ?? TutorialService();
    widget.audioService.startBgm();
    final identity = widget.playerIdentityService;
    if (identity != null && !identity.hasUsername) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showUsernamePromptDialog(isFirstLaunch: true);
        }
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: DaylightColors.brandRed,
          content: Text(
            message,
            style: DaylightTypography.rounded(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  Future<void> _onPlayCampaignTapped() async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      final completed = await _tutorialService.hasCompletedTutorial();
      if (!mounted) return;

      if (!completed) {
        final levels = await widget.getLevelsUseCase();
        if (!mounted) return;
        if (levels.isNotEmpty) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GameScreen(
                initialLevel: levels.first,
                allLevels: levels,
                audioService: widget.audioService,
                saveProgressUseCase: widget.saveProgressUseCase,
                tutorialService: _tutorialService,
                initialTutorialMode: true,
              ),
            ),
          );
          return;
        }
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LevelSelectScreen(
            getLevelsUseCase: widget.getLevelsUseCase,
            saveProgressUseCase: widget.saveProgressUseCase,
            audioService: widget.audioService,
            tutorialService: _tutorialService,
          ),
        ),
      );
    } catch (_) {
      _showErrorSnackBar('Unable to load campaign levels. Please try again.');
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> _toggleMute() async {
    await widget.audioService.toggleMute();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startTutorialFromSettings() async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      final levels = await widget.getLevelsUseCase();
      if (!mounted || levels.isEmpty) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            initialLevel: levels.first,
            allLevels: levels,
            audioService: widget.audioService,
            saveProgressUseCase: widget.saveProgressUseCase,
            tutorialService: _tutorialService,
            initialTutorialMode: true,
          ),
        ),
      );
    } catch (_) {
      _showErrorSnackBar('Unable to start tutorial. Please try again.');
    } finally {
      _isNavigating = false;
    }
  }

  void _showSettingsDialog() {
    SettingsDialog.show(
      context,
      isMuted: () => widget.audioService.isMuted,
      onToggleMute: _toggleMute,
      onReplayTutorial: _startTutorialFromSettings,
      onOpenPrivacyPolicy: _showPrivacyPolicyDialog,
    );
  }

  void _openLeaderboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeaderboardScreen(
          getLeaderboardUseCase: widget.getLeaderboardUseCase,
        ),
      ),
    );
  }

  void _openDailyChallenge() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyScreen(
          dailyRepository: widget.dailyRepository,
          submitScoreUseCase: widget.submitScoreUseCase,
          audioService: widget.audioService,
          onOpenLeaderboard: _openLeaderboard,
          defaultPlayerName: widget.playerIdentityService?.username,
        ),
      ),
    );
  }

  Future<void> _showUsernamePromptDialog({bool isFirstLaunch = false}) async {
    final identity = widget.playerIdentityService;
    if (identity == null) return;

    await UsernamePromptDialog.show(
      context,
      identity: identity,
      isFirstLaunch: isFirstLaunch,
      onSaved: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _showProfileDialog() async {
    final identity = widget.playerIdentityService;
    if (identity == null) return;

    await ProfileDialog.show(
      context,
      identity: identity,
      onEditName: () => _showUsernamePromptDialog(isFirstLaunch: false),
      onSynced: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _showPrivacyPolicyDialog() {
    PrivacyPolicyDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DaylightColors.canvasBg,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 32)
                          .clamp(0.0, double.infinity),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // Top Action Bar: Driver Profile Pill + How to Play (?) & Settings
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (widget.playerIdentityService != null)
                                TactileKeycap(
                                  onTap: _showProfileDialog,
                                  surfaceColor: DaylightColors.surfaceWhite,
                                  lipColor: DaylightColors.surfaceLip,
                                  borderColor: DaylightColors.surfaceLip,
                                  borderRadius: 14,
                                  lipHeight: 2.5,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.person_rounded,
                                        size: 18,
                                        color: widget.playerIdentityService!
                                                .isCloudSynced
                                            ? DaylightColors.completedMintLip
                                            : DaylightColors.frontierAmberLip,
                                      ),
                                      const SizedBox(width: 6),
                                      ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 130),
                                        child: Text(
                                          widget.playerIdentityService!
                                                  .username ??
                                              'Set Name',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: DaylightTypography.rounded(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: DaylightColors.inkPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _TopIconButton(
                                    tooltip: 'How to Play',
                                    icon: Icons.help_outline_rounded,
                                    iconColor: DaylightColors.inkPrimary,
                                    onTap: () => HowToPlayDialog.show(context),
                                  ),
                                  const SizedBox(width: 10),
                                  _TopIconButton(
                                    tooltip: 'Settings',
                                    icon: Icons.settings_rounded,
                                    iconColor: DaylightColors.inkPrimary,
                                    onTap: _showSettingsDialog,
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const Spacer(),
                          const SizedBox(height: 16),

                          // Hero Logo & Title
                          Container(
                            width: 112,
                            height: 112,
                            padding: const EdgeInsets.only(bottom: 5),
                            decoration: BoxDecoration(
                              color: DaylightColors.brandRedLip,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: DaylightColors.brandRed
                                      .withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    DaylightColors.brandRed,
                                    Color(0xFFE03131),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Icon(
                                Icons.directions_car_filled_rounded,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'RUSHOUT',
                            style: DaylightTypography.rounded(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: DaylightColors.inkPrimary,
                              letterSpacing: 3.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '6×6 PARKING JAM SLIDING PUZZLE',
                            style: DaylightTypography.rounded(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: DaylightColors.inkSecondary,
                              letterSpacing: 1.6,
                            ),
                          ),

                          const Spacer(),
                          const SizedBox(height: 20),

                          // Main Navigation Menu Buttons
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TactileKeycap(
                                  onTap: _onPlayCampaignTapped,
                                  surfaceColor: DaylightColors.brandRed,
                                  lipColor: DaylightColors.brandRedLip,
                                  borderRadius: 18,
                                  lipHeight: 4.0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 20,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 28,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'PLAY CAMPAIGN',
                                        style: DaylightTypography.rounded(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TactileKeycap(
                                  onTap: _openDailyChallenge,
                                  surfaceColor: DaylightColors.frontierFill,
                                  lipColor: DaylightColors.frontierAmberLip,
                                  borderColor: DaylightColors.frontierAmber,
                                  borderWidth: 2.0,
                                  borderRadius: 18,
                                  lipHeight: 3.5,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                    horizontal: 20,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 20,
                                        color: DaylightColors.frontierAmberLip,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'DAILY CHALLENGE',
                                        style: DaylightTypography.rounded(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: DaylightColors.inkPrimary,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TactileKeycap(
                                  onTap: _openLeaderboard,
                                  surfaceColor: DaylightColors.surfaceWhite,
                                  lipColor: DaylightColors.surfaceLip,
                                  borderColor: DaylightColors.surfaceLip,
                                  borderWidth: 1.2,
                                  borderRadius: 18,
                                  lipHeight: 3.5,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                    horizontal: 20,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.emoji_events_rounded,
                                        size: 22,
                                        color: DaylightColors.starGold,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'LEADERBOARD',
                                        style: DaylightTypography.rounded(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: DaylightColors.inkPrimary,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.tooltip,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TactileKeycap(
        onTap: onTap,
        surfaceColor: DaylightColors.surfaceWhite,
        lipColor: DaylightColors.surfaceLip,
        borderColor: DaylightColors.surfaceLip,
        borderRadius: 14,
        lipHeight: 2.5,
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

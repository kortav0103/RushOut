import 'package:flutter/material.dart';
import '../core/services/audio_service.dart';
import '../core/services/player_identity_service.dart';
import '../core/services/tutorial_service.dart';
import '../domain/repositories/daily_challenge_repository.dart';
import '../domain/usecases/get_leaderboard.dart';
import '../domain/usecases/get_levels.dart';
import '../domain/usecases/save_progress.dart';
import '../domain/usecases/submit_score.dart';
import '../presentation/bloc/profile_cubit.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/theme/daylight_theme.dart';
import 'app_dependencies.dart';

class RushOutApp extends StatefulWidget {
  final AudioService audioService;
  final TutorialService? tutorialService;
  final PlayerIdentityService? playerIdentityService;
  final ProfileCubit? profileCubit;
  final GetLevels getLevelsUseCase;
  final SaveProgress saveProgressUseCase;
  final DailyChallengeRepository dailyRepository;
  final SubmitScore submitScoreUseCase;
  final GetLeaderboard getLeaderboardUseCase;
  final bool disposeAudioOnClose;

  const RushOutApp({
    super.key,
    required this.audioService,
    this.tutorialService,
    this.playerIdentityService,
    this.profileCubit,
    required this.getLevelsUseCase,
    required this.saveProgressUseCase,
    required this.dailyRepository,
    required this.submitScoreUseCase,
    required this.getLeaderboardUseCase,
    this.disposeAudioOnClose = false,
  });

  factory RushOutApp.fromDependencies(AppDependencies deps, {Key? key}) {
    return RushOutApp(
      key: key,
      audioService: deps.audioService,
      tutorialService: deps.tutorialService,
      playerIdentityService: deps.playerIdentityService,
      profileCubit: deps.profileCubit,
      getLevelsUseCase: deps.getLevelsUseCase,
      saveProgressUseCase: deps.saveProgressUseCase,
      dailyRepository: deps.dailyRepository,
      submitScoreUseCase: deps.submitScoreUseCase,
      getLeaderboardUseCase: deps.getLeaderboardUseCase,
      disposeAudioOnClose: true,
    );
  }

  @override
  State<RushOutApp> createState() => _RushOutAppState();
}

class _RushOutAppState extends State<RushOutApp> {
  @override
  void dispose() {
    if (widget.disposeAudioOnClose) {
      widget.audioService.dispose();
      widget.profileCubit?.close();
      widget.playerIdentityService?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RushOut',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: DaylightColors.brandRed,
          brightness: Brightness.light,
          surface: DaylightColors.surfaceWhite,
        ),
        scaffoldBackgroundColor: DaylightColors.canvasBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: DaylightColors.canvasBg,
          foregroundColor: DaylightColors.inkPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
        audioService: widget.audioService,
        tutorialService: widget.tutorialService ?? TutorialService(),
        profileCubit: widget.profileCubit,
        getLevelsUseCase: widget.getLevelsUseCase,
        saveProgressUseCase: widget.saveProgressUseCase,
        dailyRepository: widget.dailyRepository,
        submitScoreUseCase: widget.submitScoreUseCase,
        getLeaderboardUseCase: widget.getLeaderboardUseCase,
      ),
    );
  }
}

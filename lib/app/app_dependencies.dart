import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/network/network_info.dart';
import '../core/services/audio_service.dart';
import '../core/services/player_identity_service.dart';
import '../core/services/tutorial_service.dart';
import '../data/datasources/level_asset_datasource.dart';
import '../data/datasources/local_database_datasource.dart';
import '../data/datasources/supabase_remote_datasource.dart';
import '../data/repositories/daily_challenge_repository_impl.dart';
import '../data/repositories/leaderboard_repository_impl.dart';
import '../data/repositories/level_repository_impl.dart';
import '../domain/repositories/daily_challenge_repository.dart';
import '../domain/usecases/get_leaderboard.dart';
import '../domain/usecases/get_levels.dart';
import '../domain/usecases/save_progress.dart';
import '../domain/usecases/submit_score.dart';

/// Composition root holding initialized services, repositories, and use cases.
class AppDependencies {
  final AudioService audioService;
  final TutorialService tutorialService;
  final PlayerIdentityService playerIdentityService;
  final GetLevels getLevelsUseCase;
  final SaveProgress saveProgressUseCase;
  final DailyChallengeRepository dailyRepository;
  final SubmitScore submitScoreUseCase;
  final GetLeaderboard getLeaderboardUseCase;

  const AppDependencies({
    required this.audioService,
    required this.tutorialService,
    required this.playerIdentityService,
    required this.getLevelsUseCase,
    required this.saveProgressUseCase,
    required this.dailyRepository,
    required this.submitScoreUseCase,
    required this.getLeaderboardUseCase,
  });

  static bool _desktopDbInitialized = false;

  static void _ensureDesktopDatabaseFactory() {
    if (_desktopDbInitialized || kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _desktopDbInitialized = true;
    }
  }

  static Future<AppDependencies> init() async {
    _ensureDesktopDatabaseFactory();
    final audioService = AudioService();
    await audioService.init();

    final tutorialService = TutorialService();
    final networkInfo = NetworkInfoImpl(Connectivity());
    final assetDataSource = LevelAssetDataSource();
    final localDataSource = LocalDatabaseDataSource();
    final remoteDataSource = SupabaseRemoteDataSource();

    final playerIdentityService = PlayerIdentityService(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      tutorialService: tutorialService,
      networkInfo: networkInfo,
    );
    await playerIdentityService.init();

    // Only sync with cloud on startup when the player has explicitly opted in.
    if (playerIdentityService.isCloudSyncEnabled) {
      try {
        await playerIdentityService
            .syncWithCloud()
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    final levelRepository = LevelRepositoryImpl(
      assetDataSource: assetDataSource,
      localDataSource: localDataSource,
      onProgressChanged: () async {
        if (playerIdentityService.isCloudSyncEnabled) {
          await playerIdentityService.syncWithCloud();
        }
      },
    );
    final dailyRepository = DailyChallengeRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      networkInfo: networkInfo,
    );
    final leaderboardRepository = LeaderboardRepositoryImpl(
      remoteDataSource: remoteDataSource,
      networkInfo: networkInfo,
    );

    return AppDependencies(
      audioService: audioService,
      tutorialService: tutorialService,
      playerIdentityService: playerIdentityService,
      getLevelsUseCase: GetLevels(levelRepository),
      saveProgressUseCase: SaveProgress(levelRepository),
      dailyRepository: dailyRepository,
      submitScoreUseCase: SubmitScore(leaderboardRepository),
      getLeaderboardUseCase: GetLeaderboard(leaderboardRepository),
    );
  }
}

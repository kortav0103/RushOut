import 'dart:async';
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
import '../domain/repositories/level_repository.dart';
import '../domain/usecases/get_leaderboard.dart';
import '../domain/usecases/get_levels.dart';
import '../domain/usecases/save_progress.dart';
import '../domain/usecases/submit_score.dart';
import '../presentation/bloc/profile_cubit.dart';

/// Composition root holding initialized services, repositories, and use cases.
class AppDependencies {
  final AudioService audioService;
  final TutorialService tutorialService;
  final PlayerIdentityService playerIdentityService;
  final ProfileCubit profileCubit;
  final LevelRepository levelRepository;
  final GetLevels getLevelsUseCase;
  final SaveProgress saveProgressUseCase;
  final DailyChallengeRepository dailyRepository;
  final SubmitScore submitScoreUseCase;
  final GetLeaderboard getLeaderboardUseCase;

  const AppDependencies({
    required this.audioService,
    required this.tutorialService,
    required this.playerIdentityService,
    required this.profileCubit,
    required this.levelRepository,
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

  static Future<AppDependencies> init({
    @visibleForTesting AudioService? audioService,
    @visibleForTesting PlayerIdentityService? playerIdentityService,
  }) async {
    _ensureDesktopDatabaseFactory();
    final resolvedAudioService = audioService ?? AudioService();
    await resolvedAudioService.init();

    try {
      final tutorialService = TutorialService();
      final networkInfo = NetworkInfoImpl(Connectivity());
      final assetDataSource = LevelAssetDataSource();
      final localDataSource = LocalDatabaseDataSource();
      final remoteDataSource = SupabaseRemoteDataSource();

      final resolvedIdentityService = playerIdentityService ??
          PlayerIdentityService(
            remoteDataSource: remoteDataSource,
            localDataSource: localDataSource,
            tutorialService: tutorialService,
            networkInfo: networkInfo,
          );
      await resolvedIdentityService.init();

      // Only sync with cloud on startup when the player has explicitly opted in.
      // Run non-blocking in the background so cold start stays instantaneous.
      if (resolvedIdentityService.isCloudSyncEnabled) {
        unawaited(
          resolvedIdentityService
              .syncWithCloud()
              .timeout(const Duration(seconds: 2))
              .then<void>((_) {}, onError: (_) {}),
        );
      }

      final profileCubit = ProfileCubit(identityService: resolvedIdentityService);

      final levelRepository = LevelRepositoryImpl(
        assetDataSource: assetDataSource,
        localDataSource: localDataSource,
        onProgressChanged: () async {
          if (resolvedIdentityService.isCloudSyncEnabled) {
            await resolvedIdentityService.syncWithCloud();
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
        audioService: resolvedAudioService,
        tutorialService: tutorialService,
        playerIdentityService: resolvedIdentityService,
        profileCubit: profileCubit,
        levelRepository: levelRepository,
        getLevelsUseCase: GetLevels(levelRepository),
        saveProgressUseCase: SaveProgress(levelRepository),
        dailyRepository: dailyRepository,
        submitScoreUseCase: SubmitScore(leaderboardRepository),
        getLeaderboardUseCase: GetLeaderboard(leaderboardRepository),
      );
    } catch (_) {
      try {
        await resolvedAudioService.dispose();
      } catch (_) {}
      rethrow;
    }
  }
}

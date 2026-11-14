import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/network/network_info.dart';
import 'core/services/audio_service.dart';
import 'data/datasources/level_asset_datasource.dart';
import 'data/datasources/local_database_datasource.dart';
import 'data/datasources/supabase_remote_datasource.dart';
import 'data/repositories/daily_challenge_repository_impl.dart';
import 'data/repositories/leaderboard_repository_impl.dart';
import 'data/repositories/level_repository_impl.dart';
import 'domain/repositories/daily_challenge_repository.dart';
import 'domain/usecases/get_levels.dart';
import 'domain/usecases/save_progress.dart';
import 'domain/usecases/submit_score.dart';
import 'presentation/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Graceful fallback if .env is not yet configured
  }

  final audioService = AudioService();
  await audioService.init();

  final networkInfo = NetworkInfoImpl(Connectivity());
  final assetDataSource = LevelAssetDataSource();
  final localDataSource = LocalDatabaseDataSource();
  final remoteDataSource = SupabaseRemoteDataSource();

  final levelRepository = LevelRepositoryImpl(
    assetDataSource: assetDataSource,
    localDataSource: localDataSource,
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

  final getLevelsUseCase = GetLevels(levelRepository);
  final saveProgressUseCase = SaveProgress(levelRepository);
  final submitScoreUseCase = SubmitScore(leaderboardRepository);
  final getLeaderboardUseCase = GetLeaderboard(leaderboardRepository);

  runApp(
    RushOutApp(
      audioService: audioService,
      getLevelsUseCase: getLevelsUseCase,
      saveProgressUseCase: saveProgressUseCase,
      dailyRepository: dailyRepository,
      submitScoreUseCase: submitScoreUseCase,
      getLeaderboardUseCase: getLeaderboardUseCase,
    ),
  );
}

class RushOutApp extends StatelessWidget {
  final AudioService audioService;
  final GetLevels getLevelsUseCase;
  final SaveProgress saveProgressUseCase;
  final DailyChallengeRepository dailyRepository;
  final SubmitScore submitScoreUseCase;
  final GetLeaderboard getLeaderboardUseCase;

  const RushOutApp({
    super.key,
    required this.audioService,
    required this.getLevelsUseCase,
    required this.saveProgressUseCase,
    required this.dailyRepository,
    required this.submitScoreUseCase,
    required this.getLeaderboardUseCase,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RushOut',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
        audioService: audioService,
        getLevelsUseCase: getLevelsUseCase,
        saveProgressUseCase: saveProgressUseCase,
        dailyRepository: dailyRepository,
        submitScoreUseCase: submitScoreUseCase,
        getLeaderboardUseCase: getLeaderboardUseCase,
      ),
    );
  }
}

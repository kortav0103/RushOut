import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/services/audio_service.dart';
import 'package:rush_out/data/datasources/level_asset_datasource.dart';
import 'package:rush_out/data/datasources/local_database_datasource.dart';
import 'package:rush_out/data/datasources/supabase_remote_datasource.dart';
import 'package:rush_out/data/repositories/daily_challenge_repository_impl.dart';
import 'package:rush_out/data/repositories/leaderboard_repository_impl.dart';
import 'package:rush_out/data/repositories/level_repository_impl.dart';
import 'package:rush_out/domain/usecases/get_levels.dart';
import 'package:rush_out/domain/usecases/save_progress.dart';
import 'package:rush_out/domain/usecases/submit_score.dart';
import 'package:rush_out/core/network/network_info.dart';
import 'package:rush_out/main.dart';

class _FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;
}

void main() {
  testWidgets('RushOut HomeScreen renders title and navigation buttons',
      (WidgetTester tester) async {
    final audioService = AudioService(enablePlatformAudio: false);
    final localDataSource = LocalDatabaseDataSource();
    final assetDataSource = LevelAssetDataSource();
    final remoteDataSource = SupabaseRemoteDataSource();
    final networkInfo = _FakeNetworkInfo();

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

    await tester.pumpWidget(
      RushOutApp(
        audioService: audioService,
        getLevelsUseCase: GetLevels(levelRepository),
        saveProgressUseCase: SaveProgress(levelRepository),
        dailyRepository: dailyRepository,
        submitScoreUseCase: SubmitScore(leaderboardRepository),
        getLeaderboardUseCase: GetLeaderboard(leaderboardRepository),
      ),
    );

    expect(find.text('RUSHOUT'), findsOneWidget);
    expect(find.text('PLAY CAMPAIGN'), findsOneWidget);
    expect(find.text('DAILY CHALLENGE'), findsOneWidget);
    expect(find.text('LEADERBOARD'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
  });
}

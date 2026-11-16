import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/network/network_info.dart';
import 'package:rush_out/core/services/audio_service.dart';
import 'package:rush_out/core/services/error_reporting_service.dart';
import 'package:rush_out/data/datasources/level_asset_datasource.dart';
import 'package:rush_out/data/datasources/supabase_remote_datasource.dart';
import 'package:rush_out/data/repositories/level_repository_impl.dart';
import 'package:rush_out/data/repositories/daily_challenge_repository_impl.dart';
import 'package:rush_out/domain/entities/leaderboard_entry.dart';
import 'package:rush_out/domain/entities/level.dart';
import 'package:rush_out/domain/entities/move.dart';
import 'package:rush_out/domain/repositories/daily_challenge_repository.dart';
import 'package:rush_out/domain/repositories/leaderboard_repository.dart';
import 'package:rush_out/domain/usecases/save_progress.dart';
import 'package:rush_out/domain/usecases/submit_score.dart';
import 'package:rush_out/presentation/bloc/daily_cubit.dart';
import 'package:rush_out/presentation/bloc/game_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/in_memory_local_database_datasource.dart';

class _FakeDailyChallengeRepository implements DailyChallengeRepository {
  DailyChallenge challenge;
  int saveCompletionCalls = 0;
  int markSubmittedCalls = 0;

  _FakeDailyChallengeRepository(this.challenge);

  @override
  Future<DailyChallenge> getDailyChallenge(String dateKey) async => challenge;

  @override
  Future<DailyChallenge> saveDailyCompletion({
    required String dateKey,
    required int userMoves,
  }) async {
    saveCompletionCalls++;
    challenge = challenge.copyWith(
      isCompleted: true,
      userMoves: userMoves,
    );
    return challenge;
  }

  @override
  Future<DailyChallenge?> markScoreSubmitted(String dateKey) async {
    markSubmittedCalls++;
    challenge = challenge.copyWith(
      isCompleted: true,
      scoreSubmitted: true,
    );
    return challenge;
  }
}

class _FakeLeaderboardRepository implements LeaderboardRepository {
  int submitCalls = 0;
  String? lastSubmittedName;

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(String challengeDate) async =>
      const [];

  @override
  Future<LeaderboardPage> getLeaderboardPage(
    String challengeDate, {
    int limit = LeaderboardRepository.defaultPageSize,
    int offset = 0,
    bool includeMyRank = true,
  }) async =>
      const LeaderboardPage(entries: []);

  @override
  Future<void> submitScore({
    required String playerName,
    required String challengeDate,
    required int movesCount,
  }) async {
    submitCalls++;
    lastSubmittedName = playerName;
  }
}

class _AlwaysOnlineNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _RecordingHttpClientAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.uri.path;
    if (path.endsWith('/auth/v1/signup')) {
      return ResponseBody.fromString(
        jsonEncode({
          'access_token': 'jwt_anon_token_123',
          'refresh_token': 'refresh_tok_456',
          'expires_in': 3600,
          'user': {'id': 'user-uuid-999'},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (path.endsWith('/rest/v1/rpc/submit_daily_score')) {
      return ResponseBody.fromString(
        jsonEncode({'id': 'score-1'}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (path.endsWith('/rest/v1/device_profiles')) {
      return ResponseBody.fromString(
        jsonEncode([]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('[]', 200);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Production Readiness Fixes Verification', () {
    const sampleLevel = Level(
      id: 42,
      difficulty: Difficulty.easy,
      optimalMoves: 2,
      boardString: 'oooooo'
          'oooBoo'
          'AAoBoo'
          'oooooo'
          'oooooo'
          'oooooo',
      isUnlocked: true,
    );

    test('GameCubit serializes concurrent drags without losing moves', () async {
      final cubit = GameCubit(
        level: sampleLevel,
        audioService: AudioService(enablePlatformAudio: false),
      );

      // Concurrent drag of B out of the way and A to the exit
      await Future.wait([
        cubit.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0),
        cubit.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 4.0),
      ]);

      expect(cubit.state.boardState.moveCount, 2);
      expect(cubit.state.boardState.getVehicleById('B')!.row, 3);
      expect(cubit.state.boardState.getVehicleById('A')!.col, 4);
      expect(cubit.state.isWon, isTrue);

      await cubit.close();
    });

    test('GameCubit persists and restores Undo moveHistory across process death', () async {
      final localDb = InMemoryLocalDatabaseDataSource();
      final levelRepo = LevelRepositoryImpl(
        assetDataSource: LevelAssetDataSource(),
        localDataSource: localDb,
      );
      final saveProgress = SaveProgress(levelRepo);

      final cubit1 = GameCubit(
        level: sampleLevel,
        audioService: AudioService(enablePlatformAudio: false),
        saveProgressUseCase: saveProgress,
      );

      await cubit1.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0);
      expect(cubit1.state.boardState.moveCount, 1);
      expect(cubit1.state.canUndo, isTrue);
      await cubit1.close();

      // Simulate fresh process / cubit re-creation restoring from LevelRepository
      final cubit2 = GameCubit(
        level: sampleLevel,
        audioService: AudioService(enablePlatformAudio: false),
        saveProgressUseCase: saveProgress,
      );
      // Allow async _restoreInProgressState to complete
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit2.state.boardState.moveCount, 1);
      expect(cubit2.state.canUndo, isTrue);

      cubit2.undo();
      expect(cubit2.state.boardState.moveCount, 0);
      expect(cubit2.state.boardState.getVehicleById('B')!.row, 1);

      await cubit2.close();
    });

    test('DailyCubit blocks un-won submission, restores completed status, and blocks duplicate submit on Replay', () async {
      final dailyRepo = _FakeDailyChallengeRepository(
        const DailyChallenge(
          dateKey: '2026-11-16',
          boardString: 'oooooo'
              'oooBoo'
              'AAoBoo'
              'oooooo'
              'oooooo'
              'oooooo',
          optimalMoves: 2,
        ),
      );
      final leaderboardRepo = _FakeLeaderboardRepository();

      final cubit = DailyCubit(
        dailyRepository: dailyRepo,
        submitScoreUseCase: SubmitScore(leaderboardRepo),
        audioService: AudioService(enablePlatformAudio: false),
        initialDateKey: '2026-11-16',
      );
      await cubit.loadDailyChallenge();

      // Cannot submit before winning
      expect(await cubit.submitPlayerScore('PlayerOne'), isFalse);
      expect(leaderboardRepo.submitCalls, 0);

      // Solve concurrently (also tests DailyCubit drag serialization)
      await Future.wait([
        cubit.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0),
        cubit.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 4.0),
      ]);
      expect(cubit.state.isWon, isTrue);
      expect(dailyRepo.saveCompletionCalls, 1);

      // Submit succeeds once
      expect(await cubit.submitPlayerScore('PlayerOne'), isTrue);
      expect(leaderboardRepo.submitCalls, 1);
      expect(cubit.state.scoreSubmitted, isTrue);

      // Duplicate submit is blocked
      expect(await cubit.submitPlayerScore('PlayerOne'), isFalse);
      expect(leaderboardRepo.submitCalls, 1);

      // Replay keeps scoreSubmitted == true and blocks re-submission
      cubit.reset();
      expect(cubit.state.isWon, isFalse);
      expect(cubit.state.scoreSubmitted, isTrue);
      await cubit.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0);
      await cubit.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 4.0);
      expect(await cubit.submitPlayerScore('PlayerOne'), isFalse);
      expect(leaderboardRepo.submitCalls, 1);

      // Re-opening Daily screen restores completed & submitted state
      await cubit.loadDailyChallenge();
      expect(cubit.state.isWon, isTrue);
      expect(cubit.state.scoreSubmitted, isTrue);

      await cubit.close();
    });

    test('SupabaseRemoteDataSource uses Anonymous Auth + submit_daily_score RPC with verified p_moves and user_id scoping', () async {
      final adapter = _RecordingHttpClientAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final remote = SupabaseRemoteDataSource(
        dio: dio,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon_public_key',
      );

      await remote.submitVerifiedScore(
        playerName: 'MinhAnh',
        challengeDate: '2026-11-16',
        moveHistory: const [
          Move(vehicleId: 'B', fromRow: 1, fromCol: 3, toRow: 3, toCol: 3),
          Move(vehicleId: 'A', fromRow: 2, fromCol: 0, toRow: 2, toCol: 4),
        ],
      );
      await remote.fetchUserDailySubmission('2026-11-16');

      expect(adapter.requests.length, 3);
      expect(adapter.requests[0].uri.path, '/auth/v1/signup');
      expect(adapter.requests[1].uri.path, '/rest/v1/rpc/submit_daily_score');
      expect(
        adapter.requests[1].headers['Authorization'],
        'Bearer jwt_anon_token_123',
      );
      expect(adapter.requests[1].data, {
        'p_player_name': 'MinhAnh',
        'p_challenge_date': '2026-11-16',
        'p_moves': [
          {'vehicle_id': 'B', 'steps': 2, 'axis': 'v'},
          {'vehicle_id': 'A', 'steps': 4, 'axis': 'h'},
        ],
      });
      // Second authenticated call reuses cached session without re-calling /signup
      expect(adapter.requests[2].uri.path, '/rest/v1/leaderboard_scores');
      expect(
        adapter.requests[2].queryParameters['user_id'],
        'eq.user-uuid-999',
      );
      expect(_AlwaysOnlineNetworkInfo().isConnected, completion(isTrue));
    });

    test('DailyChallengeRepositoryImpl.verifySolutionReplay rejects invalid move histories', () {
      const board = 'oooooo'
          'oooBoo'
          'AAoBoo'
          'oooooo'
          'oooooo'
          'oooooo';
      expect(
        () => DailyChallengeRepositoryImpl.verifySolutionReplay(
          initialBoardString: board,
          moveHistory: const [],
        ),
        throwsException,
      );
    });

    test('ErrorReportingService scrubs bearer tokens and device identifiers', () {
      const raw =
          'DioException Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.abc.xyz for dev_12345678-1234-4000-8000-123456789012';
      final scrubbed = ErrorReportingService.scrubSensitiveData(raw);
      expect(scrubbed.contains('eyJhbGci'), isFalse);
      expect(scrubbed.contains('dev_12345678'), isFalse);
      expect(scrubbed, contains('Bearer [REDACTED]'));
      expect(scrubbed, contains('[DEVICE_ID]'));
    });
  });
}

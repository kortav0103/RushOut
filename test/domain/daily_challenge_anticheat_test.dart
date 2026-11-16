import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/error/exceptions.dart';
import 'package:rush_out/core/network/network_info.dart';
import 'package:rush_out/core/services/audio_service.dart';
import 'package:rush_out/core/utils/level_parser.dart';
import 'package:rush_out/data/datasources/local_database_datasource.dart';
import 'package:rush_out/data/datasources/supabase_remote_datasource.dart';
import 'package:rush_out/data/models/daily_challenge_model.dart';
import 'package:rush_out/data/repositories/daily_challenge_repository_impl.dart';
import 'package:rush_out/data/repositories/leaderboard_repository_impl.dart';
import 'package:rush_out/domain/entities/leaderboard_entry.dart';
import 'package:rush_out/domain/entities/move.dart';
import 'package:rush_out/domain/repositories/leaderboard_repository.dart';
import 'package:rush_out/domain/solver/bfs_solver.dart';
import 'package:rush_out/domain/usecases/get_leaderboard.dart';
import 'package:rush_out/domain/usecases/submit_score.dart';
import 'package:rush_out/presentation/bloc/daily_cubit.dart';
import 'package:rush_out/presentation/screens/daily_screen.dart';
import 'package:rush_out/presentation/screens/leaderboard_screen.dart';
import 'package:rush_out/presentation/widgets/daily_win_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../helpers/in_memory_local_database_datasource.dart';

class _InMemoryTokenStore implements SecureTokenStore {
  final Map<String, String> _store = {};

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async => _store[key] = value;
}

class _MutableNetworkInfo implements NetworkInfo {
  bool online;
  _MutableNetworkInfo({this.online = true});

  @override
  Future<bool> get isConnected async => online;
}

class _DailyBackendFakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  String challengeDate;
  String boardString;
  int optimalMoves;
  List<Map<String, dynamic>> serverLeaderboardRows;

  _DailyBackendFakeAdapter({
    required this.challengeDate,
    required this.boardString,
    required this.optimalMoves,
    List<Map<String, dynamic>>? initialLeaderboardRows,
  }) : serverLeaderboardRows = initialLeaderboardRows ?? [];

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
      return _jsonResponse({
        'access_token': 'jwt_daily_123',
        'refresh_token': 'ref_daily_456',
        'expires_in': 3600,
        'user': {
          'id': 'user-daily-001',
          'is_anonymous': true,
        },
      });
    }

    if (path.endsWith('/rest/v1/daily_challenges')) {
      final dateFilter = options.queryParameters['challenge_date']?.toString();
      if (dateFilter == 'eq.$challengeDate') {
        return _jsonResponse([
          {
            'challenge_date': challengeDate,
            'board_string': boardString,
            'optimal_moves': optimalMoves,
          },
        ]);
      }
      return _jsonResponse([]);
    }

    if (path.endsWith('/rest/v1/leaderboard_scores')) {
      final userFilter = options.queryParameters['user_id']?.toString();
      final dateFilter = options.queryParameters['challenge_date']?.toString();
      final filtered = serverLeaderboardRows.where((row) {
        if (dateFilter != null && 'eq.${row['challenge_date']}' != dateFilter) {
          return false;
        }
        if (userFilter != null && 'eq.${row['user_id']}' != userFilter) {
          return false;
        }
        return true;
      }).toList();
      return _jsonResponse(filtered);
    }

    if (path.endsWith('/rest/v1/rpc/submit_daily_score')) {
      final body = options.data as Map<String, dynamic>;
      final rawMoves = body['p_moves'];
      if (rawMoves is! List || rawMoves.isEmpty) {
        return _jsonResponse(
          {'message': 'Move history must be a non-empty array.'},
          statusCode: 400,
        );
      }

      // Mirror server PL/pgSQL move verifier
      final parsedMoves = <Move>[];
      var board = LevelParser.parseToBoardState(
        boardString,
        optimalMoves: optimalMoves,
      );
      for (final item in rawMoves.whereType<Map<String, dynamic>>()) {
        final vid = item['vehicle_id'] as String?;
        final steps = (item['steps'] as num?)?.toInt();
        final v = vid != null ? board.getVehicleById(vid) : null;
        if (v == null || steps == null || steps == 0) {
          return _jsonResponse(
            {'message': 'Invalid move in p_moves.'},
            statusCode: 400,
          );
        }
        final move = Move(
          vehicleId: vid!,
          fromRow: v.row,
          fromCol: v.col,
          toRow: v.isHorizontal ? v.row : v.row + steps,
          toCol: v.isHorizontal ? v.col + steps : v.col,
        );
        parsedMoves.add(move);
        try {
          board = DailyChallengeRepositoryImpl.verifySolutionReplay(
            initialBoardString: boardString,
            moveHistory: parsedMoves,
            optimalMoves: 1,
          );
        } on ServerException catch (e) {
          // Only intermediate step validation if not won yet; verify step itself
          if (e.message.contains('did not reach exit')) {
            continue;
          }
          return _jsonResponse({'message': e.message}, statusCode: 400);
        }
      }

      try {
        final verified = DailyChallengeRepositoryImpl.verifySolutionReplay(
          initialBoardString: boardString,
          moveHistory: parsedMoves,
          optimalMoves: optimalMoves,
        );
        final row = {
          'id': 'score-${serverLeaderboardRows.length + 1}',
          'user_id': 'user-daily-001',
          'player_name': body['p_player_name'],
          'challenge_date': body['p_challenge_date'],
          'moves_count': verified.moveCount,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
        serverLeaderboardRows.add(row);
        return _jsonResponse(row);
      } on ServerException catch (e) {
        return _jsonResponse({'message': e.message}, statusCode: 400);
      }
    }

    return _jsonResponse([]);
  }

  ResponseBody _jsonResponse(Object data, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _StubLeaderboardRepo implements LeaderboardRepository {
  @override
  Future<List<LeaderboardEntry>> getLeaderboard(String challengeDate) async =>
      const [];

  @override
  Future<void> submitScore({
    required String playerName,
    required String challengeDate,
    required int movesCount,
  }) async {}
}

class _FakeWidgetRemoteDataSource extends SupabaseRemoteDataSource {
  final String challengeDate;
  final String boardString;
  final int optimalMoves;
  UserDailySubmission? userSubmission;

  _FakeWidgetRemoteDataSource({
    required this.challengeDate,
    required this.boardString,
    required this.optimalMoves,
    this.userSubmission,
  });

  @override
  bool get isConfigured => true;

  @override
  Future<DailyChallengeModel?> fetchDailyChallenge(String dateKey) async {
    if (dateKey != challengeDate) return null;
    return DailyChallengeModel(
      dateKey: challengeDate,
      boardString: boardString,
      optimalMoves: optimalMoves,
    );
  }

  @override
  Future<UserDailySubmission?> fetchUserDailySubmission(String dateKey) async {
    return dateKey == challengeDate ? userSubmission : null;
  }

  @override
  Future<void> submitVerifiedScore({
    required String playerName,
    required String challengeDate,
    required List<Move> moveHistory,
  }) async {
    userSubmission = UserDailySubmission(
      playerName: playerName,
      movesCount: moveHistory.length,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleBoard = 'oooooo'
      'oooBoo'
      'AAoBoo'
      'oooooo'
      'oooooo'
      'oooooo';
  const todayKey = '2026-11-16';

  group('DailyChallengeModel & Schema Verification', () {
    test('DailyChallengeModel rejects missing or invalid optimal_moves (no ?? 10 fallback)', () {
      expect(
        () => DailyChallengeModel.fromSupabaseJson(const {
          'challenge_date': todayKey,
          'board_string': sampleBoard,
        }),
        throwsA(isA<ServerException>()),
      );
      expect(
        () => DailyChallengeModel.fromSupabaseJson(const {
          'challenge_date': todayKey,
          'board_string': sampleBoard,
          'optimal_moves': 0,
        }),
        throwsA(isA<ServerException>()),
      );
      expect(
        () => DailyChallengeModel.fromSupabaseJson(const {
          'challenge_date': todayKey,
          'board_string': 'oooooooooooooooooooooooooooooooooooo',
          'optimal_moves': 5,
        }),
        throwsA(isA<ServerException>()),
      );
      expect(
        () => DailyChallengeModel.fromCacheMap(const {
          'date_key': todayKey,
          'board_string': sampleBoard,
        }),
        throwsA(isA<CacheException>()),
      );
    });

    test('supabase/schema.sql removes fake leaderboard rows, uses verified p_moves RPC, and all 36 daily_puzzle_pool boards solve at exact optimal_moves', () {
      final schemaText = File('supabase/schema.sql').readAsStringSync();

      // Zero fake leaderboard entries
      expect(schemaText.contains('SpeedRacer_VN'), isFalse);
      expect(schemaText.contains('PuzzleMaster'), isFalse);
      expect(schemaText.contains('RushHourPro'), isFalse);

      // Uses long-term puzzle pool + scheduler and verified p_moves JSONB RPC
      expect(schemaText.contains('CREATE TABLE IF NOT EXISTS public.daily_puzzle_pool'), isTrue);
      expect(schemaText.contains('schedule_daily_challenges'), isTrue);
      expect(schemaText.contains('DROP FUNCTION IF EXISTS public.submit_daily_score(TEXT, DATE, INTEGER);'), isTrue);
      expect(schemaText.contains('p_moves JSONB'), isTrue);

      // Extract every ('board', optimal, 'difficulty') tuple in daily_puzzle_pool
      final tupleRegex = RegExp(
        r"\('([A-Za-z]{36})',\s*(\d+),\s*'(easy|medium|hard)'\)",
      );
      final matches = tupleRegex.allMatches(schemaText).toList();
      expect(matches.length, greaterThanOrEqualTo(36));

      for (final m in matches) {
        final boardStr = m.group(1)!;
        final expectedOptimal = int.parse(m.group(2)!);
        final board = LevelParser.parseToBoardState(
          boardStr,
          optimalMoves: expectedOptimal,
        );
        final solution = BfsSolver.solve(board, maxVisitedStates: 200000);
        expect(
          solution,
          isNotNull,
          reason: 'Pool board $boardStr must be solvable',
        );
        expect(
          solution!.length,
          expectedOptimal,
          reason:
              'Pool board $boardStr optimal_moves ($expectedOptimal) must match BFS shortest path (${solution.length})',
        );
      }
    });
  });

  group('Anti-Cheat Replay Verifier & Local Persistence', () {
    test('verifySolutionReplay accepts valid moves and rejects empty, incomplete, colliding, out-of-bounds, and wrong-axis moves', () {
      // Valid 2-move solution
      final solved = DailyChallengeRepositoryImpl.verifySolutionReplay(
        initialBoardString: sampleBoard,
        optimalMoves: 2,
        moveHistory: const [
          Move(vehicleId: 'B', fromRow: 1, fromCol: 3, toRow: 3, toCol: 3),
          Move(vehicleId: 'A', fromRow: 2, fromCol: 0, toRow: 2, toCol: 4),
        ],
      );
      expect(solved.isWon, isTrue);
      expect(solved.moveCount, 2);

      // Empty move history
      expect(
        () => DailyChallengeRepositoryImpl.verifySolutionReplay(
          initialBoardString: sampleBoard,
          moveHistory: const [],
        ),
        throwsA(isA<ServerException>()),
      );

      // Incomplete (A did not reach col 4)
      expect(
        () => DailyChallengeRepositoryImpl.verifySolutionReplay(
          initialBoardString: sampleBoard,
          moveHistory: const [
            Move(vehicleId: 'B', fromRow: 1, fromCol: 3, toRow: 3, toCol: 3),
            Move(vehicleId: 'A', fromRow: 2, fromCol: 0, toRow: 2, toCol: 3),
          ],
        ),
        throwsA(isA<ServerException>()),
      );

      // Collision / jumping through B without moving B first
      expect(
        () => DailyChallengeRepositoryImpl.verifySolutionReplay(
          initialBoardString: sampleBoard,
          moveHistory: const [
            Move(vehicleId: 'A', fromRow: 2, fromCol: 0, toRow: 2, toCol: 4),
          ],
        ),
        throwsA(isA<ServerException>()),
      );

      // Wrong axis (horizontal A moving vertically)
      expect(
        () => DailyChallengeRepositoryImpl.verifySolutionReplay(
          initialBoardString: sampleBoard,
          moveHistory: const [
            Move(vehicleId: 'A', fromRow: 2, fromCol: 0, toRow: 1, toCol: 0),
          ],
        ),
        throwsA(isA<ServerException>()),
      );

      // Out of bounds 0..5 (col = 5 for length 2 vehicle)
      expect(
        () => DailyChallengeRepositoryImpl.verifySolutionReplay(
          initialBoardString: sampleBoard,
          moveHistory: const [
            Move(vehicleId: 'B', fromRow: 1, fromCol: 3, toRow: 3, toCol: 3),
            Move(vehicleId: 'A', fromRow: 2, fromCol: 0, toRow: 2, toCol: 5),
          ],
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('LocalDatabaseDataSource persists solved_board_string and best_move_history on disk via sqflite_common_ffi', () async {
      sqfliteFfiInit();
      final tempDir = await Directory.systemTemp.createTemp('rushout_daily_db_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      Future<Database> openFfiDb(
        String path, {
        int? version,
        OnDatabaseCreateFn? onCreate,
        OnDatabaseVersionChangeFn? onUpgrade,
      }) {
        return databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: version,
            onCreate: onCreate,
            onUpgrade: onUpgrade,
          ),
        );
      }

      final db1 = LocalDatabaseDataSource(
        getDatabasesPathFn: () async => tempDir.path,
        openDatabaseFn: openFfiDb,
        dbFileName: 'daily_test.db',
      );
      await db1.saveDailyChallengeCache(
        const DailyChallengeModel(
          dateKey: todayKey,
          boardString: sampleBoard,
          optimalMoves: 2,
          isCompleted: true,
          userMoves: 2,
          solvedBoardString: 'oooooo'
              'oooooo'
              'ooooAA'
              'oooBoo'
              'oooBoo'
              'oooooo',
          bestMoveHistory: [
            Move(vehicleId: 'B', fromRow: 1, fromCol: 3, toRow: 3, toCol: 3),
            Move(vehicleId: 'A', fromRow: 2, fromCol: 0, toRow: 2, toCol: 4),
          ],
          scoreSubmitted: true,
          submittedMoves: 2,
          submittedPlayerName: 'DriverPro',
        ),
      );
      await db1.close();

      final db2 = LocalDatabaseDataSource(
        getDatabasesPathFn: () async => tempDir.path,
        openDatabaseFn: openFfiDb,
        dbFileName: 'daily_test.db',
      );
      final restored = await db2.getCachedDailyChallenge(todayKey);
      await db2.close();

      expect(restored, isNotNull);
      expect(restored!.isCompleted, isTrue);
      expect(restored.userMoves, 2);
      expect(restored.solvedBoardString, isNotNull);
      expect(restored.bestMoveHistory.length, 2);
      expect(restored.scoreSubmitted, isTrue);
      expect(restored.submittedMoves, 2);
      expect(restored.submittedPlayerName, 'DriverPro');
    });

    test('DailyChallengeRepositoryImpl syncs server submission status by auth.uid() + challenge_date even after local cache clear', () async {
      final tokenStore = _InMemoryTokenStore();
      final adapter = _DailyBackendFakeAdapter(
        challengeDate: todayKey,
        boardString: sampleBoard,
        optimalMoves: 2,
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final remote = SupabaseRemoteDataSource(
        dio: dio,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon_key',
        tokenStore: tokenStore,
      );

      // Device 1 authenticates and submits score
      final localDb1 = InMemoryLocalDatabaseDataSource();
      final repo1 = DailyChallengeRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: localDb1,
        networkInfo: _MutableNetworkInfo(online: true),
      );

      await repo1.getDailyChallenge(todayKey);
      await repo1.submitVerifiedScore(
        playerName: 'CloudRacer',
        challengeDate: todayKey,
        moveHistory: const [
          Move(vehicleId: 'B', fromRow: 1, fromCol: 3, toRow: 3, toCol: 3),
          Move(vehicleId: 'A', fromRow: 2, fromCol: 0, toRow: 2, toCol: 4),
        ],
      );

      // Simulate cleared local SQLite cache (same auth session in secure storage)
      final clearedLocalDb = InMemoryLocalDatabaseDataSource();
      final repo2 = DailyChallengeRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: clearedLocalDb,
        networkInfo: _MutableNetworkInfo(online: true),
      );

      final synced = await repo2.getDailyChallenge(todayKey);
      expect(synced.scoreSubmitted, isTrue);
      expect(synced.isCompleted, isTrue);
      expect(synced.submittedMoves, 2);
      expect(synced.submittedPlayerName, 'CloudRacer');
      expect(synced.userMoves, 2);
    });
  });

  group('DailyCubit Best-Score Preservation, Reopen Solved Board & Validation', () {
    test('Reopening completed Daily restores actual solved board (not starting board with A hidden) and Replay worse score still submits best score', () async {
      final localDb = InMemoryLocalDatabaseDataSource();
      final adapter = _DailyBackendFakeAdapter(
        challengeDate: todayKey,
        boardString: sampleBoard,
        optimalMoves: 2,
      );
      final remote = SupabaseRemoteDataSource(
        dio: Dio()..httpClientAdapter = adapter,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon_key',
        tokenStore: _InMemoryTokenStore(),
      );
      final dailyRepo = DailyChallengeRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: localDb,
        networkInfo: _MutableNetworkInfo(online: true),
      );
      final leaderboardRepo = LeaderboardRepositoryImpl(
        remoteDataSource: remote,
        networkInfo: _MutableNetworkInfo(online: true),
      );
      final audio = AudioService(enablePlatformAudio: false);

      // 1. Play and win in optimal 2 moves
      final cubit1 = DailyCubit(
        dailyRepository: dailyRepo,
        submitScoreUseCase: SubmitScore(leaderboardRepo),
        audioService: audio,
        initialDateKey: todayKey,
      );
      await cubit1.loadDailyChallenge();
      await cubit1.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0);
      await cubit1.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 4.0);

      expect(cubit1.state.isWon, isTrue);
      expect(cubit1.state.bestMoves, 2);
      expect(cubit1.state.hasSolvedBoardSnapshot, isTrue);
      await cubit1.close();

      // 2. Reopen DailyCubit -> must restore SOLVED board (B at row 3, A at col 4)
      final cubit2 = DailyCubit(
        dailyRepository: dailyRepo,
        submitScoreUseCase: SubmitScore(leaderboardRepo),
        audioService: audio,
        initialDateKey: todayKey,
      );
      await cubit2.loadDailyChallenge();

      expect(cubit2.state.isWon, isTrue);
      expect(cubit2.state.isReviewMode, isTrue);
      expect(cubit2.state.hasSolvedBoardSnapshot, isTrue);
      expect(cubit2.state.boardState!.isWon, isTrue);
      expect(cubit2.state.boardState!.getVehicleById('B')!.row, 3);
      expect(cubit2.state.boardState!.getVehicleById('A')!.col, 4);
      expect(cubit2.state.bestMoves, 2);

      // 3. Empty nickname shows explicit validation error (does NOT silently return)
      final emptySubmit = await cubit2.submitPlayerScore('   ');
      expect(emptySubmit, isFalse);
      expect(cubit2.state.submitErrorMessage, isNotNull);
      expect(cubit2.state.submitErrorMessage, contains('nickname'));

      // 4. Tap Replay (reset) and solve WORSE in 4 moves!
      cubit2.reset();
      expect(cubit2.state.isWon, isFalse);
      expect(cubit2.state.bestMoves, 2);

      await cubit2.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0);
      await cubit2.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 1.0);
      await cubit2.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 2.0);
      await cubit2.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 4.0);

      expect(cubit2.state.isWon, isTrue);
      expect(cubit2.state.boardState!.moveCount, 4);
      // Best score must stay 2!
      expect(cubit2.state.bestMoves, 2);
      expect(cubit2.state.challenge!.userMoves, 2);
      expect(cubit2.state.challenge!.bestMoveHistory.length, 2);

      // 5. Submit score -> MUST submit the 2-move bestMoveHistory, NOT the 4-move replay!
      final submitted = await cubit2.submitPlayerScore('BestKeeper');
      expect(submitted, isTrue);
      expect(cubit2.state.scoreSubmitted, isTrue);
      expect(cubit2.state.submittedMoves, 2);
      expect(adapter.serverLeaderboardRows.length, 1);
      expect(adapter.serverLeaderboardRows.first['moves_count'], 2);

      await cubit2.close();
    });
  });

  group('DailyScreen & DailyWinDialog Widget Tests', () {
    Future<void> pumpFrames(
      WidgetTester tester, {
      int count = 12,
      Duration step = const Duration(milliseconds: 50),
    }) async {
      for (int i = 0; i < count; i++) {
        await tester.pump(step);
      }
    }

    testWidgets(
      'Reopening solved DailyScreen shows Review banner with Replay & Submit, and empty submit shows clear validation error in DailyWinDialog',
      (tester) async {
      final localDb = InMemoryLocalDatabaseDataSource();
      final remote = _FakeWidgetRemoteDataSource(
        challengeDate: todayKey,
        boardString: sampleBoard,
        optimalMoves: 2,
      );
      final dailyRepo = DailyChallengeRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: localDb,
        networkInfo: _MutableNetworkInfo(online: true),
      );

      // Pre-save a verified completion
      await dailyRepo.getDailyChallenge(todayKey);
      await dailyRepo.saveVerifiedCompletion(
        dateKey: todayKey,
        userMoves: 2,
        solvedBoardString: 'oooooo'
            'oooooo'
            'ooooAA'
            'oooBoo'
            'oooBoo'
            'oooooo',
        moveHistory: const [
          Move(vehicleId: 'B', fromRow: 1, fromCol: 3, toRow: 3, toCol: 3),
          Move(vehicleId: 'A', fromRow: 2, fromCol: 0, toRow: 2, toCol: 4),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DailyScreen(
            dailyRepository: dailyRepo,
            submitScoreUseCase: SubmitScore(_StubLeaderboardRepo()),
            getLeaderboardUseCase: GetLeaderboard(_StubLeaderboardRepo()),
            audioService: AudioService(enablePlatformAudio: false),
            initialDateKey: todayKey,
          ),
        ),
      );
      await pumpFrames(tester);

      // Review banner + Replay + Submit visible immediately
      expect(find.textContaining('Completed • Best: 2 moves'), findsOneWidget);
      expect(find.text('Replay'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);

      // Open DailyWinDialog via Submit button
      await tester.tap(find.text('Submit'));
      await pumpFrames(tester);

      expect(find.byType(DailyWinDialog), findsOneWidget);

      // Submit with empty nickname -> clear validation error shown
      await tester.tap(find.text('Submit Score (2 moves)'));
      await pumpFrames(tester);
      expect(
        find.text('Please enter a nickname before submitting your score.'),
        findsOneWidget,
      );

      // Navigate independently to LeaderboardScreen from DailyWinDialog
      await tester.tap(find.text('Leaderboard'));
      await pumpFrames(tester);
      expect(find.byType(LeaderboardScreen), findsOneWidget);
    });

    testWidgets('Server-synced completion without local solved snapshot shows Summary card with Replay Puzzle instead of broken board', (tester) async {
      final remote = _FakeWidgetRemoteDataSource(
        challengeDate: todayKey,
        boardString: sampleBoard,
        optimalMoves: 2,
        userSubmission: const UserDailySubmission(
          playerName: 'RemotePlayer',
          movesCount: 2,
        ),
      );

      final dailyRepo = DailyChallengeRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: InMemoryLocalDatabaseDataSource(),
        networkInfo: _MutableNetworkInfo(online: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DailyScreen(
            dailyRepository: dailyRepo,
            submitScoreUseCase: SubmitScore(_StubLeaderboardRepo()),
            getLeaderboardUseCase: GetLeaderboard(_StubLeaderboardRepo()),
            audioService: AudioService(enablePlatformAudio: false),
            initialDateKey: todayKey,
          ),
        ),
      );
      await pumpFrames(tester);

      expect(find.text('DAILY CHALLENGE COMPLETED'), findsOneWidget);
      expect(find.text('Submitted score: 2 moves'), findsOneWidget);
      expect(find.text('Replay Puzzle'), findsOneWidget);

      // Tapping Replay Puzzle transitions into playable board
      await tester.tap(find.text('Replay Puzzle'));
      await pumpFrames(tester);
      expect(find.textContaining('Replaying • Best today: 2 moves'), findsOneWidget);
    });
  });
}

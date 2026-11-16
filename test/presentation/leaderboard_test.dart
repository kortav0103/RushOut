import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/error/exceptions.dart';
import 'package:rush_out/core/network/network_info.dart';
import 'package:rush_out/data/datasources/supabase_remote_datasource.dart';
import 'package:rush_out/data/models/score_model.dart';
import 'package:rush_out/data/repositories/leaderboard_repository_impl.dart';
import 'package:rush_out/domain/entities/leaderboard_entry.dart';
import 'package:rush_out/domain/repositories/leaderboard_repository.dart';
import 'package:rush_out/domain/usecases/get_leaderboard.dart';
import 'package:rush_out/presentation/bloc/daily_cubit.dart';
import 'package:rush_out/presentation/bloc/leaderboard_cubit.dart';
import 'package:rush_out/presentation/screens/leaderboard_screen.dart';

class _ConfigurableLeaderboardRepository implements LeaderboardRepository {
  Future<List<LeaderboardEntry>> Function(String challengeDate)? onGetLeaderboard;
  Future<LeaderboardPage> Function(
    String challengeDate, {
    int limit,
    int offset,
    bool includeMyRank,
  })? onGetPage;

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(String challengeDate) async {
    if (onGetLeaderboard != null) {
      return onGetLeaderboard!(challengeDate);
    }
    return const [];
  }

  @override
  Future<LeaderboardPage> getLeaderboardPage(
    String challengeDate, {
    int limit = LeaderboardRepository.defaultPageSize,
    int offset = 0,
    bool includeMyRank = true,
  }) async {
    if (onGetPage != null) {
      return onGetPage!(
        challengeDate,
        limit: limit,
        offset: offset,
        includeMyRank: includeMyRank,
      );
    }
    final entries = await getLeaderboard(challengeDate);
    return LeaderboardPage(entries: entries);
  }

  @override
  Future<void> submitScore({
    required String playerName,
    required String challengeDate,
    required int movesCount,
  }) async {}
}

class _InMemoryTokenStore implements SecureTokenStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

class _StaticNetworkInfo implements NetworkInfo {
  final bool connected;
  const _StaticNetworkInfo(this.connected);

  @override
  Future<bool> get isConnected async => connected;
}

class _MockHttpAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  _MockHttpAdapter(this.handler);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }
}

ResponseBody _jsonResponse(
  Object body, {
  int statusCode = 200,
  Map<String, List<String>> extraHeaders = const {},
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...extraHeaders,
    },
  );
}

void main() {
  group('ScoreModel strict parsing (Mục 2.7)', () {
    test('rejects missing or whitespace-only player_name instead of returning Anonymous', () {
      expect(
        () => ScoreModel.fromJson(const {
          'challenge_date': '2026-11-16',
          'moves_count': 12,
        }),
        throwsA(isA<ServerException>()),
      );
      expect(
        () => ScoreModel.fromJson(const {
          'player_name': '   ',
          'challenge_date': '2026-11-16',
          'moves_count': 12,
        }),
        throwsA(isA<ServerException>()),
      );
    });

    test('rejects moves_count <= 0, non-integer, or invalid challenge_date', () {
      expect(
        () => ScoreModel.fromJson(const {
          'player_name': 'DriverOne',
          'challenge_date': '2026-11-16',
          'moves_count': 0,
        }),
        throwsA(isA<ServerException>()),
      );
      expect(
        () => ScoreModel.fromJson(const {
          'player_name': 'DriverOne',
          'challenge_date': '2026-11-16',
          'moves_count': -4,
        }),
        throwsA(isA<ServerException>()),
      );
      expect(
        () => ScoreModel.fromJson(const {
          'player_name': 'DriverOne',
          'challenge_date': '2026-11-16',
          'moves_count': 12.5,
        }),
        throwsA(isA<ServerException>()),
      );
      expect(
        () => ScoreModel.fromJson(const {
          'player_name': 'DriverOne',
          'challenge_date': '2026-02-30',
          'moves_count': 8,
        }),
        throwsA(isA<ServerException>()),
      );
      expect(
        () => ScoreModel.fromJson(const {
          'player_name': 'DriverOne',
          'challenge_date': 'not-a-date',
          'moves_count': 8,
        }),
        throwsA(isA<ServerException>()),
      );
    });

    test('parses valid API payload and trims player_name', () {
      final model = ScoreModel.fromJson(const {
        'id': 'row-1',
        'user_id': 'user-99',
        'player_name': '  AceDriver  ',
        'challenge_date': '2026-11-16',
        'moves_count': 9,
        'created_at': '2026-11-16T08:30:00Z',
      });

      expect(model.id, 'row-1');
      expect(model.userId, 'user-99');
      expect(model.playerName, 'AceDriver');
      expect(model.challengeDate, '2026-11-16');
      expect(model.movesCount, 9);
      expect(model.createdAt, DateTime.utc(2026, 11, 16, 8, 30));
    });
  });

  group('SupabaseRemoteDataSource & LeaderboardRepositoryImpl (Mục 2.7)', () {
    test('fetchLeaderboard forwards pagination params and rejects corrupt server records', () async {
      final adapter = _MockHttpAdapter((options) {
        if (options.queryParameters['offset'] == '20') {
          return _jsonResponse([
            {
              'id': 'r-21',
              'user_id': 'u-21',
              'player_name': 'PageTwoPlayer',
              'challenge_date': '2026-11-16',
              'moves_count': 15,
            },
          ]);
        }
        return _jsonResponse([
          {
            'id': 'bad',
            'player_name': '',
            'challenge_date': '2026-11-16',
            'moves_count': 10,
          },
        ]);
      });

      final dio = Dio()..httpClientAdapter = adapter;
      final ds = SupabaseRemoteDataSource(
        dio: dio,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key-test',
        tokenStore: _InMemoryTokenStore(),
      );

      final page2 = await ds.fetchLeaderboard('2026-11-16', limit: 20, offset: 20);
      expect(page2, hasLength(1));
      expect(page2.first.playerName, 'PageTwoPlayer');

      await expectLater(
        () => ds.fetchLeaderboard('2026-11-16', limit: 20, offset: 0),
        throwsA(isA<ServerException>()),
      );
    });

    test('fetchPlayerLeaderboardRank computes exact rank outside Top 20 and returns null without session', () async {
      final tokenStore = _InMemoryTokenStore();
      final adapter = _MockHttpAdapter((options) {
        if (options.queryParameters['user_id'] == 'eq.user-25') {
          return _jsonResponse([
            {
              'id': 'row-25',
              'user_id': 'user-25',
              'player_name': 'MeOutsideTop20',
              'challenge_date': '2026-11-16',
              'moves_count': 24,
              'created_at': '2026-11-16T05:00:00Z',
            },
          ]);
        }
        if (options.headers['Prefer'] == 'count=exact') {
          return _jsonResponse(
            [
              {'id': 'row-1'},
            ],
            extraHeaders: {
              'content-range': ['0-0/24'],
            },
          );
        }
        return _jsonResponse([]);
      });

      final dio = Dio()..httpClientAdapter = adapter;
      final dsNoSession = SupabaseRemoteDataSource(
        dio: dio,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key-test',
        tokenStore: _InMemoryTokenStore(),
      );
      expect(await dsNoSession.fetchPlayerLeaderboardRank('2026-11-16'), isNull);

      await tokenStore.write(
        'rush_out_sb_session_v2',
        jsonEncode(
          SupabaseSession(
            accessToken: 'jwt-abc',
            refreshToken: 'ref-abc',
            userId: 'user-25',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          ).toJson(),
        ),
      );
      final dsWithSession = SupabaseRemoteDataSource(
        dio: dio,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key-test',
        tokenStore: tokenStore,
      );

      final myRank = await dsWithSession.fetchPlayerLeaderboardRank('2026-11-16');
      expect(myRank, isNotNull);
      expect(myRank!.rank, 25);
      expect(myRank.entry.playerName, 'MeOutsideTop20');
      expect(myRank.entry.movesCount, 24);
    });

    test('LeaderboardRepositoryImpl.getLeaderboardPage sets hasMore accurately via limit+1 and handles offline', () async {
      final tokenStore = _InMemoryTokenStore();
      final adapter = _MockHttpAdapter((options) {
        return _jsonResponse([
          {
            'id': '1',
            'player_name': 'P1',
            'challenge_date': '2026-11-16',
            'moves_count': 7,
          },
          {
            'id': '2',
            'player_name': 'P2',
            'challenge_date': '2026-11-16',
            'moves_count': 8,
          },
          {
            'id': '3',
            'player_name': 'P3',
            'challenge_date': '2026-11-16',
            'moves_count': 9,
          },
        ]);
      });

      final ds = SupabaseRemoteDataSource(
        dio: Dio()..httpClientAdapter = adapter,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key-test',
        tokenStore: tokenStore,
      );

      final onlineRepo = LeaderboardRepositoryImpl(
        remoteDataSource: ds,
        networkInfo: const _StaticNetworkInfo(true),
      );
      final page = await onlineRepo.getLeaderboardPage('2026-11-16', limit: 2);
      expect(page.entries, hasLength(2));
      expect(page.hasMore, isTrue);

      final offlineRepo = LeaderboardRepositoryImpl(
        remoteDataSource: ds,
        networkInfo: const _StaticNetworkInfo(false),
      );
      await expectLater(
        () => offlineRepo.getLeaderboardPage('2026-11-16'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('LeaderboardCubit (Mục 2.7)', () {
    test('sanitizes unexpected non-ServerException errors and never leaks e.toString()', () async {
      final repo = _ConfigurableLeaderboardRepository()
        ..onGetPage = (_, {limit = 20, offset = 0, includeMyRank = true}) async {
          throw const FormatException('RAW_INTERNAL_PARSE_DETAIL_LEAK');
        };
      final cubit = LeaderboardCubit(
        getLeaderboardUseCase: GetLeaderboard(repo),
        initialDate: '2026-11-16',
      );

      await cubit.loadLeaderboard();

      expect(cubit.state.status, LeaderboardViewStatus.error);
      expect(cubit.state.errorMessage, isNotNull);
      expect(
        cubit.state.errorMessage,
        isNot(contains('RAW_INTERNAL_PARSE_DETAIL_LEAK')),
      );
      expect(cubit.state.errorMessage, isNot(contains('FormatException')));
      await cubit.close();
    });

    test('preserves ServerException message and keeps loaded entries if loadMore fails', () async {
      final repo = _ConfigurableLeaderboardRepository()
        ..onGetPage = (date, {limit = 20, offset = 0, includeMyRank = true}) async {
          if (offset == 0) {
            return LeaderboardPage(
              entries: [
                LeaderboardEntry(
                  id: 'r1',
                  playerName: 'First',
                  challengeDate: date,
                  movesCount: 6,
                ),
              ],
              hasMore: true,
            );
          }
          throw StateError('INTERNAL_NEXT_PAGE_TRACE');
        };

      final cubit = LeaderboardCubit(
        getLeaderboardUseCase: GetLeaderboard(repo),
        initialDate: '2026-11-16',
        pageSize: 1,
      );

      await cubit.loadLeaderboard();
      expect(cubit.state.status, LeaderboardViewStatus.content);
      expect(cubit.state.entries, hasLength(1));

      await cubit.loadMore();
      expect(cubit.state.status, LeaderboardViewStatus.content);
      expect(cubit.state.entries, hasLength(1));
      expect(cubit.state.loadMoreErrorMessage, isNotNull);
      expect(
        cubit.state.loadMoreErrorMessage,
        isNot(contains('INTERNAL_NEXT_PAGE_TRACE')),
      );
      await cubit.close();
    });

    test('previousDay and nextDay navigate UTC dates and clamp at today UTC', () async {
      final requestedDates = <String>[];
      final repo = _ConfigurableLeaderboardRepository()
        ..onGetPage = (date, {limit = 20, offset = 0, includeMyRank = true}) async {
          requestedDates.add(date);
          return const LeaderboardPage(entries: []);
        };
      final todayUtc = DailyCubit.formatTodayDateKey();
      final cubit = LeaderboardCubit(
        getLeaderboardUseCase: GetLeaderboard(repo),
        initialDate: todayUtc,
      );

      await cubit.loadLeaderboard();
      expect(cubit.state.canGoNextDay, isFalse);

      // Cannot advance past today UTC
      await cubit.nextDay();
      expect(requestedDates, [todayUtc]);

      await cubit.previousDay();
      expect(requestedDates, hasLength(2));
      expect(cubit.state.canGoNextDay, isTrue);

      await cubit.nextDay();
      expect(cubit.state.challengeDate, todayUtc);
      await cubit.close();
    });
  });

  group('LeaderboardScreen Widget Tests (Mục 2.7)', () {
    testWidgets('displays (UTC) date labels, My Rank card outside Top 20, and Load More pagination highlighting player row', (tester) async {
      final top20 = List.generate(
        20,
        (i) => ScoreModel(
          id: 'row-${i + 1}',
          userId: 'user-${i + 1}',
          playerName: 'Driver_${i + 1}',
          challengeDate: '2026-11-16',
          movesCount: 5 + i,
        ),
      );
      const myEntry = ScoreModel(
        id: 'row-21',
        userId: 'current-user',
        playerName: 'HeroPlayer',
        challengeDate: '2026-11-16',
        movesCount: 25,
      );

      final repo = _ConfigurableLeaderboardRepository()
        ..onGetPage = (date, {limit = 20, offset = 0, includeMyRank = true}) async {
          if (offset == 0) {
            return LeaderboardPage(
              entries: top20,
              myRank: const PlayerLeaderboardRank(rank: 21, entry: myEntry),
              currentUserId: 'current-user',
              hasMore: true,
            );
          }
          return const LeaderboardPage(
            entries: [myEntry],
            hasMore: false,
          );
        };

      await tester.pumpWidget(
        MaterialApp(
          home: LeaderboardScreen(
            getLeaderboardUseCase: GetLeaderboard(repo),
            initialDateKey: '2026-11-16',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear (UTC) labels
      expect(find.textContaining('2026-11-16 (UTC)'), findsWidgets);

      // Dedicated "My Rank" card shown even when player is outside Top 20
      expect(find.byKey(const Key('my_rank_card')), findsOneWidget);
      expect(find.text('My Rank'), findsOneWidget);
      expect(find.text('#21'), findsOneWidget);
      expect(find.text('HeroPlayer'), findsOneWidget);
      expect(find.textContaining('Outside Top 20'), findsOneWidget);
      expect(find.text('YOU'), findsNothing);

      // Scroll to bottom and tap Load More
      await tester.scrollUntilVisible(
        find.text('Load More'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Load More'));
      await tester.pumpAndSettle();

      // Player's row is now loaded in list and highlighted with YOU badge
      await tester.scrollUntilVisible(
        find.text('YOU'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('YOU'), findsOneWidget);
      expect(find.text('Load More'), findsNothing);
    });

    testWidgets('highlights current player row inside Top 20 with YOU badge', (tester) async {
      final repo = _ConfigurableLeaderboardRepository()
        ..onGetPage = (date, {limit = 20, offset = 0, includeMyRank = true}) async {
          const me = ScoreModel(
            id: 'row-2',
            userId: 'user-me',
            playerName: 'FastLane',
            challengeDate: '2026-11-16',
            movesCount: 9,
          );
          return LeaderboardPage(
            entries: [
              ScoreModel(
                id: 'row-1',
                userId: 'user-other',
                playerName: 'PoleSitter',
                challengeDate: date,
                movesCount: 7,
              ),
              me,
            ],
            myRank: const PlayerLeaderboardRank(rank: 2, entry: me),
            currentUserId: 'user-me',
            hasMore: false,
          );
        };

      await tester.pumpWidget(
        MaterialApp(
          home: LeaderboardScreen(
            getLeaderboardUseCase: GetLeaderboard(repo),
            initialDateKey: '2026-11-16',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YOU'), findsOneWidget);
      expect(find.byKey(const Key('my_rank_card')), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });
  });
}

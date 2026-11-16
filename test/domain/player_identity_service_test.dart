import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/error/exceptions.dart';
import 'package:rush_out/core/network/network_info.dart';
import 'package:rush_out/core/services/player_identity_service.dart';
import 'package:rush_out/core/services/tutorial_service.dart';
import 'package:rush_out/data/datasources/supabase_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/in_memory_local_database_datasource.dart';

class _FakeNetworkInfo implements NetworkInfo {
  bool connected;
  _FakeNetworkInfo({this.connected = true});

  @override
  Future<bool> get isConnected async => connected;
}

class _InMemorySecureTokenStore implements SecureTokenStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _FakeSupabaseServerAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<List<Map<String, dynamic>>> uploadedChunks = [];

  Map<String, dynamic>? storedProfile;
  List<Map<String, dynamic>> storedProgress = [];
  bool rejectOtpVerification = false;
  bool failBatchOnSecondChunk = false;
  String? userIdOverride;
  Duration delay = Duration.zero;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    final path = options.uri.path;
    final method = options.method.toUpperCase();

    if (path.endsWith('/auth/v1/otp')) {
      return _jsonResponse({'message_id': 'otp-msg-1'}, 200);
    }

    if (path.endsWith('/auth/v1/verify')) {
      if (rejectOtpVerification) {
        return _jsonResponse(
          {'error_description': 'Token has expired or is invalid'},
          401,
        );
      }
      final body = options.data as Map<String, dynamic>;
      final email = body['email'] as String? ?? 'driver@example.com';
      return _jsonResponse({
        'access_token': 'jwt_recoverable_access_token',
        'refresh_token': 'refresh_recoverable_token',
        'expires_in': 3600,
        'user': {
          'id': userIdOverride ?? 'uid-recoverable-123',
          'email': email,
          'is_anonymous': false,
        },
      }, 200);
    }

    if (path.endsWith('/auth/v1/signup')) {
      return _jsonResponse({
        'access_token': 'jwt_anon_only_token',
        'refresh_token': 'refresh_anon_only',
        'expires_in': 3600,
        'user': {
          'id': 'uid-anon-999',
          'is_anonymous': true,
        },
      }, 200);
    }

    if (path.endsWith('/auth/v1/logout')) {
      return _jsonResponse({}, 204);
    }

    if (path.endsWith('/rest/v1/player_profiles')) {
      if (method == 'GET') {
        return _jsonResponse(
          storedProfile != null ? [storedProfile] : <dynamic>[],
          200,
        );
      }
      if (method == 'POST') {
        storedProfile = Map<String, dynamic>.from(
          options.data as Map<String, dynamic>,
        );
        return _jsonResponse([], 201);
      }
    }

    if (path.endsWith('/rest/v1/player_level_progress')) {
      if (method == 'GET') {
        final limit =
            int.tryParse(options.queryParameters['limit'] ?? '1000') ?? 1000;
        final offset =
            int.tryParse(options.queryParameters['offset'] ?? '0') ?? 0;
        if (offset >= storedProgress.length) {
          return _jsonResponse(<dynamic>[], 200);
        }
        final end = (offset + limit < storedProgress.length)
            ? offset + limit
            : storedProgress.length;
        return _jsonResponse(storedProgress.sublist(offset, end), 200);
      }
      if (method == 'POST') {
        final rawRows = (options.data as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        uploadedChunks.add(rawRows);
        if (failBatchOnSecondChunk && uploadedChunks.length == 2) {
          return _jsonResponse({'message': 'Simulated server timeout'}, 500);
        }
        for (final row in rawRows) {
          final levelId = row['level_id'] as int;
          storedProgress.removeWhere((r) => r['level_id'] == levelId);
          storedProgress.add(row);
        }
        return _jsonResponse([], 201);
      }
    }

    return _jsonResponse({'message': 'Unhandled path $path'}, 404);
  }

  static ResponseBody _jsonResponse(Object payload, int statusCode) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerIdentityService & Recoverable Cloud Sync Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('validateUsername rejects math symbols (×/÷), links, and Vietnamese accented profanity without false positives', () {
      // Invalid cases
      expect(PlayerIdentityService.validateUsername('A'), isNotNull);
      expect(
        PlayerIdentityService.validateUsername('Driver_Name_Over_24_Chars'),
        isNotNull,
      );
      expect(PlayerIdentityService.validateUsername('Bad×Name'), isNotNull);
      expect(PlayerIdentityService.validateUsername('Bad÷Name'), isNotNull);
      expect(PlayerIdentityService.validateUsername('Driver@123'), isNotNull);
      expect(PlayerIdentityService.validateUsername('đụ má'), isNotNull);
      expect(PlayerIdentityService.validateUsername('địt mẹ'), isNotNull);
      expect(PlayerIdentityService.validateUsername('http://spam.com'), isNotNull);

      // Valid names (including Vietnamese diacritics and benign short tags)
      expect(PlayerIdentityService.validateUsername('Minh Anh_99'), isNull);
      expect(PlayerIdentityService.validateUsername('Nguyễn Văn Đạt'), isNull);
      expect(PlayerIdentityService.validateUsername('CC_Player'), isNull);
      expect(PlayerIdentityService.validateUsername('DM_Racer'), isNull);
      expect(PlayerIdentityService.validateUsername('VL_99'), isNull);
    });

    test('Guest Mode works offline, blocks cloud sync honestly, and does not write tokens to SharedPreferences', () async {
      final tokenStore = _InMemorySecureTokenStore();
      final adapter = _FakeSupabaseServerAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final remote = SupabaseRemoteDataSource(
        dio: dio,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon_public_key',
        tokenStore: tokenStore,
      );
      final service = PlayerIdentityService(
        remoteDataSource: remote,
        localDataSource: InMemoryLocalDatabaseDataSource(),
        tutorialService: TutorialService(),
        networkInfo: _FakeNetworkInfo(connected: false),
      );

      // Concurrent init shares work and finishes cleanly
      await Future.wait([service.init(), service.init()]);

      expect(service.accountMode, AccountMode.guest);
      expect(service.isRecoverable, isFalse);
      expect(service.hasUsername, isFalse);
      expect(service.isCloudSyncEnabled, isFalse);

      // Attempting to enable cloud sync or sync without linking email fails honestly
      await expectLater(
        service.setCloudSyncEnabled(true),
        throwsA(isA<ServerException>()),
      );
      final guestSync = await service.syncWithCloud(force: true);
      expect(guestSync.success, isFalse);
      expect(guestSync.errorMessage, contains('email'));

      // Username saves locally offline
      await service.setUsername('  GuestDriver  ');
      expect(service.username, 'GuestDriver');

      // SharedPreferences holds no JWTs or tokens
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        expect(key.contains('token'), isFalse);
      }
      expect(tokenStore.values, isEmpty);

      service.dispose();
    });

    test('Anonymous auth session cannot access recoverable player_profiles endpoints', () async {
      final tokenStore = _InMemorySecureTokenStore();
      final adapter = _FakeSupabaseServerAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final remote = SupabaseRemoteDataSource(
        dio: dio,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon_public_key',
        tokenStore: tokenStore,
      );

      // Create anonymous session (as Daily Challenge submission would)
      final anonSession = await remote.ensureAuthenticatedSession();
      expect(anonSession.isAnonymous, isTrue);
      expect(anonSession.isRecoverable, isFalse);

      // Recoverable endpoints must reject anonymous session
      await expectLater(
        remote.fetchPlayerProfile(),
        throwsA(isA<ServerException>()),
      );
      await expectLater(
        remote.fetchCloudLevelProgress(),
        throwsA(isA<ServerException>()),
      );
    });

    test('Email OTP link stores JWT in SecureTokenStore, restores progress after reinstall, and signOut reverts to Guest', () async {
      final sharedServer = _FakeSupabaseServerAdapter();
      final dio1 = Dio()..httpClientAdapter = sharedServer;
      final tokenStore1 = _InMemorySecureTokenStore();
      final remote1 = SupabaseRemoteDataSource(
        dio: dio1,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon_public_key',
        tokenStore: tokenStore1,
      );
      final localDb1 = InMemoryLocalDatabaseDataSource();
      await localDb1.upsertLevelProgress(
        levelId: 1,
        difficulty: 'easy',
        bestMoves: 5,
        stars: 3,
        isUnlocked: true,
      );
      final tutorial1 = TutorialService();
      await tutorial1.setTutorialCompleted(true);

      final device1 = PlayerIdentityService(
        remoteDataSource: remote1,
        localDataSource: localDb1,
        tutorialService: tutorial1,
        networkInfo: _FakeNetworkInfo(connected: true),
      );
      await device1.setUsername('CloudRacer');

      // Request OTP + verify
      await device1.requestEmailOtp('Racer@Example.com');
      final firstSync = await device1.verifyEmailOtpAndSync(
        email: 'racer@example.com',
        otpCode: '123456',
      );
      expect(firstSync.success, isTrue);
      expect(firstSync.uploadedCount, 1);
      expect(device1.accountMode, AccountMode.cloudAccount);
      expect(device1.email, 'racer@example.com');
      expect(device1.isCloudSynced, isTrue);

      // Token stored in SecureTokenStore, NOT SharedPreferences
      expect(tokenStore1.values, isNotEmpty);
      final prefs1 = await SharedPreferences.getInstance();
      expect(prefs1.getString('rush_out_sb_access_token'), isNull);

      // Simulate complete uninstall + reinstall on a wiped device
      SharedPreferences.setMockInitialValues({});
      final tokenStore2 = _InMemorySecureTokenStore();
      final dio2 = Dio()..httpClientAdapter = sharedServer;
      final remote2 = SupabaseRemoteDataSource(
        dio: dio2,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon_public_key',
        tokenStore: tokenStore2,
      );
      final freshDb = InMemoryLocalDatabaseDataSource();
      final freshTutorial = TutorialService();

      final device2 = PlayerIdentityService(
        remoteDataSource: remote2,
        localDataSource: freshDb,
        tutorialService: freshTutorial,
        networkInfo: _FakeNetworkInfo(connected: true),
      );

      // Before signing in, fresh install has no progress and is Guest
      expect(device2.accountMode, AccountMode.guest);
      expect(await freshDb.getAllLevelProgress(), isEmpty);

      // Verify OTP on new install -> restores username, tutorial & levels!
      await device2.requestEmailOtp('racer@example.com');
      final restoreReport = await device2.verifyEmailOtpAndSync(
        email: 'racer@example.com',
        otpCode: '123456',
      );
      expect(restoreReport.success, isTrue);
      expect(restoreReport.downloadedCount, 1);
      expect(device2.username, 'CloudRacer');
      expect(await freshTutorial.hasCompletedTutorial(), isTrue);

      final restoredLevels = await freshDb.getAllLevelProgress();
      expect(restoredLevels[1]?['stars'], 3);
      expect(restoredLevels[1]?['best_moves'], 5);

      // Sign out clears SecureTokenStore and reverts to Guest while keeping local SQLite progress
      await device2.signOutCloudAccount();
      expect(device2.accountMode, AccountMode.guest);
      expect(tokenStore2.values, isEmpty);
      expect((await freshDb.getAllLevelProgress())[1]?['stars'], 3);

      device1.dispose();
      device2.dispose();
    });

    test('Invalid OTP, offline network, and unconfigured Supabase return real errors without faking success', () async {
      final tokenStore = _InMemorySecureTokenStore();
      final adapter = _FakeSupabaseServerAdapter()..rejectOtpVerification = true;
      final dio = Dio()..httpClientAdapter = adapter;
      final net = _FakeNetworkInfo(connected: false);

      final remote = SupabaseRemoteDataSource(
        dio: dio,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon_public_key',
        tokenStore: tokenStore,
      );
      final service = PlayerIdentityService(
        remoteDataSource: remote,
        localDataSource: InMemoryLocalDatabaseDataSource(),
        tutorialService: TutorialService(),
        networkInfo: net,
      );

      // Offline throws real ServerException
      await expectLater(
        service.requestEmailOtp('user@example.com'),
        throwsA(isA<ServerException>()),
      );

      // Online with rejected OTP surfaces server's error_description
      net.connected = true;
      await expectLater(
        service.verifyEmailOtpAndSync(
          email: 'user@example.com',
          otpCode: '999999',
        ),
        throwsA(
          predicate<ServerException>(
            (e) => e.message.contains('Token has expired or is invalid'),
          ),
        ),
      );
      expect(service.accountMode, AccountMode.guest);

      // Unconfigured Supabase
      final unconfiguredService = PlayerIdentityService(
        remoteDataSource: SupabaseRemoteDataSource(
          dio: dio,
          supabaseUrl: '',
          supabaseAnonKey: '',
          tokenStore: _InMemorySecureTokenStore(),
        ),
        localDataSource: InMemoryLocalDatabaseDataSource(),
        tutorialService: TutorialService(),
        networkInfo: _FakeNetworkInfo(connected: true),
      );
      await expectLater(
        unconfiguredService.requestEmailOtp('user@example.com'),
        throwsA(isA<ServerException>()),
      );

      service.dispose();
      unconfiguredService.dispose();
    });

    test('Chunked batch upload splits 620 levels into 250-row chunks and paginated fetch retrieves all pages', () async {
      final adapter = _FakeSupabaseServerAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final remote = SupabaseRemoteDataSource(
        dio: dio,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon_public_key',
        tokenStore: _InMemorySecureTokenStore(),
      );
      final localDb = InMemoryLocalDatabaseDataSource();
      for (int id = 1; id <= 620; id++) {
        await localDb.upsertLevelProgress(
          levelId: id,
          difficulty: id <= 200 ? 'easy' : (id <= 400 ? 'medium' : 'hard'),
          bestMoves: 10 + (id % 5),
          stars: (id % 3) + 1,
          isUnlocked: true,
        );
      }

      final service = PlayerIdentityService(
        remoteDataSource: remote,
        localDataSource: localDb,
        tutorialService: TutorialService(),
        networkInfo: _FakeNetworkInfo(connected: true),
      );
      await service.setUsername('BatchTester');
      await service.requestEmailOtp('batch@example.com');
      final report = await service.verifyEmailOtpAndSync(
        email: 'batch@example.com',
        otpCode: '123456',
      );

      expect(report.success, isTrue);
      expect(report.uploadedCount, 620);
      expect(adapter.uploadedChunks.length, 3);
      expect(adapter.uploadedChunks[0].length, 250);
      expect(adapter.uploadedChunks[1].length, 250);
      expect(adapter.uploadedChunks[2].length, 120);

      // Paginated fetch with pageSize 200 fetches 4 pages (200+200+200+20)
      final fetched = await remote.fetchCloudLevelProgress(pageSize: 200);
      expect(fetched.length, 620);

      service.dispose();
    });

    test('Two-way merge resolves profile username by updated_at and clears is_skipped when stars > 0', () async {
      final adapter = _FakeSupabaseServerAdapter();
      final remoteUpdated = DateTime.now().toUtc().add(const Duration(minutes: 5));
      adapter.storedProfile = {
        'user_id': 'uid-recoverable-123',
        'username': 'NewerRemoteName',
        'tutorial_completed': true,
        'updated_at': remoteUpdated.toIso8601String(),
      };
      adapter.storedProgress = [
        {
          'level_id': 1,
          'difficulty': 'easy',
          'best_moves': 6,
          'stars': 2,
          'is_unlocked': true,
          'is_skipped': false,
          'updated_at': remoteUpdated.toIso8601String(),
        },
        {
          'level_id': 2,
          'difficulty': 'easy',
          'best_moves': null,
          'stars': 0,
          'is_unlocked': true,
          'is_skipped': true,
          'updated_at': remoteUpdated.toIso8601String(),
        },
      ];

      final dio = Dio()..httpClientAdapter = adapter;
      final remote = SupabaseRemoteDataSource(
        dio: dio,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon_public_key',
        tokenStore: _InMemorySecureTokenStore(),
      );
      final localDb = InMemoryLocalDatabaseDataSource();
      await localDb.upsertLevelProgress(
        levelId: 1,
        difficulty: 'easy',
        bestMoves: 4,
        stars: 3,
        isUnlocked: true,
        isSkipped: true,
      );

      final service = PlayerIdentityService(
        remoteDataSource: remote,
        localDataSource: localDb,
        tutorialService: TutorialService(),
        networkInfo: _FakeNetworkInfo(connected: true),
      );
      await service.setUsername('OlderLocalName');

      await service.requestEmailOtp('merge@example.com');
      final report = await service.verifyEmailOtpAndSync(
        email: 'merge@example.com',
        otpCode: '123456',
      );

      expect(report.success, isTrue);
      // Newer remote timestamp wins over older local username
      expect(service.username, 'NewerRemoteName');

      final merged = await localDb.getAllLevelProgress();
      // Level 1: max stars (3), min moves (4), is_skipped cleared because stars > 0
      expect(merged[1]?['stars'], 3);
      expect(merged[1]?['best_moves'], 4);
      expect(merged[1]?['is_skipped'], 0);
      // Level 2: remote skipped state restored
      expect(merged[2]?['is_skipped'], 1);

      service.dispose();
    });
  });
}

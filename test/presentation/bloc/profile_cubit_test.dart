import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/error/exceptions.dart';
import 'package:rush_out/core/network/network_info.dart';
import 'package:rush_out/core/services/audio_service.dart';
import 'package:rush_out/core/services/player_identity_service.dart';
import 'package:rush_out/core/services/tutorial_service.dart';
import 'package:rush_out/data/datasources/level_asset_datasource.dart';
import 'package:rush_out/data/datasources/supabase_remote_datasource.dart';
import 'package:rush_out/data/repositories/daily_challenge_repository_impl.dart';
import 'package:rush_out/data/repositories/leaderboard_repository_impl.dart';
import 'package:rush_out/data/repositories/level_repository_impl.dart';
import 'package:rush_out/domain/usecases/get_leaderboard.dart';
import 'package:rush_out/domain/usecases/get_levels.dart';
import 'package:rush_out/domain/usecases/save_progress.dart';
import 'package:rush_out/domain/usecases/submit_score.dart';
import 'package:rush_out/presentation/bloc/profile_cubit.dart';
import 'package:rush_out/presentation/screens/home_screen.dart';
import 'package:rush_out/presentation/widgets/dialogs/privacy_policy_dialog.dart';
import 'package:rush_out/presentation/widgets/dialogs/username_prompt_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/in_memory_local_database_datasource.dart';

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
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _FakeRemoteDataSource extends SupabaseRemoteDataSource {
  bool configured;
  bool failOtpSend = false;
  bool failOtpVerify = false;
  SupabaseSession? _fakeSession;
  Map<String, dynamic>? remoteProfile;
  List<Map<String, dynamic>> remoteProgress = [];

  _FakeRemoteDataSource({this.configured = true});

  @override
  bool get isConfigured => configured;

  @override
  SupabaseSession? get currentSession => _fakeSession;

  @override
  String? get currentUserId => _fakeSession?.userId;

  @override
  String? get currentUserEmail => _fakeSession?.email;

  @override
  bool get hasRecoverableSession => _fakeSession?.isRecoverable ?? false;

  @override
  Future<SupabaseSession?> loadSavedSession() async => _fakeSession;

  @override
  Future<void> sendEmailOtp(String email) async {
    if (failOtpSend) {
      throw const ServerException('Rate limit exceeded for OTP');
    }
  }

  @override
  Future<SupabaseSession> verifyEmailOtp({
    required String email,
    required String otpCode,
  }) async {
    if (failOtpVerify) {
      throw const ServerException('Invalid OTP code');
    }
    _fakeSession = SupabaseSession(
      accessToken: 'jwt_access_widget',
      refreshToken: 'jwt_refresh_widget',
      userId: 'uid-widget-1',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      email: email.trim().toLowerCase(),
      isAnonymous: false,
    );
    return _fakeSession!;
  }

  @override
  Future<void> signOut() async {
    _fakeSession = null;
  }

  @override
  Future<Map<String, dynamic>?> fetchPlayerProfile() async => remoteProfile;

  @override
  Future<void> upsertPlayerProfile({
    required String username,
    required bool tutorialCompleted,
    DateTime? updatedAt,
  }) async {
    remoteProfile = {
      'user_id': _fakeSession?.userId,
      'username': username,
      'tutorial_completed': tutorialCompleted,
      'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCloudLevelProgress({
    int pageSize = SupabaseRemoteDataSource.defaultProgressPageSize,
  }) async =>
      remoteProgress;

  @override
  Future<void> upsertCloudLevelProgressBatch(
    List<Map<String, dynamic>> rows, {
    int chunkSize = SupabaseRemoteDataSource.defaultSyncBatchSize,
  }) async {
    remoteProgress = rows;
  }
}

class _MockSupabaseHttpAdapter implements HttpClientAdapter {
  bool failOtpSend = false;
  bool failOtpVerify = false;
  Map<String, dynamic>? remoteProfile;
  List<Map<String, dynamic>> remoteProgress = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final method = options.method.toUpperCase();

    if (path.endsWith('/auth/v1/otp')) {
      if (failOtpSend) {
        return _json({'message': 'Rate limit exceeded for OTP'}, 429);
      }
      return _json({'message_id': 'otp-1'}, 200);
    }

    if (path.endsWith('/auth/v1/verify')) {
      if (failOtpVerify) {
        return _json({'error_description': 'Invalid OTP code'}, 401);
      }
      final body = options.data as Map<String, dynamic>;
      return _json({
        'access_token': 'jwt_access_1',
        'refresh_token': 'jwt_refresh_1',
        'expires_in': 3600,
        'user': {
          'id': 'uid-profile-test',
          'email': body['email'] ?? 'player@example.com',
          'is_anonymous': false,
        },
      }, 200);
    }

    if (path.endsWith('/auth/v1/logout')) {
      return _json({}, 204);
    }

    if (path.endsWith('/rest/v1/player_profiles')) {
      if (method == 'GET') {
        return _json(remoteProfile != null ? [remoteProfile] : <dynamic>[], 200);
      }
      if (method == 'POST') {
        remoteProfile = Map<String, dynamic>.from(
          options.data as Map<String, dynamic>,
        );
        return _json([], 201);
      }
    }

    if (path.endsWith('/rest/v1/player_level_progress')) {
      if (method == 'GET') {
        return _json(remoteProgress, 200);
      }
      if (method == 'POST') {
        return _json([], 201);
      }
    }

    return _json({}, 404);
  }

  static ResponseBody _json(Object data, int statusCode) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfileCubit Unit Tests', () {
    test('rejects invalid nickname and surfaces real error when syncing in Guest Mode', () async {
      final adapter = _MockSupabaseHttpAdapter();
      final remote = SupabaseRemoteDataSource(
        dio: Dio()..httpClientAdapter = adapter,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon_public_key',
        tokenStore: _InMemorySecureTokenStore(),
      );
      final service = PlayerIdentityService(
        remoteDataSource: remote,
        localDataSource: InMemoryLocalDatabaseDataSource(),
        tutorialService: TutorialService(),
        networkInfo: _FakeNetworkInfo(connected: true),
      );
      await service.init();

      final cubit = ProfileCubit(identityService: service);

      // Invalid nickname sets validationError
      expect(await cubit.saveUsername('Bad×Name'), isFalse);
      expect(cubit.state.validationError, isNotNull);
      expect(cubit.state.status, ProfileActionStatus.error);

      // Valid nickname saves locally
      expect(await cubit.saveUsername('ValidDriver'), isTrue);
      expect(cubit.state.username, 'ValidDriver');
      expect(cubit.state.status, ProfileActionStatus.success);

      // Sync Now as Guest emits real error (NOT fake "Will sync when online")
      final report = await cubit.syncNow();
      expect(report.success, isFalse);
      expect(cubit.state.status, ProfileActionStatus.error);
      expect(cubit.state.statusMessage, contains('email'));

      // Toggle cloud sync without email emits error and opens email linking step
      await cubit.toggleCloudSync(true);
      expect(cubit.state.cloudSyncEnabled, isFalse);
      expect(cubit.state.otpStep, OtpFlowStep.enterEmail);
      expect(cubit.state.status, ProfileActionStatus.error);

      await cubit.close();
      service.dispose();
    });

    test('Email OTP flow updates state through enterEmail -> enterCode -> linked & synced', () async {
      final adapter = _MockSupabaseHttpAdapter();
      final remote = SupabaseRemoteDataSource(
        dio: Dio()..httpClientAdapter = adapter,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon_public_key',
        tokenStore: _InMemorySecureTokenStore(),
      );
      final service = PlayerIdentityService(
        remoteDataSource: remote,
        localDataSource: InMemoryLocalDatabaseDataSource(),
        tutorialService: TutorialService(),
        networkInfo: _FakeNetworkInfo(connected: true),
      );
      await service.init();

      final cubit = ProfileCubit(identityService: service);
      cubit.startEmailLinking();
      expect(cubit.state.otpStep, OtpFlowStep.enterEmail);

      // Invalid email validation
      expect(await cubit.sendEmailOtp('not-an-email'), isFalse);
      expect(cubit.state.validationError, isNotNull);

      // Server rate limit error surfaced accurately
      adapter.failOtpSend = true;
      expect(await cubit.sendEmailOtp('driver@example.com'), isFalse);
      expect(cubit.state.status, ProfileActionStatus.error);
      expect(cubit.state.statusMessage, contains('Rate limit exceeded'));

      // Success OTP send
      adapter.failOtpSend = false;
      expect(await cubit.sendEmailOtp('driver@example.com'), isTrue);
      expect(cubit.state.otpStep, OtpFlowStep.enterCode);
      expect(cubit.state.pendingEmail, 'driver@example.com');

      // Failed OTP verify surfaces real server error
      adapter.failOtpVerify = true;
      expect(await cubit.verifyEmailOtp('000000'), isFalse);
      expect(cubit.state.status, ProfileActionStatus.error);
      expect(cubit.state.statusMessage, contains('Invalid OTP code'));

      // Success OTP verify links account and syncs
      adapter.failOtpVerify = false;
      expect(await cubit.verifyEmailOtp('123456'), isTrue);
      expect(cubit.state.isRecoverable, isTrue);
      expect(cubit.state.isCloudSynced, isTrue);
      expect(cubit.state.email, 'driver@example.com');
      expect(cubit.state.otpStep, OtpFlowStep.none);

      // Sign out returns to Guest mode
      await cubit.signOutCloudAccount();
      expect(cubit.state.isRecoverable, isFalse);
      expect(cubit.state.accountMode, AccountMode.guest);

      await cubit.close();
      service.dispose();
    });
  });

  group('Profile UI & HomeScreen Reactive Widget Tests', () {
    testWidgets('HomeScreen opens directly without forced prompt and updates reactively when ProfileCubit changes', (tester) async {
      final remote = _FakeRemoteDataSource(configured: true);
      final localDb = InMemoryLocalDatabaseDataSource();
      final net = _FakeNetworkInfo(connected: true);
      final service = PlayerIdentityService(
        remoteDataSource: remote,
        localDataSource: localDb,
        tutorialService: TutorialService(),
        networkInfo: net,
      );
      await service.init();
      final cubit = ProfileCubit(identityService: service);

      final levelRepo = LevelRepositoryImpl(
        assetDataSource: LevelAssetDataSource(),
        localDataSource: localDb,
      );
      final dailyRepo = DailyChallengeRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: localDb,
        networkInfo: net,
      );
      final leaderboardRepo = LeaderboardRepositoryImpl(
        remoteDataSource: remote,
        networkInfo: net,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            audioService: AudioService(enablePlatformAudio: false),
            profileCubit: cubit,
            getLevelsUseCase: GetLevels(levelRepo),
            saveProgressUseCase: SaveProgress(levelRepo),
            dailyRepository: dailyRepo,
            submitScoreUseCase: SubmitScore(leaderboardRepo),
            getLeaderboardUseCase: GetLeaderboard(leaderboardRepo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Does NOT block first launch with mandatory UsernamePromptDialog
      expect(find.text('Pick Your Driver Name'), findsNothing);
      expect(find.text('Guest Driver'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);

      // Tap Profile Pill -> opens ProfileDialog in Guest Mode
      await tester.tap(find.text('Guest Driver'));
      await tester.pumpAndSettle();
      expect(find.text('Guest Mode (Local Only)'), findsOneWidget);

      // Tapping Sync Now as Guest shows real error, never fake success
      await tester.tap(find.text('Sync Now'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Link an email account'), findsWidgets);
      expect(find.text('Sync enabled. Will sync when online.'), findsNothing);

      // Complete Email OTP flow from UI
      await tester.tap(find.text('Link Email for Cloud Backup & Recovery'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'racer@example.com');
      await tester.tap(find.text('Send Code'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '654321');
      await tester.tap(find.text('Verify & Sync'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cloud Synced'), findsOneWidget);

      // Close ProfileDialog -> HomeScreen reactively shows cloud_done icon
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);

      // Background username update via service notifies ProfileCubit & HomeScreen
      await service.setUsername('ReactiveRacer');
      await tester.pump();
      expect(find.text('ReactiveRacer'), findsOneWidget);

      await cubit.close();
      service.dispose();
    });

    testWidgets('UsernamePromptDialog supports Play as Guest and validates math symbols', (tester) async {
      final remote = SupabaseRemoteDataSource(
        tokenStore: _InMemorySecureTokenStore(),
      );
      final service = PlayerIdentityService(
        remoteDataSource: remote,
        localDataSource: InMemoryLocalDatabaseDataSource(),
        tutorialService: TutorialService(),
        networkInfo: _FakeNetworkInfo(connected: false),
      );
      await service.init();
      final cubit = ProfileCubit(identityService: service);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => UsernamePromptDialog.show(
                  context,
                  profileCubit: cubit,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Play as Guest'), findsOneWidget);

      // Enter invalid symbol ×
      await tester.enterText(find.byType(TextField), 'Test×Name');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Only letters, numbers, spaces, hyphens, and underscores are allowed.'),
        findsOneWidget,
      );

      // Tap Play as Guest dismisses cleanly
      await tester.tap(find.text('Play as Guest'));
      await tester.pumpAndSettle();
      expect(find.text('Choose Driver Name'), findsNothing);

      await cubit.close();
      service.dispose();
    });

    testWidgets('PrivacyPolicyDialog reflects Offline Guest and Email OTP storage accurately', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PrivacyPolicyDialog()),
        ),
      );
      expect(
        find.text('1. Local Data Storage (Offline Guest Mode)'),
        findsOneWidget,
      );
      expect(
        find.text('3. Optional Email Account & Cloud Progress Sync'),
        findsOneWidget,
      );
    });
  });
}

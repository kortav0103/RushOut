import 'package:flutter_test/flutter_test.dart';
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

class _FakeSupabaseRemoteDataSource extends SupabaseRemoteDataSource {
  bool configured;
  Map<String, dynamic>? remoteProfile;
  List<Map<String, dynamic>> remoteProgress = [];
  List<Map<String, dynamic>> uploadedProgress = [];
  Map<String, dynamic>? lastUpsertedProfile;
  int fetchProfileCallCount = 0;
  Duration fetchDelay = Duration.zero;

  _FakeSupabaseRemoteDataSource({this.configured = true});

  @override
  bool get isConfigured => configured;

  @override
  Future<Map<String, dynamic>?> fetchDeviceProfile(String deviceId) async {
    fetchProfileCallCount++;
    if (fetchDelay > Duration.zero) {
      await Future<void>.delayed(fetchDelay);
    }
    return remoteProfile;
  }

  @override
  Future<void> upsertDeviceProfile({
    required String deviceId,
    required String username,
    required bool tutorialCompleted,
  }) async {
    lastUpsertedProfile = {
      'device_id': deviceId,
      'username': username,
      'tutorial_completed': tutorialCompleted,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDeviceLevelProgress(
    String deviceId,
  ) async {
    return remoteProgress;
  }

  @override
  Future<void> upsertDeviceLevelProgressBatch(
    List<Map<String, dynamic>> rows,
  ) async {
    uploadedProgress = rows;
  }
}

void main() {
  group('Device-Based PlayerIdentityService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Case 1 & 2: Offline first launch resolves persistent deviceId and saves username locally', () async {
      final remote = _FakeSupabaseRemoteDataSource(configured: true);
      final localDb = InMemoryLocalDatabaseDataSource();
      final tutorial = TutorialService();
      final net = _FakeNetworkInfo(connected: false);

      final service = PlayerIdentityService(
        remoteDataSource: remote,
        localDataSource: localDb,
        tutorialService: tutorial,
        networkInfo: net,
        deviceIdProvider: () async => 'win_TEST_DEVICE_001',
      );

      await service.init();
      expect(service.deviceId, 'win_TEST_DEVICE_001');
      expect(service.hasUsername, isFalse);
      expect(await service.syncWithCloud(), isFalse);

      // Invalid usernames rejected (length, special chars, profanity, links)
      await expectLater(service.setUsername('A'), throwsArgumentError);
      await expectLater(
        service.setUsername('A_Very_Long_Driver_Name_Over_24'),
        throwsArgumentError,
      );
      await expectLater(service.setUsername('Driver@123!'), throwsArgumentError);
      await expectLater(
        service.setUsername('player fuck 123'),
        throwsArgumentError,
      );
      await expectLater(
        service.setUsername('visit http://spam.com'),
        throwsArgumentError,
      );
      expect(PlayerIdentityService.validateUsername('Minh Anh_99'), isNull);

      // Valid username persisted locally even offline
      await service.setUsername('  SpeedyDriver  ');
      expect(service.username, 'SpeedyDriver');
      expect(service.hasUsername, isTrue);

      // Fresh instance loads persisted username
      final reloaded = PlayerIdentityService(
        remoteDataSource: remote,
        localDataSource: localDb,
        tutorialService: tutorial,
        networkInfo: net,
        deviceIdProvider: () async => 'win_TEST_DEVICE_001',
      );
      await reloaded.init();
      expect(reloaded.username, 'SpeedyDriver');
      expect(reloaded.deviceId, 'win_TEST_DEVICE_001');
    });

    test('Case 3: Reinstall on same device (wiped local storage) auto-restores username, tutorial & levels', () async {
      final remote = _FakeSupabaseRemoteDataSource(configured: true)
        ..remoteProfile = {
          'device_id': 'win_TEST_DEVICE_001',
          'username': 'ReturningDriver',
          'tutorial_completed': true,
        }
        ..remoteProgress = [
          {
            'level_id': 1,
            'difficulty': 'easy',
            'best_moves': 5,
            'stars': 3,
            'is_unlocked': true,
          },
          {
            'level_id': 2,
            'difficulty': 'easy',
            'best_moves': 7,
            'stars': 2,
            'is_unlocked': true,
          },
        ];

      // Fresh wiped local DB & SharedPreferences (simulating app uninstall + reinstall)
      final freshDb = InMemoryLocalDatabaseDataSource();
      final freshTutorial = TutorialService();
      expect(await freshTutorial.hasCompletedTutorial(), isFalse);

      final service = PlayerIdentityService(
        remoteDataSource: remote,
        localDataSource: freshDb,
        tutorialService: freshTutorial,
        networkInfo: _FakeNetworkInfo(connected: true),
        deviceIdProvider: () async => 'win_TEST_DEVICE_001',
      );

      // Cloud sync is opt-in by default; without opt-in it does not transmit
      expect(service.isCloudSyncEnabled, isFalse);
      expect(await service.syncWithCloud(), isFalse);
      expect(remote.fetchProfileCallCount, 0);

      await service.setCloudSyncEnabled(true);
      final synced = await service.syncWithCloud();
      expect(synced, isTrue);
      expect(service.isCloudSynced, isTrue);
      expect(service.username, 'ReturningDriver');
      expect(service.hasUsername, isTrue);
      expect(await freshTutorial.hasCompletedTutorial(), isTrue);

      final restoredLevels = await freshDb.getAllLevelProgress();
      expect(restoredLevels[1]?['stars'], 3);
      expect(restoredLevels[1]?['best_moves'], 5);
      expect(restoredLevels[2]?['stars'], 2);
      expect(restoredLevels[2]?['is_unlocked'], 1);
    });

    test('Case 4: Two-way merge preserves max stars, min moves, and uploads local progress', () async {
      final remote = _FakeSupabaseRemoteDataSource(configured: true)
        ..remoteProfile = {
          'device_id': 'win_TEST_DEVICE_001',
          'username': 'LocalHero',
          'tutorial_completed': false,
        }
        ..remoteProgress = [
          {
            'level_id': 1,
            'difficulty': 'easy',
            'best_moves': 6,
            'stars': 2,
            'is_unlocked': true,
          },
        ];

      final localDb = InMemoryLocalDatabaseDataSource();
      await localDb.upsertLevelProgress(
        levelId: 1,
        difficulty: 'easy',
        bestMoves: 5,
        stars: 3,
        isUnlocked: true,
      );
      await localDb.upsertLevelProgress(
        levelId: 2,
        difficulty: 'easy',
        bestMoves: null,
        stars: 0,
        isUnlocked: true,
      );

      final tutorial = TutorialService();
      await tutorial.setTutorialCompleted(true);

      final service = PlayerIdentityService(
        remoteDataSource: remote,
        localDataSource: localDb,
        tutorialService: tutorial,
        networkInfo: _FakeNetworkInfo(connected: true),
        deviceIdProvider: () async => 'win_TEST_DEVICE_001',
      );

      await service.setCloudSyncEnabled(true);
      await service.setUsername('LocalHero');
      expect(remote.lastUpsertedProfile?['tutorial_completed'], isTrue);
      expect(
        remote.uploadedProgress.any((r) => r['level_id'] == 1 && r['stars'] == 3),
        isTrue,
      );
      expect(
        remote.uploadedProgress.any((r) => r['level_id'] == 2 && r['is_unlocked'] == true),
        isTrue,
      );
    });

    test('Case 5: Concurrent syncWithCloud calls share the in-flight Future', () async {
      final remote = _FakeSupabaseRemoteDataSource(configured: true)
        ..fetchDelay = const Duration(milliseconds: 30)
        ..remoteProfile = {
          'device_id': 'win_TEST_DEVICE_001',
          'username': 'ConcurrentDriver',
          'tutorial_completed': true,
        };

      final service = PlayerIdentityService(
        remoteDataSource: remote,
        localDataSource: InMemoryLocalDatabaseDataSource(),
        tutorialService: TutorialService(),
        networkInfo: _FakeNetworkInfo(connected: true),
        deviceIdProvider: () async => 'win_TEST_DEVICE_001',
      );

      await service.setCloudSyncEnabled(true);
      final results = await Future.wait([
        service.syncWithCloud(),
        service.syncWithCloud(),
        service.syncWithCloud(),
      ]);

      expect(results, [true, true, true]);
      expect(remote.fetchProfileCallCount, 1);
      expect(service.username, 'ConcurrentDriver');
    });
  });
}

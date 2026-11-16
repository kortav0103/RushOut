import 'dart:math' as math;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/local_database_datasource.dart';
import '../../data/datasources/supabase_remote_datasource.dart';
import '../network/network_info.dart';
import 'tutorial_service.dart';

class PlayerIdentityService {
  static const String _deviceIdKey = 'rush_out_device_id';
  static const String _usernameKey = 'rush_out_player_username';
  static const String _lastSyncedAtKey = 'rush_out_last_synced_at';
  static const String _cloudSyncEnabledKey = 'rush_out_cloud_sync_enabled';

  static final RegExp _validNameRegex =
      RegExp(r'^[a-zA-Z0-9_\-\sÀ-ỹ]+$');

  static const List<String> _blockedTerms = [
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'dick',
    'pussy',
    'cunt',
    'nigger',
    'faggot',
    'whore',
    'slut',
    'dm',
    'dkm',
    'dmm',
    'vcl',
    'vl',
    'cc',
    'cl',
    'dit',
    'du ma',
    'lon',
    'buoi',
    'cac',
    'http',
    'www.',
    '.com',
  ];

  final SupabaseRemoteDataSource remoteDataSource;
  final LocalDatabaseDataSource localDataSource;
  final TutorialService tutorialService;
  final NetworkInfo networkInfo;
  final Future<SharedPreferences> Function()? _prefsProvider;
  final Future<String?> Function()? _deviceIdProvider;

  String _deviceId = '';
  String? _username;
  DateTime? _lastSyncedAt;
  bool _cloudSyncEnabled = false;
  bool _hasSyncedCloud = false;
  bool _isInitialized = false;
  Future<bool>? _ongoingSync;

  PlayerIdentityService({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.tutorialService,
    required this.networkInfo,
    Future<SharedPreferences> Function()? prefsProvider,
    Future<String?> Function()? deviceIdProvider,
  })  : _prefsProvider = prefsProvider,
        _deviceIdProvider = deviceIdProvider;

  String get deviceId => _deviceId;
  String? get username => _username;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get hasUsername => _username != null && _username!.trim().isNotEmpty;
  bool get isCloudSyncEnabled => _cloudSyncEnabled;
  bool get isCloudSynced => _hasSyncedCloud;

  /// Validates player username/nickname for length, allowed characters,
  /// and profanity/spam links (single source of truth for Profile & Leaderboard).
  static String? validateUsername(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.length < 2 || trimmed.length > 24) {
      return 'Nickname must be between 2 and 24 characters.';
    }
    if (!_validNameRegex.hasMatch(trimmed)) {
      return 'Only letters, numbers, spaces, hyphens, and underscores are allowed.';
    }
    final lower = trimmed.toLowerCase();
    final tokens = lower.split(RegExp(r'[\s_\-]+'));
    for (final term in _blockedTerms) {
      if (term.contains('.') || term.length >= 4) {
        if (lower.contains(term)) {
          return 'Please choose an appropriate nickname without restricted words or links.';
        }
      } else if (tokens.contains(term)) {
        return 'Please choose an appropriate nickname without restricted words.';
      }
    }
    return null;
  }

  Future<SharedPreferences> _prefs() =>
      _prefsProvider?.call() ?? SharedPreferences.getInstance();

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await _prefs();
      _username = prefs.getString(_usernameKey);
      _cloudSyncEnabled = prefs.getBool(_cloudSyncEnabledKey) ?? false;
      final syncedRaw = prefs.getString(_lastSyncedAtKey);
      if (syncedRaw != null) {
        _lastSyncedAt = DateTime.tryParse(syncedRaw);
      }

      if (_deviceIdProvider != null) {
        final provided = await _deviceIdProvider!();
        if (provided != null && provided.trim().isNotEmpty) {
          _deviceId = provided.trim();
          await prefs.setString(_deviceIdKey, _deviceId);
        } else {
          _deviceId = prefs.getString(_deviceIdKey) ?? '';
          if (_deviceId.isEmpty) {
            _deviceId = _generateFallbackUuid();
            await prefs.setString(_deviceIdKey, _deviceId);
          }
        }
      } else {
        // Installation-scoped identifier persisted in SharedPreferences.
        // Note: Reinstalling or clearing app data generates a fresh local installation ID.
        final storedId = prefs.getString(_deviceIdKey);
        if (storedId != null && storedId.trim().isNotEmpty) {
          _deviceId = storedId.trim();
        } else {
          final hardwareId = await _resolveInstallationFallbackId();
          _deviceId = (hardwareId != null && hardwareId.trim().isNotEmpty)
              ? hardwareId.trim()
              : _generateFallbackUuid();
          await prefs.setString(_deviceIdKey, _deviceId);
        }
      }
    } catch (_) {
      if (_deviceId.isEmpty) {
        _deviceId = _generateFallbackUuid();
      }
    }
  }

  Future<String?> _resolveInstallationFallbackId() async {
    if (_deviceIdProvider != null) {
      return await _deviceIdProvider!();
    }
    if (kIsWeb) return null;

    try {
      final plugin = DeviceInfoPlugin();
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
          final info = await plugin.windowsInfo;
          return info.deviceId.isNotEmpty ? 'win_${info.deviceId}' : null;
        case TargetPlatform.android:
          // Android does not expose a stable reinstall-proof ID without user sign-in;
          // use a generated installation UUID instead of fingerprinting hardware.
          return _generateFallbackUuid();
        case TargetPlatform.iOS:
          final info = await plugin.iosInfo;
          final vendor = info.identifierForVendor;
          return (vendor != null && vendor.isNotEmpty) ? 'ios_$vendor' : null;
        case TargetPlatform.macOS:
          final info = await plugin.macOsInfo;
          final guid = info.systemGUID;
          return (guid != null && guid.isNotEmpty) ? 'mac_$guid' : null;
        case TargetPlatform.linux:
          final info = await plugin.linuxInfo;
          final id = info.machineId;
          return (id != null && id.isNotEmpty) ? 'lin_$id' : null;
        case TargetPlatform.fuchsia:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// Enables or disables opt-in cloud backup sync.
  Future<void> setCloudSyncEnabled(bool enabled) async {
    await init();
    _cloudSyncEnabled = enabled;
    try {
      final prefs = await _prefs();
      await prefs.setBool(_cloudSyncEnabledKey, enabled);
    } catch (_) {}
    if (!enabled) {
      _hasSyncedCloud = false;
    }
  }

  /// Validates and saves the player's username locally, then syncs to cloud if opted in.
  Future<void> setUsername(String rawName) async {
    await init();
    final validationError = validateUsername(rawName);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }
    final trimmed = rawName.trim();

    _username = trimmed;
    try {
      final prefs = await _prefs();
      await prefs.setString(_usernameKey, trimmed);
    } catch (_) {}

    if (_cloudSyncEnabled) {
      try {
        await syncWithCloud();
      } catch (_) {}
    }
  }

  /// Two-way merge sync between local SQLite/SharedPreferences and Supabase
  /// scoped to the authenticated session (`auth.uid()`). Requires opt-in unless [force] is true.
  Future<bool> syncWithCloud({bool force = false}) {
    final active = _ongoingSync;
    if (active != null) return active;

    late final Future<bool> syncFuture;
    syncFuture = _performSyncWithCloud(force: force).whenComplete(() {
      if (identical(_ongoingSync, syncFuture)) {
        _ongoingSync = null;
      }
    });
    _ongoingSync = syncFuture;
    return syncFuture;
  }

  Future<bool> _performSyncWithCloud({bool force = false}) async {
    await init();
    if ((!_cloudSyncEnabled && !force) ||
        _deviceId.isEmpty ||
        !remoteDataSource.isConfigured) {
      return false;
    }
    final connected = await networkInfo.isConnected;
    if (!connected) return false;

    try {
      // 1. Fetch remote profile for this deviceId
      final remoteProfile =
          await remoteDataSource.fetchDeviceProfile(_deviceId);

      // Restore username if local was wiped (e.g. reinstall on same device)
      final remoteUsername = remoteProfile?['username'] as String?;
      if ((_username == null || _username!.trim().isEmpty) &&
          remoteUsername != null &&
          remoteUsername.trim().isNotEmpty) {
        _username = remoteUsername.trim();
        try {
          final prefs = await _prefs();
          await prefs.setString(_usernameKey, _username!);
        } catch (_) {}
      }

      // Restore or merge tutorial completion
      final localTutorial = await tutorialService.hasCompletedTutorial();
      final remoteTutorial =
          (remoteProfile?['tutorial_completed'] as bool?) ?? false;
      final mergedTutorial = localTutorial || remoteTutorial;
      if (mergedTutorial && !localTutorial) {
        await tutorialService.setTutorialCompleted(true);
      }

      // Only create/update remote profile once the player has a username
      // (or already has a remote profile).
      if (hasUsername || remoteProfile != null) {
        final effectiveName = hasUsername
            ? _username!.trim()
            : (remoteUsername ?? 'Driver');
        await remoteDataSource.upsertDeviceProfile(
          deviceId: _deviceId,
          username: effectiveName,
          tutorialCompleted: mergedTutorial,
        );
      }

      // 2. Two-way merge of level_progress
      final localMap = await localDataSource.getAllLevelProgress();
      final remoteRows =
          await remoteDataSource.fetchDeviceLevelProgress(_deviceId);

      final Map<int, Map<String, dynamic>> remoteMap = {};
      for (final row in remoteRows) {
        final id = row['level_id'] as int?;
        if (id != null) remoteMap[id] = row;
      }

      final allIds = <int>{...localMap.keys, ...remoteMap.keys};
      final List<Map<String, dynamic>> toUpload = [];

      for (final levelId in allIds) {
        final local = localMap[levelId];
        final remote = remoteMap[levelId];

        final localStars = (local?['stars'] as int?) ?? 0;
        final remoteStars = (remote?['stars'] as int?) ?? 0;
        final mergedStars = math.max(localStars, remoteStars);

        final localBest = local?['best_moves'] as int?;
        final remoteBest = remote?['best_moves'] as int?;
        final int? mergedBest;
        if (localBest == null) {
          mergedBest = remoteBest;
        } else if (remoteBest == null) {
          mergedBest = localBest;
        } else {
          mergedBest = math.min(localBest, remoteBest);
        }

        final localUnlocked = (local?['is_unlocked'] as int? ?? 0) == 1;
        final remoteUnlocked = (remote?['is_unlocked'] as bool?) ?? false;
        final mergedUnlocked = localUnlocked || remoteUnlocked;

        final difficulty = (local?['difficulty'] as String?) ??
            (remote?['difficulty'] as String?) ??
            'easy';

        // Update local SQLite if remote brought newer/better progress (e.g. after reinstall)
        if (local == null ||
            mergedStars != localStars ||
            mergedBest != localBest ||
            (mergedUnlocked && !localUnlocked)) {
          await localDataSource.upsertLevelProgress(
            levelId: levelId,
            difficulty: difficulty,
            bestMoves: mergedBest,
            stars: mergedStars,
            isUnlocked: mergedUnlocked,
          );
        }

        // Upload to cloud only if a profile exists on cloud (foreign key constraint)
        if ((hasUsername || remoteProfile != null) &&
            (remote == null ||
                mergedStars != remoteStars ||
                mergedBest != remoteBest ||
                (mergedUnlocked && !remoteUnlocked))) {
          toUpload.add({
            'device_id': _deviceId,
            'level_id': levelId,
            'difficulty': difficulty,
            'best_moves': mergedBest,
            'stars': mergedStars,
            'is_unlocked': mergedUnlocked,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }

      if (toUpload.isNotEmpty) {
        await remoteDataSource.upsertDeviceLevelProgressBatch(toUpload);
      }

      _hasSyncedCloud = true;
      _lastSyncedAt = DateTime.now();
      try {
        final prefs = await _prefs();
        await prefs.setString(
          _lastSyncedAtKey,
          _lastSyncedAt!.toIso8601String(),
        );
      } catch (_) {}

      return true;
    } catch (_) {
      return false;
    }
  }

  static String _generateShortHex(int count) {
    final rng = math.Random.secure();
    return List.generate(
      count,
      (_) => rng.nextInt(16).toRadixString(16),
    ).join();
  }

  static String _generateFallbackUuid() {
    final rng = math.Random.secure();
    return 'dev_${_generateShortHex(8)}-${_generateShortHex(4)}-4${_generateShortHex(3)}-${(8 + rng.nextInt(4)).toRadixString(16)}${_generateShortHex(3)}-${_generateShortHex(12)}';
  }
}

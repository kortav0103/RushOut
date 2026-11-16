import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/local_database_datasource.dart';
import '../../data/datasources/supabase_remote_datasource.dart';
import '../error/exceptions.dart';
import '../network/network_info.dart';
import 'tutorial_service.dart';

enum AccountMode {
  guest,
  cloudAccount,
}

class PlayerProfileSnapshot extends Equatable {
  final AccountMode accountMode;
  final String? username;
  final String? email;
  final bool cloudSyncEnabled;
  final bool isCloudSynced;
  final DateTime? lastSyncedAt;

  const PlayerProfileSnapshot({
    this.accountMode = AccountMode.guest,
    this.username,
    this.email,
    this.cloudSyncEnabled = false,
    this.isCloudSynced = false,
    this.lastSyncedAt,
  });

  bool get hasUsername => username != null && username!.trim().isNotEmpty;

  bool get isRecoverable =>
      accountMode == AccountMode.cloudAccount &&
      email != null &&
      email!.trim().isNotEmpty;

  @override
  List<Object?> get props => [
        accountMode,
        username,
        email,
        cloudSyncEnabled,
        isCloudSynced,
        lastSyncedAt,
      ];
}

class CloudSyncReport extends Equatable {
  final bool success;
  final String? errorMessage;
  final int uploadedCount;
  final int downloadedCount;
  final DateTime? syncedAt;

  const CloudSyncReport({
    required this.success,
    this.errorMessage,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.syncedAt,
  });

  factory CloudSyncReport.succeeded({
    int uploadedCount = 0,
    int downloadedCount = 0,
    DateTime? syncedAt,
  }) {
    return CloudSyncReport(
      success: true,
      uploadedCount: uploadedCount,
      downloadedCount: downloadedCount,
      syncedAt: syncedAt ?? DateTime.now().toUtc(),
    );
  }

  factory CloudSyncReport.failed(String message) {
    return CloudSyncReport(
      success: false,
      errorMessage: message,
    );
  }

  @override
  List<Object?> get props => [
        success,
        errorMessage,
        uploadedCount,
        downloadedCount,
        syncedAt,
      ];
}

class PlayerIdentityService {
  static const String _usernameKey = 'rush_out_player_username';
  static const String _usernameUpdatedAtKey = 'rush_out_username_updated_at';
  static const String _lastSyncedAtKey = 'rush_out_last_synced_at';
  static const String _cloudSyncEnabledKey = 'rush_out_cloud_sync_enabled';

  /// Allows ASCII letters/digits, spaces, hyphens, underscores, and valid
  /// Latin/Vietnamese letters while explicitly excluding U+00D7 (×) & U+00F7 (÷).
  static final RegExp _validNameRegex = RegExp(
    r'^[a-zA-Z0-9_\-\s\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u024F\u1E00-\u1EFF]+$',
  );

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  static const List<String> _blockedPhrases = [
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'nigger',
    'faggot',
    'whore',
    'slut',
    'pussy',
    'cunt',
    'du ma',
    'duma',
    'dit me',
    'ditme',
    'con cac',
    'cai lon',
    'http://',
    'https://',
    'www.',
    '.com',
    '.net',
    '.org',
    '.vn',
  ];

  static const List<String> _blockedTokens = [
    'dick',
    'dkm',
    'dmm',
    'vcl',
    'vkl',
    'dit',
    'lon',
    'buoi',
    'cac',
  ];

  final SupabaseRemoteDataSource remoteDataSource;
  final LocalDatabaseDataSource localDataSource;
  final TutorialService tutorialService;
  final NetworkInfo networkInfo;
  final Future<SharedPreferences> Function()? _prefsProvider;

  final ValueNotifier<PlayerProfileSnapshot> snapshotNotifier =
      ValueNotifier<PlayerProfileSnapshot>(const PlayerProfileSnapshot());

  String? _username;
  DateTime? _usernameUpdatedAt;
  DateTime? _lastSyncedAt;
  bool _cloudSyncEnabled = false;
  bool _hasSyncedCloud = false;
  bool _isInitialized = false;
  Future<void>? _initFuture;
  Future<CloudSyncReport>? _ongoingSync;

  PlayerIdentityService({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.tutorialService,
    required this.networkInfo,
    Future<SharedPreferences> Function()? prefsProvider,
  }) : _prefsProvider = prefsProvider;

  PlayerProfileSnapshot get snapshot => snapshotNotifier.value;
  String? get username => _username;
  String? get email => remoteDataSource.hasRecoverableSession
      ? remoteDataSource.currentUserEmail
      : null;
  AccountMode get accountMode => remoteDataSource.hasRecoverableSession
      ? AccountMode.cloudAccount
      : AccountMode.guest;
  bool get isRecoverable => remoteDataSource.hasRecoverableSession;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get hasUsername => _username != null && _username!.trim().isNotEmpty;
  bool get isCloudSyncEnabled => isRecoverable && _cloudSyncEnabled;
  bool get isCloudSynced => isRecoverable && _hasSyncedCloud;

  /// Validates player nickname for length, allowed characters, and profanity/links.
  static String? validateUsername(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.length < 2 || trimmed.length > 24) {
      return 'Nickname must be between 2 and 24 characters.';
    }
    if (!_validNameRegex.hasMatch(trimmed)) {
      return 'Only letters, numbers, spaces, hyphens, and underscores are allowed.';
    }

    final folded = _foldVietnameseDiacritics(trimmed.toLowerCase());
    final collapsedSpaces = folded.replaceAll(RegExp(r'\s+'), ' ');
    for (final phrase in _blockedPhrases) {
      if (collapsedSpaces.contains(phrase)) {
        return 'Please choose an appropriate nickname without restricted words or links.';
      }
    }

    final tokens = collapsedSpaces
        .split(RegExp(r'[\s_\-]+'))
        .where((t) => t.isNotEmpty)
        .toSet();
    for (final token in _blockedTokens) {
      if (tokens.contains(token)) {
        return 'Please choose an appropriate nickname without restricted words.';
      }
    }
    return null;
  }

  static String? validateEmail(String rawEmail) {
    final trimmed = rawEmail.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your email address.';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? validateOtpCode(String rawCode) {
    final trimmed = rawCode.trim();
    if (trimmed.length < 6 || !RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'Enter the 6-digit verification code from your email.';
    }
    return null;
  }

  static String _foldVietnameseDiacritics(String input) {
    const replacements = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(replacements[ch] ?? ch);
    }
    return buffer.toString();
  }

  Future<SharedPreferences> _prefs() =>
      _prefsProvider?.call() ?? SharedPreferences.getInstance();

  void _publishSnapshot() {
    snapshotNotifier.value = PlayerProfileSnapshot(
      accountMode: accountMode,
      username: _username,
      email: email,
      cloudSyncEnabled: isCloudSyncEnabled,
      isCloudSynced: isCloudSynced,
      lastSyncedAt: _lastSyncedAt,
    );
  }

  /// Initializes local preferences and loads any securely persisted cloud
  /// session. Concurrent callers share the in-flight initialization Future, and
  /// [_isInitialized] is only marked true once all awaits succeed.
  Future<void> init() {
    if (_isInitialized) return Future<void>.value();
    final inFlight = _initFuture;
    if (inFlight != null) return inFlight;

    final future = _performInit();
    _initFuture = future;
    return future.whenComplete(() {
      if (identical(_initFuture, future)) {
        _initFuture = null;
      }
    });
  }

  Future<void> _performInit() async {
    final prefs = await _prefs();
    final savedUsername = prefs.getString(_usernameKey);
    _username = (savedUsername != null && savedUsername.trim().isNotEmpty)
        ? savedUsername.trim()
        : null;

    final updatedRaw = prefs.getString(_usernameUpdatedAtKey);
    _usernameUpdatedAt =
        updatedRaw != null ? DateTime.tryParse(updatedRaw)?.toUtc() : null;

    _cloudSyncEnabled = prefs.getBool(_cloudSyncEnabledKey) ?? false;

    final syncedRaw = prefs.getString(_lastSyncedAtKey);
    _lastSyncedAt =
        syncedRaw != null ? DateTime.tryParse(syncedRaw)?.toUtc() : null;

    await remoteDataSource.loadSavedSession();
    if (!remoteDataSource.hasRecoverableSession) {
      _cloudSyncEnabled = false;
      _hasSyncedCloud = false;
    }

    _isInitialized = true;
    _publishSnapshot();
  }

  /// Saves nickname locally and syncs to cloud if a recoverable account is
  /// linked and cloud sync is enabled.
  Future<CloudSyncReport?> setUsername(String rawName) async {
    await init();
    final validationError = validateUsername(rawName);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final trimmed = rawName.trim();
    final now = DateTime.now().toUtc();
    _username = trimmed;
    _usernameUpdatedAt = now;

    final prefs = await _prefs();
    await prefs.setString(_usernameKey, trimmed);
    await prefs.setString(_usernameUpdatedAtKey, now.toIso8601String());
    _publishSnapshot();

    if (isCloudSyncEnabled) {
      return syncWithCloud();
    }
    return null;
  }

  /// Sends an email OTP code to link or recover an account.
  Future<void> requestEmailOtp(String rawEmail) async {
    await init();
    final emailError = validateEmail(rawEmail);
    if (emailError != null) {
      throw ArgumentError(emailError);
    }
    if (!remoteDataSource.isConfigured) {
      throw const ServerException(
        'Cloud account linking is unavailable because Supabase is not configured.',
      );
    }
    if (!await networkInfo.isConnected) {
      throw const ServerException(
        'No internet connection. Connect to the internet and try again.',
      );
    }
    await remoteDataSource.sendEmailOtp(rawEmail.trim().toLowerCase());
  }

  /// Verifies the email OTP code, persists the recoverable session in secure
  /// storage, enables cloud sync, and performs a two-way cloud merge sync.
  Future<CloudSyncReport> verifyEmailOtpAndSync({
    required String email,
    required String otpCode,
  }) async {
    await init();
    final emailError = validateEmail(email);
    if (emailError != null) {
      throw ArgumentError(emailError);
    }
    final codeError = validateOtpCode(otpCode);
    if (codeError != null) {
      throw ArgumentError(codeError);
    }
    if (!remoteDataSource.isConfigured) {
      throw const ServerException(
        'Cloud account linking is unavailable because Supabase is not configured.',
      );
    }
    if (!await networkInfo.isConnected) {
      throw const ServerException(
        'No internet connection. Connect to the internet and try again.',
      );
    }

    await remoteDataSource.verifyEmailOtp(
      email: email.trim().toLowerCase(),
      otpCode: otpCode.trim(),
    );

    _cloudSyncEnabled = true;
    final prefs = await _prefs();
    await prefs.setBool(_cloudSyncEnabledKey, true);
    _publishSnapshot();

    return syncWithCloud(force: true);
  }

  /// Toggles cloud backup sync for an already linked recoverable account.
  Future<void> setCloudSyncEnabled(bool enabled) async {
    await init();
    if (enabled && !isRecoverable) {
      throw const ServerException(
        'Link an email account before enabling cloud backup and recovery.',
      );
    }
    _cloudSyncEnabled = enabled;
    final prefs = await _prefs();
    await prefs.setBool(_cloudSyncEnabledKey, enabled);
    if (!enabled) {
      _hasSyncedCloud = false;
    }
    _publishSnapshot();
  }

  /// Signs out of the recoverable cloud account while keeping local SQLite
  /// campaign progress and local nickname on this device.
  Future<void> signOutCloudAccount() async {
    await init();
    await remoteDataSource.signOut();
    _cloudSyncEnabled = false;
    _hasSyncedCloud = false;
    _lastSyncedAt = null;
    final prefs = await _prefs();
    await prefs.setBool(_cloudSyncEnabledKey, false);
    await prefs.remove(_lastSyncedAtKey);
    _publishSnapshot();
  }

  /// Performs a two-way merge sync with Supabase scoped to a verified
  /// recoverable `auth.uid()`. Returns a detailed [CloudSyncReport] and never
  /// fakes success on failure.
  Future<CloudSyncReport> syncWithCloud({bool force = false}) {
    final active = _ongoingSync;
    if (active != null) return active;

    late final Future<CloudSyncReport> syncFuture;
    syncFuture = _performSyncWithCloud(force: force).whenComplete(() {
      if (identical(_ongoingSync, syncFuture)) {
        _ongoingSync = null;
      }
    });
    _ongoingSync = syncFuture;
    return syncFuture;
  }

  Future<CloudSyncReport> _performSyncWithCloud({required bool force}) async {
    try {
      await init();
      if (!remoteDataSource.isConfigured) {
        return CloudSyncReport.failed(
          'Cloud sync is unavailable because Supabase is not configured.',
        );
      }
      if (!isRecoverable) {
        return CloudSyncReport.failed(
          'Link an email account to sync and recover progress across devices.',
        );
      }
      if (!_cloudSyncEnabled && !force) {
        return CloudSyncReport.failed(
          'Cloud progress sync is currently turned off.',
        );
      }
      if (!await networkInfo.isConnected) {
        return CloudSyncReport.failed(
          'No internet connection. Progress remains saved locally.',
        );
      }

      // 1. Fetch & merge profile by updated_at
      final remoteProfile = await remoteDataSource.fetchPlayerProfile();
      final remoteUsernameRaw = remoteProfile?['username'] as String?;
      final remoteUsername =
          (remoteUsernameRaw != null && remoteUsernameRaw.trim().isNotEmpty)
              ? remoteUsernameRaw.trim()
              : null;
      final remoteUpdatedAtRaw = remoteProfile?['updated_at'] as String?;
      final remoteUpdatedAt = remoteUpdatedAtRaw != null
          ? DateTime.tryParse(remoteUpdatedAtRaw)?.toUtc()
          : null;

      bool shouldUploadProfile = false;
      final prefs = await _prefs();

      if (remoteUsername != null) {
        final shouldAdoptRemote = !hasUsername ||
            (remoteUpdatedAt != null &&
                (_usernameUpdatedAt == null ||
                    remoteUpdatedAt.isAfter(_usernameUpdatedAt!)));
        if (shouldAdoptRemote) {
          _username = remoteUsername;
          _usernameUpdatedAt = remoteUpdatedAt ?? DateTime.now().toUtc();
          await prefs.setString(_usernameKey, _username!);
          await prefs.setString(
            _usernameUpdatedAtKey,
            _usernameUpdatedAt!.toIso8601String(),
          );
        } else if (_username != remoteUsername) {
          shouldUploadProfile = true;
        }
      } else if (hasUsername) {
        shouldUploadProfile = true;
      }

      final localTutorial = await tutorialService.hasCompletedTutorial();
      final remoteTutorial =
          (remoteProfile?['tutorial_completed'] as bool?) ?? false;
      final mergedTutorial = localTutorial || remoteTutorial;
      if (mergedTutorial && !localTutorial) {
        await tutorialService.setTutorialCompleted(true);
      }
      if (mergedTutorial != remoteTutorial) {
        shouldUploadProfile = true;
      }

      // 2. Fetch & merge level progress (best stars, min valid moves, unlocked, skipped)
      final localMap = await localDataSource.getAllLevelProgress();
      final remoteRows = await remoteDataSource.fetchCloudLevelProgress();

      final Map<int, Map<String, dynamic>> remoteMap = {};
      for (final row in remoteRows) {
        final id = row['level_id'] as int?;
        if (id != null && id >= 1) {
          remoteMap[id] = row;
        }
      }

      final allIds = <int>{...localMap.keys, ...remoteMap.keys};
      final List<Map<String, dynamic>> toUpload = [];
      int downloadedCount = 0;

      for (final levelId in allIds) {
        final local = localMap[levelId];
        final remote = remoteMap[levelId];

        final localStars = (local?['stars'] as int?) ?? 0;
        final remoteStars = (remote?['stars'] as int?) ?? 0;
        final mergedStars = math.max(localStars, remoteStars);

        final localBestRaw = local?['best_moves'] as int?;
        final remoteBestRaw = remote?['best_moves'] as int?;
        final localBest =
            (localBestRaw != null && localBestRaw > 0) ? localBestRaw : null;
        final remoteBest =
            (remoteBestRaw != null && remoteBestRaw > 0) ? remoteBestRaw : null;
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

        final localSkipped = (local?['is_skipped'] as int? ?? 0) == 1;
        final remoteSkipped = (remote?['is_skipped'] as bool?) ?? false;
        final mergedSkipped =
            mergedStars > 0 ? false : (localSkipped || remoteSkipped);

        final difficulty = _normalizeDifficulty(
          (local?['difficulty'] as String?) ??
              (remote?['difficulty'] as String?),
        );

        final localUpdatedAt = _parseUtc(local?['updated_at'] as String?);
        final remoteUpdatedAtRow = _parseUtc(remote?['updated_at'] as String?);
        final latestUpdatedAt = _maxDate(localUpdatedAt, remoteUpdatedAtRow) ??
            DateTime.now().toUtc();

        if (local == null ||
            mergedStars != localStars ||
            mergedBest != localBest ||
            mergedUnlocked != localUnlocked ||
            mergedSkipped != localSkipped) {
          await localDataSource.upsertLevelProgress(
            levelId: levelId,
            difficulty: difficulty,
            bestMoves: mergedBest,
            stars: mergedStars,
            isUnlocked: mergedUnlocked,
            isSkipped: mergedSkipped,
          );
          downloadedCount++;
        }

        if (remote == null ||
            mergedStars != remoteStars ||
            mergedBest != remoteBest ||
            mergedUnlocked != remoteUnlocked ||
            mergedSkipped != remoteSkipped) {
          toUpload.add({
            'level_id': levelId,
            'difficulty': difficulty,
            'best_moves': mergedBest,
            'stars': mergedStars,
            'is_unlocked': mergedUnlocked,
            'is_skipped': mergedSkipped,
            'updated_at': latestUpdatedAt.toIso8601String(),
          });
        }
      }

      // Ensure parent player_profiles row exists before uploading child rows.
      if (remoteProfile == null && (hasUsername || toUpload.isNotEmpty)) {
        shouldUploadProfile = true;
      }

      if (shouldUploadProfile) {
        final effectiveName = hasUsername ? _username!.trim() : 'Driver';
        await remoteDataSource.upsertPlayerProfile(
          username: effectiveName,
          tutorialCompleted: mergedTutorial,
          updatedAt: _usernameUpdatedAt ?? DateTime.now().toUtc(),
        );
      }

      if (toUpload.isNotEmpty) {
        await remoteDataSource.upsertCloudLevelProgressBatch(toUpload);
      }

      final now = DateTime.now().toUtc();
      _hasSyncedCloud = true;
      _lastSyncedAt = now;
      await prefs.setString(_lastSyncedAtKey, now.toIso8601String());
      _publishSnapshot();

      return CloudSyncReport.succeeded(
        uploadedCount: toUpload.length,
        downloadedCount: downloadedCount,
        syncedAt: now,
      );
    } on ServerException catch (e) {
      _hasSyncedCloud = false;
      _publishSnapshot();
      return CloudSyncReport.failed(e.message);
    } catch (_) {
      _hasSyncedCloud = false;
      _publishSnapshot();
      return CloudSyncReport.failed(
        'Cloud sync failed. Your progress remains saved locally.',
      );
    }
  }

  static String _normalizeDifficulty(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'medium':
        return 'medium';
      case 'hard':
        return 'hard';
      default:
        return 'easy';
    }
  }

  static DateTime? _parseUtc(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  static DateTime? _maxDate(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  void dispose() {
    snapshotNotifier.dispose();
  }
}

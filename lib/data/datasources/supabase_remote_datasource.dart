import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/error/exceptions.dart';
import '../../domain/entities/move.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../models/daily_challenge_model.dart';
import '../models/score_model.dart';

class UserDailySubmission {
  final String playerName;
  final int movesCount;

  const UserDailySubmission({
    required this.playerName,
    required this.movesCount,
  });
}

abstract class SecureTokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureTokenStore implements SecureTokenStore {
  final FlutterSecureStorage _storage;

  const FlutterSecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on MissingPluginException {
      // Platform plugin unavailable in headless test environments.
    } on PlatformException {
      // Ignore secure storage write failure gracefully; session remains in memory.
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      // Platform plugin unavailable in headless test environments.
    } on PlatformException {
      // Ignore secure storage delete failure gracefully.
    }
  }
}

class SupabaseSession {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final DateTime expiresAt;
  final String? email;
  final bool isAnonymous;

  const SupabaseSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.expiresAt,
    this.email,
    this.isAnonymous = true,
  });

  bool get isRecoverable =>
      !isAnonymous && email != null && email!.trim().isNotEmpty;

  bool get isExpired => DateTime.now()
      .toUtc()
      .isAfter(expiresAt.subtract(const Duration(seconds: 60)));

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'user_id': userId,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'email': email,
        'is_anonymous': isAnonymous,
      };

  factory SupabaseSession.fromJson(Map<String, dynamic> json) {
    final access = json['access_token'] as String?;
    final refresh = json['refresh_token'] as String?;
    final uid = json['user_id'] as String?;
    final expiresRaw = json['expires_at'] as String?;
    final expires = expiresRaw != null ? DateTime.tryParse(expiresRaw) : null;
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty ||
        uid == null ||
        uid.isEmpty ||
        expires == null) {
      throw const FormatException('Incomplete persisted Supabase session.');
    }
    return SupabaseSession(
      accessToken: access,
      refreshToken: refresh,
      userId: uid,
      expiresAt: expires.toUtc(),
      email: json['email'] as String?,
      isAnonymous: (json['is_anonymous'] as bool?) ?? true,
    );
  }
}

class SupabaseRemoteDataSource {
  static const String _envDefinedUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envDefinedAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String _secureSessionKey = 'rush_out_sb_session_v2';
  static const int defaultSyncBatchSize = 250;
  static const int defaultProgressPageSize = 1000;

  final Dio _dio;
  final String? _overrideUrl;
  final String? _overrideAnonKey;
  final SecureTokenStore _tokenStore;

  SupabaseSession? _session;
  bool _sessionLoaded = false;
  Future<SupabaseSession>? _ongoingAuth;

  SupabaseRemoteDataSource({
    Dio? dio,
    String? supabaseUrl,
    String? supabaseAnonKey,
    SecureTokenStore? tokenStore,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 12),
                sendTimeout: const Duration(seconds: 12),
              ),
            ),
        _overrideUrl = supabaseUrl,
        _overrideAnonKey = supabaseAnonKey,
        _tokenStore = tokenStore ?? const FlutterSecureTokenStore();

  SupabaseSession? get currentSession => _session;
  String? get currentUserId => _session?.userId;
  String? get currentUserEmail => _session?.email;
  bool get hasRecoverableSession => _session?.isRecoverable ?? false;

  String get _baseUrl {
    final fromDefine = _envDefinedUrl.trim();
    final raw = _overrideUrl ??
        (fromDefine.isNotEmpty
            ? fromDefine
            : (dotenv.isInitialized ? dotenv.env['SUPABASE_URL'] : null)) ??
        '';
    return raw.trim().replaceAll(RegExp(r'/$'), '');
  }

  String get _anonKey {
    final fromDefine = _envDefinedAnonKey.trim();
    final raw = _overrideAnonKey ??
        (fromDefine.isNotEmpty
            ? fromDefine
            : (dotenv.isInitialized ? dotenv.env['SUPABASE_ANON_KEY'] : null)) ??
        '';
    return raw.trim();
  }

  bool get isConfigured {
    final url = _baseUrl;
    final key = _anonKey;
    return url.isNotEmpty &&
        url.startsWith('http') &&
        !url.contains('your-project-id') &&
        key.isNotEmpty &&
        !key.contains('your-supabase-anon');
  }

  Map<String, String> get _anonHeaders => {
        'apikey': _anonKey,
        'Authorization': 'Bearer $_anonKey',
        'Content-Type': 'application/json',
      };

  Map<String, String> _authHeaders(String accessToken) => {
        'apikey': _anonKey,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const ServerException(
        'Supabase is not configured. Please provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define or .env.',
      );
    }
  }

  Future<SupabaseSession?> loadSavedSession() async {
    if (_session != null) return _session;
    if (_sessionLoaded) return null;
    _sessionLoaded = true;

    try {
      final raw = await _tokenStore.read(_secureSessionKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _session = SupabaseSession.fromJson(decoded);
      }
    } catch (_) {
      await _tokenStore.delete(_secureSessionKey);
      _session = null;
    }
    return _session;
  }

  Future<void> _persistSession(SupabaseSession session) async {
    _session = session;
    _sessionLoaded = true;
    await _tokenStore.write(_secureSessionKey, jsonEncode(session.toJson()));
  }

  Future<void> _clearSession() async {
    _session = null;
    _sessionLoaded = true;
    await _tokenStore.delete(_secureSessionKey);
  }

  SupabaseSession _parseAuthResponse(
    dynamic data, {
    String? fallbackEmail,
    bool? fallbackIsAnonymous,
  }) {
    if (data is! Map<String, dynamic>) {
      throw const ServerException('Invalid authentication response from server.');
    }
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
    final user = data['user'];
    final userMap = user is Map<String, dynamic> ? user : null;
    final uid = userMap?['id'] as String?;
    final rawEmail = userMap?['email'] as String?;
    final email = (rawEmail != null && rawEmail.trim().isNotEmpty)
        ? rawEmail.trim()
        : fallbackEmail;
    final isAnon = (userMap?['is_anonymous'] as bool?) ??
        fallbackIsAnonymous ??
        (email == null || email.isEmpty);

    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty ||
        uid == null ||
        uid.isEmpty) {
      throw const ServerException(
        'Authentication provider returned incomplete credentials.',
      );
    }

    return SupabaseSession(
      accessToken: access,
      refreshToken: refresh,
      userId: uid,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      email: email,
      isAnonymous: isAnon,
    );
  }

  /// Sends a 6-digit passwordless OTP code to [email] for recoverable sign-in.
  Future<void> sendEmailOtp(String email) async {
    _ensureConfigured();
    final normalized = email.trim().toLowerCase();
    try {
      await _dio.post<dynamic>(
        '$_baseUrl/auth/v1/otp',
        data: {
          'email': normalized,
          'create_user': true,
        },
        options: Options(headers: {
          'apikey': _anonKey,
          'Content-Type': 'application/json',
        }),
      );
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to send verification code'),
      );
    }
  }

  /// Verifies the [otpCode] sent to [email] and stores a recoverable session in
  /// secure storage.
  Future<SupabaseSession> verifyEmailOtp({
    required String email,
    required String otpCode,
  }) async {
    _ensureConfigured();
    final normalized = email.trim().toLowerCase();
    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/auth/v1/verify',
        data: {
          'email': normalized,
          'token': otpCode.trim(),
          'type': 'email',
        },
        options: Options(headers: {
          'apikey': _anonKey,
          'Content-Type': 'application/json',
        }),
      );
      final session = _parseAuthResponse(
        response.data,
        fallbackEmail: normalized,
        fallbackIsAnonymous: false,
      );
      await _persistSession(session);
      return session;
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Verification failed'),
      );
    }
  }

  /// Signs out of the current session and clears tokens from secure storage.
  Future<void> signOut() async {
    await loadSavedSession();
    final current = _session;
    if (current != null && isConfigured) {
      try {
        await _dio.post<dynamic>(
          '$_baseUrl/auth/v1/logout',
          options: Options(headers: _authHeaders(current.accessToken)),
        );
      } catch (_) {
        // Best-effort remote revoke; local secure storage is always cleared.
      }
    }
    await _clearSession();
  }

  Future<SupabaseSession> _refreshSession(SupabaseSession current) async {
    final response = await _dio.post<dynamic>(
      '$_baseUrl/auth/v1/token',
      queryParameters: {'grant_type': 'refresh_token'},
      data: {'refresh_token': current.refreshToken},
      options: Options(headers: {
        'apikey': _anonKey,
        'Content-Type': 'application/json',
      }),
    );
    final refreshed = _parseAuthResponse(
      response.data,
      fallbackEmail: current.email,
      fallbackIsAnonymous: current.isAnonymous,
    );
    await _persistSession(refreshed);
    return refreshed;
  }

  /// Ensures a valid recoverable (email-authenticated) session for cloud backup
  /// and cross-device recovery.
  Future<SupabaseSession> requireRecoverableSession({
    bool forceRefresh = false,
  }) async {
    _ensureConfigured();
    await loadSavedSession();

    final current = _session;
    if (current == null || !current.isRecoverable) {
      throw const ServerException(
        'Sign in with your email account to enable cloud backup and recovery.',
      );
    }
    if (!forceRefresh && !current.isExpired) {
      return current;
    }
    try {
      return await _refreshSession(current);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 400 || status == 401 || status == 403) {
        await _clearSession();
        throw const ServerException(
          'Your cloud session has expired. Please sign in with your email again.',
        );
      }
      throw ServerException(
        _formatDioError(e, 'Failed to refresh your cloud session'),
      );
    }
  }

  /// Ensures an authenticated session (reusing any active recoverable session,
  /// or creating an anonymous session for Daily Challenge submission).
  Future<SupabaseSession> ensureAuthenticatedSession({
    bool forceRefresh = false,
  }) async {
    _ensureConfigured();
    final inflight = _ongoingAuth;
    if (inflight != null) return inflight;

    late final Future<SupabaseSession> authFuture;
    authFuture = _authenticate(forceRefresh: forceRefresh).whenComplete(() {
      if (identical(_ongoingAuth, authFuture)) {
        _ongoingAuth = null;
      }
    });
    _ongoingAuth = authFuture;
    return authFuture;
  }

  Future<SupabaseSession> _authenticate({required bool forceRefresh}) async {
    await loadSavedSession();

    final current = _session;
    if (current != null && !forceRefresh && !current.isExpired) {
      return current;
    }

    if (current != null && current.refreshToken.isNotEmpty) {
      try {
        return await _refreshSession(current);
      } on DioException catch (e) {
        final status = e.response?.statusCode ?? 0;
        if (status != 400 && status != 401 && status != 403) {
          throw ServerException(
            _formatDioError(e, 'Failed to refresh player session'),
          );
        }
        await _clearSession();
      }
    }

    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/auth/v1/signup',
        data: const <String, dynamic>{},
        options: Options(headers: {
          'apikey': _anonKey,
          'Content-Type': 'application/json',
        }),
      );
      final session = _parseAuthResponse(
        response.data,
        fallbackIsAnonymous: true,
      );
      await _persistSession(session);
      return session;
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to create anonymous player session'),
      );
    }
  }

  Future<T> _runAuthenticated<T>(
    Future<T> Function(SupabaseSession session) action,
  ) async {
    final session = await ensureAuthenticatedSession();
    try {
      return await action(session);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final refreshed = await ensureAuthenticatedSession(forceRefresh: true);
        return await action(refreshed);
      }
      rethrow;
    }
  }

  Future<T> _runRecoverableAuthenticated<T>(
    Future<T> Function(SupabaseSession session) action,
  ) async {
    final session = await requireRecoverableSession();
    try {
      return await action(session);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final refreshed = await requireRecoverableSession(forceRefresh: true);
        return await action(refreshed);
      }
      rethrow;
    }
  }

  /// GET /rest/v1/daily_challenges?challenge_date=eq.{YYYY-MM-DD}&select=*
  Future<DailyChallengeModel?> fetchDailyChallenge(String dateKey) async {
    _ensureConfigured();
    try {
      final response = await _dio.get<dynamic>(
        '$_baseUrl/rest/v1/daily_challenges',
        queryParameters: {
          'challenge_date': 'eq.$dateKey',
          'select': '*',
        },
        options: Options(headers: _anonHeaders),
      );

      final data = response.data;
      if (data is List) {
        if (data.isEmpty) {
          return null;
        }
        final first = data.first;
        if (first is Map<String, dynamic>) {
          return DailyChallengeModel.fromSupabaseJson(first);
        }
      }
      return null;
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to fetch Daily Challenge'),
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Unexpected error loading Daily Challenge: $e');
    }
  }

  /// GET /rest/v1/leaderboard_scores?challenge_date=eq.{YYYY-MM-DD}&order=moves_count.asc,created_at.asc&limit={limit}&offset={offset}
  Future<List<ScoreModel>> fetchLeaderboard(
    String challengeDate, {
    int limit = 20,
    int offset = 0,
  }) async {
    _ensureConfigured();
    final safeLimit = limit.clamp(1, 100);
    final safeOffset = offset < 0 ? 0 : offset;
    try {
      Response<dynamic> response;
      try {
        response = await _dio.get<dynamic>(
          '$_baseUrl/rest/v1/leaderboard_scores',
          queryParameters: {
            'challenge_date': 'eq.$challengeDate',
            'select':
                'id,user_id,player_name,challenge_date,moves_count,created_at',
            'order': 'moves_count.asc,created_at.asc',
            'limit': '$safeLimit',
            'offset': '$safeOffset',
          },
          options: Options(headers: _anonHeaders),
        );
      } on DioException catch (inner) {
        if (inner.response?.statusCode == 404) {
          response = await _dio.get<dynamic>(
            '$_baseUrl/rest/v1/leaderboard',
            queryParameters: {
              'challenge_date': 'eq.$challengeDate',
              'select': 'id,player_name,challenge_date,moves_count,created_at',
              'order': 'moves_count.asc,created_at.asc',
              'limit': '$safeLimit',
              'offset': '$safeOffset',
            },
            options: Options(headers: _anonHeaders),
          );
        } else {
          rethrow;
        }
      }

      final data = response.data;
      if (data is! List) {
        throw const ServerException('Invalid leaderboard response from server.');
      }
      final scores = <ScoreModel>[];
      for (final item in data) {
        if (item is! Map<String, dynamic>) {
          throw const ServerException('Invalid leaderboard entry format.');
        }
        scores.add(ScoreModel.fromJson(item));
      }
      return scores;
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to load Leaderboard scores'),
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const ServerException('Unexpected error loading Leaderboard scores.');
    }
  }

  /// Queries the authenticated player's submitted score and exact 1-based rank
  /// for [challengeDate]. Returns `null` if there is no active session or the
  /// player has not submitted a score for that UTC date.
  Future<PlayerLeaderboardRank?> fetchPlayerLeaderboardRank(
    String challengeDate,
  ) async {
    if (!isConfigured) return null;
    await loadSavedSession();
    final session = _session;
    if (session == null) return null;

    final headers = session.isExpired
        ? _anonHeaders
        : _authHeaders(session.accessToken);

    try {
      final rowResponse = await _dio.get<dynamic>(
        '$_baseUrl/rest/v1/leaderboard_scores',
        queryParameters: {
          'user_id': 'eq.${session.userId}',
          'challenge_date': 'eq.$challengeDate',
          'select':
              'id,user_id,player_name,challenge_date,moves_count,created_at',
          'limit': '1',
        },
        options: Options(headers: headers),
      );

      final rowData = rowResponse.data;
      if (rowData is! List || rowData.isEmpty) {
        return null;
      }
      final first = rowData.first;
      if (first is! Map<String, dynamic>) {
        throw const ServerException('Invalid player rank record format.');
      }
      final myEntry = ScoreModel.fromJson(first);

      final aheadQuery = <String, dynamic>{
        'challenge_date': 'eq.$challengeDate',
        'select': 'id',
        'limit': '1',
      };
      if (myEntry.createdAt != null) {
        final ts = myEntry.createdAt!.toUtc().toIso8601String();
        aheadQuery['or'] =
            '(moves_count.lt.${myEntry.movesCount},and(moves_count.eq.${myEntry.movesCount},created_at.lt.$ts))';
      } else {
        aheadQuery['moves_count'] = 'lt.${myEntry.movesCount}';
      }

      final countResponse = await _dio.get<dynamic>(
        '$_baseUrl/rest/v1/leaderboard_scores',
        queryParameters: aheadQuery,
        options: Options(
          headers: {
            ...headers,
            'Prefer': 'count=exact',
          },
        ),
      );

      final aheadCount = _parseTotalFromContentRange(
        countResponse.headers.value('content-range'),
      );
      if (aheadCount == null) {
        return null;
      }

      return PlayerLeaderboardRank(
        rank: aheadCount + 1,
        entry: myEntry,
      );
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to load player rank'),
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const ServerException('Unexpected error loading player rank.');
    }
  }

  static int? _parseTotalFromContentRange(String? header) {
    if (header == null || header.trim().isEmpty) return null;
    final slashIndex = header.lastIndexOf('/');
    if (slashIndex == -1 || slashIndex == header.length - 1) return null;
    final totalStr = header.substring(slashIndex + 1).trim();
    if (totalStr == '*') return null;
    final parsed = int.tryParse(totalStr);
    return (parsed != null && parsed >= 0) ? parsed : null;
  }

  /// Queries whether the currently authenticated `auth.uid()` has already
  /// submitted a Daily Challenge score for [dateKey].
  /// Returns `null` when no local session exists yet or no score is found.
  Future<UserDailySubmission?> fetchUserDailySubmission(String dateKey) async {
    if (!isConfigured) return null;
    await loadSavedSession();
    if (_session == null) return null;

    try {
      return await _runAuthenticated((session) async {
        final response = await _dio.get<dynamic>(
          '$_baseUrl/rest/v1/leaderboard_scores',
          queryParameters: {
            'user_id': 'eq.${session.userId}',
            'challenge_date': 'eq.$dateKey',
            'select': 'player_name,moves_count',
            'limit': '1',
          },
          options: Options(headers: _authHeaders(session.accessToken)),
        );
        final data = response.data;
        if (data is List && data.isNotEmpty) {
          final first = data.first;
          if (first is Map<String, dynamic>) {
            final name = (first['player_name'] as String?)?.trim() ?? '';
            final moves = (first['moves_count'] as num?)?.toInt();
            if (moves != null && moves > 0) {
              return UserDailySubmission(
                playerName: name,
                movesCount: moves,
              );
            }
          }
        }
        return null;
      });
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to check Daily Challenge submission status'),
      );
    }
  }

  /// POST /rest/v1/rpc/submit_daily_score with server-verified `p_moves` replay.
  Future<void> submitVerifiedScore({
    required String playerName,
    required String challengeDate,
    required List<Move> moveHistory,
  }) async {
    _ensureConfigured();
    if (moveHistory.isEmpty) {
      throw const ServerException(
        'Verified move history is required to submit a Daily Challenge score.',
      );
    }

    final pMoves = moveHistory.map((m) {
      final isHorizontalMove = m.deltaCol != 0 && m.deltaRow == 0;
      final isVerticalMove = m.deltaRow != 0 && m.deltaCol == 0;
      if (!isHorizontalMove && !isVerticalMove) {
        throw const ServerException(
          'Cannot submit score: move history contains an invalid diagonal or zero-step move.',
        );
      }
      return <String, dynamic>{
        'vehicle_id': m.vehicleId,
        'steps': isHorizontalMove ? m.deltaCol : m.deltaRow,
        'axis': isHorizontalMove ? 'h' : 'v',
      };
    }).toList(growable: false);

    try {
      await _runAuthenticated((session) async {
        await _dio.post<dynamic>(
          '$_baseUrl/rest/v1/rpc/submit_daily_score',
          data: {
            'p_player_name': playerName.trim(),
            'p_challenge_date': challengeDate,
            'p_moves': pMoves,
          },
          options: Options(headers: _authHeaders(session.accessToken)),
        );
      });
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to submit score to Leaderboard'),
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Unexpected error submitting score: $e');
    }
  }

  /// Legacy entrypoint retained for repository compatibility; enforces verified
  /// [moveHistory] and refuses unverified score-only submissions.
  Future<void> submitScore(
    ScoreModel score, {
    List<Move>? moveHistory,
  }) async {
    if (moveHistory == null || moveHistory.isEmpty) {
      throw const ServerException(
        'Verified move history is required to submit a Daily Challenge score.',
      );
    }
    return submitVerifiedScore(
      playerName: score.playerName,
      challengeDate: score.challengeDate,
      moveHistory: moveHistory,
    );
  }

  /// GET /rest/v1/player_profiles?user_id=eq.{auth.uid()}
  Future<Map<String, dynamic>?> fetchPlayerProfile() async {
    _ensureConfigured();
    try {
      return await _runRecoverableAuthenticated((session) async {
        final response = await _dio.get<dynamic>(
          '$_baseUrl/rest/v1/player_profiles',
          queryParameters: {
            'user_id': 'eq.${session.userId}',
            'select': '*',
          },
          options: Options(headers: _authHeaders(session.accessToken)),
        );
        final data = response.data;
        if (data is List &&
            data.isNotEmpty &&
            data.first is Map<String, dynamic>) {
          return Map<String, dynamic>.from(data.first as Map<String, dynamic>);
        }
        return null;
      });
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to fetch player profile'),
      );
    }
  }

  /// POST /rest/v1/player_profiles?on_conflict=user_id
  Future<void> upsertPlayerProfile({
    required String username,
    required bool tutorialCompleted,
    DateTime? updatedAt,
  }) async {
    _ensureConfigured();
    try {
      await _runRecoverableAuthenticated((session) async {
        await _dio.post<dynamic>(
          '$_baseUrl/rest/v1/player_profiles',
          queryParameters: {'on_conflict': 'user_id'},
          data: {
            'user_id': session.userId,
            'username': username,
            'tutorial_completed': tutorialCompleted,
            'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
          },
          options: Options(
            headers: {
              ..._authHeaders(session.accessToken),
              'Prefer': 'resolution=merge-duplicates,return=minimal',
            },
          ),
        );
      });
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to save player profile'),
      );
    }
  }

  /// Paginated fetch of all cloud level progress rows for the authenticated
  /// recoverable user (handles 4,050+ levels past PostgREST's 1,000-row cap).
  Future<List<Map<String, dynamic>>> fetchCloudLevelProgress({
    int pageSize = defaultProgressPageSize,
  }) async {
    _ensureConfigured();
    final safePageSize = pageSize.clamp(100, 1000);
    try {
      return await _runRecoverableAuthenticated((session) async {
        final List<Map<String, dynamic>> allRows = [];
        int offset = 0;

        while (true) {
          final response = await _dio.get<dynamic>(
            '$_baseUrl/rest/v1/player_level_progress',
            queryParameters: {
              'user_id': 'eq.${session.userId}',
              'select':
                  'level_id,difficulty,best_moves,stars,is_unlocked,is_skipped,updated_at',
              'order': 'level_id.asc',
              'limit': '$safePageSize',
              'offset': '$offset',
            },
            options: Options(headers: _authHeaders(session.accessToken)),
          );
          final data = response.data;
          if (data is! List || data.isEmpty) {
            break;
          }
          final page = data.whereType<Map<String, dynamic>>().toList();
          allRows.addAll(page);
          if (page.length < safePageSize) {
            break;
          }
          offset += page.length;
        }

        return allRows;
      });
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to fetch cloud level progress'),
      );
    }
  }

  /// Chunked upsert of level progress rows (200–500 rows per request) so
  /// syncing 4,050 levels does not hit payload or timeout limits.
  Future<void> upsertCloudLevelProgressBatch(
    List<Map<String, dynamic>> rows, {
    int chunkSize = defaultSyncBatchSize,
  }) async {
    if (rows.isEmpty) return;
    _ensureConfigured();
    final safeChunkSize = chunkSize.clamp(1, 500);
    try {
      await _runRecoverableAuthenticated((session) async {
        for (int i = 0; i < rows.length; i += safeChunkSize) {
          final end = (i + safeChunkSize < rows.length)
              ? i + safeChunkSize
              : rows.length;
          final chunk = rows.sublist(i, end).map((r) {
            return {
              ...r,
              'user_id': session.userId,
            };
          }).toList();

          await _dio.post<dynamic>(
            '$_baseUrl/rest/v1/player_level_progress',
            queryParameters: {'on_conflict': 'user_id,level_id'},
            data: chunk,
            options: Options(
              headers: {
                ..._authHeaders(session.accessToken),
                'Prefer': 'resolution=merge-duplicates,return=minimal',
              },
            ),
          );
        }
      });
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to sync level progress'),
      );
    }
  }

  /// Legacy helper retained strictly for pre-Wave-5 test compatibility.
  @Deprecated('Use fetchPlayerProfile for recoverable cloud accounts.')
  Future<Map<String, dynamic>?> fetchDeviceProfile(String deviceId) async {
    _ensureConfigured();
    try {
      return await _runAuthenticated((session) async {
        final response = await _dio.get<dynamic>(
          '$_baseUrl/rest/v1/device_profiles',
          queryParameters: {
            'user_id': 'eq.${session.userId}',
            'select': '*',
          },
          options: Options(headers: _authHeaders(session.accessToken)),
        );
        final data = response.data;
        if (data is List &&
            data.isNotEmpty &&
            data.first is Map<String, dynamic>) {
          return Map<String, dynamic>.from(data.first as Map<String, dynamic>);
        }
        return null;
      });
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to fetch player profile'),
      );
    }
  }

  String _formatDioError(DioException e, String prefix) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Network connection error. Please check your internet and try again.';
    }
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final serverMessage = data['error_description'] as String? ??
          data['message'] as String? ??
          data['msg'] as String? ??
          data['error'] as String?;
      if (serverMessage != null && serverMessage.trim().isNotEmpty) {
        return serverMessage.trim();
      }
    }
    final status = e.response?.statusCode;
    return '$prefix${status != null ? ' (HTTP $status)' : ''}.';
  }
}

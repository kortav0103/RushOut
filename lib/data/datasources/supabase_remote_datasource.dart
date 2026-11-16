import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/error/exceptions.dart';
import '../models/daily_challenge_model.dart';
import '../models/score_model.dart';

class SupabaseSession {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final DateTime expiresAt;

  const SupabaseSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.expiresAt,
  });

  bool get isExpired =>
      DateTime.now().toUtc().isAfter(expiresAt.subtract(const Duration(seconds: 60)));
}

class SupabaseRemoteDataSource {
  static const String _envDefinedUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envDefinedAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String _accessTokenKey = 'rush_out_sb_access_token';
  static const String _refreshTokenKey = 'rush_out_sb_refresh_token';
  static const String _userIdKey = 'rush_out_sb_user_id';
  static const String _expiresAtKey = 'rush_out_sb_expires_at';

  final Dio _dio;
  final String? _overrideUrl;
  final String? _overrideAnonKey;
  final Future<SharedPreferences> Function()? _prefsProvider;

  SupabaseSession? _session;
  Future<SupabaseSession>? _ongoingAuth;

  SupabaseRemoteDataSource({
    Dio? dio,
    String? supabaseUrl,
    String? supabaseAnonKey,
    Future<SharedPreferences> Function()? prefsProvider,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                sendTimeout: const Duration(seconds: 8),
              ),
            ),
        _overrideUrl = supabaseUrl,
        _overrideAnonKey = supabaseAnonKey,
        _prefsProvider = prefsProvider;

  String? get currentUserId => _session?.userId;

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

  Future<SharedPreferences> _prefs() =>
      _prefsProvider?.call() ?? SharedPreferences.getInstance();

  Future<void> _loadPersistedSession() async {
    if (_session != null) return;
    try {
      final prefs = await _prefs();
      final access = prefs.getString(_accessTokenKey);
      final refresh = prefs.getString(_refreshTokenKey);
      final uid = prefs.getString(_userIdKey);
      final expiresRaw = prefs.getString(_expiresAtKey);
      final expires = expiresRaw != null ? DateTime.tryParse(expiresRaw) : null;
      if (access != null &&
          access.isNotEmpty &&
          refresh != null &&
          refresh.isNotEmpty &&
          uid != null &&
          uid.isNotEmpty &&
          expires != null) {
        _session = SupabaseSession(
          accessToken: access,
          refreshToken: refresh,
          userId: uid,
          expiresAt: expires.toUtc(),
        );
      }
    } catch (_) {}
  }

  Future<void> _persistSession(SupabaseSession session) async {
    _session = session;
    try {
      final prefs = await _prefs();
      await prefs.setString(_accessTokenKey, session.accessToken);
      await prefs.setString(_refreshTokenKey, session.refreshToken);
      await prefs.setString(_userIdKey, session.userId);
      await prefs.setString(_expiresAtKey, session.expiresAt.toIso8601String());
    } catch (_) {}
  }

  Future<void> _clearSession() async {
    _session = null;
    try {
      final prefs = await _prefs();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_expiresAtKey);
    } catch (_) {}
  }

  SupabaseSession _parseAuthResponse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw const ServerException('Invalid authentication response from Supabase.');
    }
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
    final user = data['user'];
    final uid = user is Map<String, dynamic> ? user['id'] as String? : null;

    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty ||
        uid == null ||
        uid.isEmpty) {
      throw const ServerException(
        'Anonymous authentication is not enabled or returned incomplete credentials.',
      );
    }

    return SupabaseSession(
      accessToken: access,
      refreshToken: refresh,
      userId: uid,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }

  /// Ensures a valid Supabase Anonymous Auth session (`auth.uid()`).
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
    await _loadPersistedSession();

    final current = _session;
    if (current != null && !forceRefresh && !current.isExpired) {
      return current;
    }

    if (current != null && current.refreshToken.isNotEmpty) {
      try {
        final response = await _dio.post<dynamic>(
          '$_baseUrl/auth/v1/token',
          queryParameters: {'grant_type': 'refresh_token'},
          data: {'refresh_token': current.refreshToken},
          options: Options(headers: {
            'apikey': _anonKey,
            'Content-Type': 'application/json',
          }),
        );
        final refreshed = _parseAuthResponse(response.data);
        await _persistSession(refreshed);
        return refreshed;
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
      final session = _parseAuthResponse(response.data);
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

  /// GET /rest/v1/leaderboard_scores?challenge_date=eq.{YYYY-MM-DD}&order=moves_count.asc&limit=20
  Future<List<ScoreModel>> fetchLeaderboard(String challengeDate) async {
    _ensureConfigured();
    try {
      Response<dynamic> response;
      try {
        response = await _dio.get<dynamic>(
          '$_baseUrl/rest/v1/leaderboard_scores',
          queryParameters: {
            'challenge_date': 'eq.$challengeDate',
            'order': 'moves_count.asc,created_at.asc',
            'limit': '20',
          },
          options: Options(headers: _anonHeaders),
        );
      } on DioException catch (inner) {
        if (inner.response?.statusCode == 404) {
          response = await _dio.get<dynamic>(
            '$_baseUrl/rest/v1/leaderboard',
            queryParameters: {
              'challenge_date': 'eq.$challengeDate',
              'order': 'moves_count.asc',
              'limit': '20',
            },
            options: Options(headers: _anonHeaders),
          );
        } else {
          rethrow;
        }
      }

      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(ScoreModel.fromJson)
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to load Leaderboard scores'),
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Unexpected error loading Leaderboard: $e');
    }
  }

  /// POST /rest/v1/rpc/submit_daily_score (authenticated via Anonymous Auth)
  Future<void> submitScore(ScoreModel score) async {
    _ensureConfigured();
    try {
      await _runAuthenticated((session) async {
        await _dio.post<dynamic>(
          '$_baseUrl/rest/v1/rpc/submit_daily_score',
          data: {
            'p_player_name': score.playerName,
            'p_challenge_date': score.challengeDate,
            'p_moves_count': score.movesCount,
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

  /// GET /rest/v1/device_profiles?user_id=eq.{auth.uid()}
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

  /// POST /rest/v1/device_profiles?on_conflict=user_id
  Future<void> upsertDeviceProfile({
    required String deviceId,
    required String username,
    required bool tutorialCompleted,
  }) async {
    _ensureConfigured();
    try {
      await _runAuthenticated((session) async {
        await _dio.post<dynamic>(
          '$_baseUrl/rest/v1/device_profiles',
          queryParameters: {'on_conflict': 'user_id'},
          data: {
            'user_id': session.userId,
            'device_id': deviceId,
            'username': username,
            'tutorial_completed': tutorialCompleted,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
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

  /// GET /rest/v1/device_level_progress?user_id=eq.{auth.uid()}
  Future<List<Map<String, dynamic>>> fetchDeviceLevelProgress(
    String deviceId,
  ) async {
    _ensureConfigured();
    try {
      return await _runAuthenticated((session) async {
        final response = await _dio.get<dynamic>(
          '$_baseUrl/rest/v1/device_level_progress',
          queryParameters: {
            'user_id': 'eq.${session.userId}',
            'select': 'level_id,difficulty,best_moves,stars,is_unlocked',
          },
          options: Options(headers: _authHeaders(session.accessToken)),
        );
        final data = response.data;
        if (data is List) {
          return data.whereType<Map<String, dynamic>>().toList();
        }
        return const [];
      });
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to fetch cloud level progress'),
      );
    }
  }

  /// POST /rest/v1/device_level_progress?on_conflict=user_id,level_id
  Future<void> upsertDeviceLevelProgressBatch(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;
    _ensureConfigured();
    try {
      await _runAuthenticated((session) async {
        final scopedRows = rows
            .map((r) => {
                  ...r,
                  'user_id': session.userId,
                })
            .toList();
        await _dio.post<dynamic>(
          '$_baseUrl/rest/v1/device_level_progress',
          queryParameters: {'on_conflict': 'user_id,level_id'},
          data: scopedRows,
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
        _formatDioError(e, 'Failed to sync level progress'),
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
      final serverMessage = data['message'] as String? ?? data['msg'] as String?;
      if (serverMessage != null && serverMessage.trim().isNotEmpty) {
        return serverMessage.trim();
      }
    }
    final status = e.response?.statusCode;
    return '$prefix${status != null ? ' (HTTP $status)' : ''}.';
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/error/exceptions.dart';
import '../models/score_model.dart';

class SupabaseRemoteDataSource {
  final Dio _dio;
  final String? _overrideUrl;
  final String? _overrideAnonKey;

  SupabaseRemoteDataSource({
    Dio? dio,
    String? supabaseUrl,
    String? supabaseAnonKey,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                sendTimeout: const Duration(seconds: 8),
              ),
            ),
        _overrideUrl = supabaseUrl,
        _overrideAnonKey = supabaseAnonKey;

  String get _baseUrl {
    final raw = _overrideUrl ?? (dotenv.isInitialized ? dotenv.env['SUPABASE_URL'] : null) ?? '';
    return raw.trim().replaceAll(RegExp(r'/$'), '');
  }

  String get _anonKey {
    final raw =
        _overrideAnonKey ?? (dotenv.isInitialized ? dotenv.env['SUPABASE_ANON_KEY'] : null) ?? '';
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

  Map<String, String> get _headers => {
        'apikey': _anonKey,
        'Authorization': 'Bearer $_anonKey',
        'Content-Type': 'application/json',
      };

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const ServerException(
        'Supabase is not configured. Please set SUPABASE_URL and SUPABASE_ANON_KEY in your .env file.',
      );
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
        options: Options(headers: _headers),
      );

      final data = response.data;
      if (data is List) {
        if (data.isEmpty) {
          return null;
        }
        final first = data.first as Map<String, dynamic>;
        return DailyChallengeModel.fromSupabaseJson(first);
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
  /// Falls back to `/rest/v1/leaderboard` if needed.
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
          options: Options(headers: _headers),
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
            options: Options(headers: _headers),
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

  /// POST /rest/v1/leaderboard_scores (with fallback to /rest/v1/leaderboard)
  Future<void> submitScore(ScoreModel score) async {
    _ensureConfigured();
    final headers = {
      ..._headers,
      'Prefer': 'return=minimal',
    };
    final payload = score.toSubmissionJson();

    try {
      try {
        await _dio.post<dynamic>(
          '$_baseUrl/rest/v1/leaderboard_scores',
          data: payload,
          options: Options(headers: headers),
        );
      } on DioException catch (inner) {
        if (inner.response?.statusCode == 404) {
          await _dio.post<dynamic>(
            '$_baseUrl/rest/v1/leaderboard',
            data: payload,
            options: Options(headers: headers),
          );
        } else {
          rethrow;
        }
      }
    } on DioException catch (e) {
      throw ServerException(
        _formatDioError(e, 'Failed to submit score to Leaderboard'),
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Unexpected error submitting score: $e');
    }
  }

  String _formatDioError(DioException e, String prefix) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Network connection error. Please check your internet and try again.';
    }
    final status = e.response?.statusCode;
    return '$prefix${status != null ? ' (HTTP $status)' : ''}.';
  }
}

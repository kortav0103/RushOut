import 'dart:async';
import 'dart:collection';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ErrorReportEntry {
  final DateTime timestamp;
  final String message;
  final String stackTrace;
  final bool fatal;
  final String? context;

  const ErrorReportEntry({
    required this.timestamp,
    required this.message,
    required this.stackTrace,
    required this.fatal,
    this.context,
  });
}

/// Lightweight, privacy-safe crash/error reporting hook.
///
/// Scrubs bearer tokens and device identifiers before recording locally and
/// optionally forwarding to an ingest endpoint configured via
/// `--dart-define=ERROR_REPORTING_URL=...`.
class ErrorReportingService {
  static const String _ingestUrl = String.fromEnvironment('ERROR_REPORTING_URL');
  static const int _maxStoredEntries = 20;

  static final ErrorReportingService instance = ErrorReportingService._();

  final Queue<ErrorReportEntry> _recentErrors = Queue<ErrorReportEntry>();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
    ),
  );

  ErrorReportingService._();

  List<ErrorReportEntry> get recentErrors => List.unmodifiable(_recentErrors);

  static String scrubSensitiveData(String input) {
    return input
        .replaceAll(
          RegExp(r'Bearer\s+[A-Za-z0-9\-_\.]+', caseSensitive: false),
          'Bearer [REDACTED]',
        )
        .replaceAllMapped(
          RegExp(
            r'''(["']?(?:x-)?api[_-]?key["']?\s*[:=]\s*["']?)[A-Za-z0-9\-_\.]+''',
            caseSensitive: false,
          ),
          (match) => '${match.group(1)}[REDACTED]',
        )
        .replaceAll(
          RegExp(
            r'\b(dev|win|ios|mac|lin|and)_[A-Za-z0-9\-_]{6,}\b',
            caseSensitive: false,
          ),
          '[DEVICE_ID]',
        )
        .replaceAll(
          RegExp(
            r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',
            caseSensitive: false,
          ),
          '[UUID]',
        );
  }

  void recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    String? context,
  }) {
    final sanitizedMessage = scrubSensitiveData(error.toString());
    final sanitizedStack = scrubSensitiveData(stack.toString());

    if (_recentErrors.length >= _maxStoredEntries) {
      _recentErrors.removeFirst();
    }
    _recentErrors.addLast(
      ErrorReportEntry(
        timestamp: DateTime.now().toUtc(),
        message: sanitizedMessage,
        stackTrace: sanitizedStack,
        fatal: fatal,
        context: context,
      ),
    );

    if (kDebugMode) {
      debugPrint(
        '[${fatal ? 'FATAL' : 'ERROR'}]${context != null ? ' ($context)' : ''}: $sanitizedMessage\n$sanitizedStack',
      );
    }

    final endpoint = _ingestUrl.trim();
    if (kReleaseMode && endpoint.startsWith('https://')) {
      unawaited(
        _sendRemoteReport(
          endpoint: endpoint,
          fatal: fatal,
          context: context,
          message: sanitizedMessage,
          stackTrace: sanitizedStack,
        ),
      );
    }
  }

  Future<void> _sendRemoteReport({
    required String endpoint,
    required bool fatal,
    required String? context,
    required String message,
    required String stackTrace,
  }) async {
    try {
      await _dio.post<dynamic>(
        endpoint,
        data: {
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'fatal': fatal,
          'context': context,
          'message': message,
          'stackTrace': stackTrace,
          'platform': defaultTargetPlatform.name,
        },
      );
    } catch (_) {}
  }
}

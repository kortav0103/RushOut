class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Server error occurred']);

  @override
  String toString() => message;
}

class EmptyDataException implements Exception {
  final String message;
  const EmptyDataException([this.message = 'No data available']);

  @override
  String toString() => message;
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Cache error occurred']);

  @override
  String toString() => message;
}

class LevelParseException implements Exception {
  final String message;
  const LevelParseException(this.message);

  @override
  String toString() => 'LevelParseException: $message';
}

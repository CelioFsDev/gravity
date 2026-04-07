import 'dart:io';

/// Reads configuration from environment variables (or .env file).
class Config {
  final String host;
  final int port;
  final String minioEndpoint;
  final int minioPort;
  final String minioAccessKey;
  final String minioSecretKey;
  final bool minioUseSsl;
  final String minioBucket;
  final String firebaseProjectId;
  final int presignedUrlExpiry;

  const Config({
    required this.host,
    required this.port,
    required this.minioEndpoint,
    required this.minioPort,
    required this.minioAccessKey,
    required this.minioSecretKey,
    required this.minioUseSsl,
    required this.minioBucket,
    required this.firebaseProjectId,
    required this.presignedUrlExpiry,
  });

  factory Config.fromEnv() {
    // Load .env file if present (simple key=value parser)
    _loadDotEnv();

    return Config(
      host: _env('HOST', '0.0.0.0'),
      port: int.parse(_env('PORT', '8080')),
      minioEndpoint: _env('MINIO_ENDPOINT', 'localhost'),
      minioPort: int.parse(_env('MINIO_PORT', '9000')),
      minioAccessKey: _env('MINIO_ACCESS_KEY', 'minioadmin'),
      minioSecretKey: _env('MINIO_SECRET_KEY', 'minioadmin'),
      minioUseSsl: _env('MINIO_USE_SSL', 'false').toLowerCase() == 'true',
      minioBucket: _env('MINIO_BUCKET', 'gravity'),
      firebaseProjectId: _env('FIREBASE_PROJECT_ID', 'catalogoja-app'),
      presignedUrlExpiry:
          int.parse(_env('PRESIGNED_URL_EXPIRY', '3600')),
    );
  }

  static String _env(String key, String fallback) {
    return Platform.environment[key] ?? _dotEnvValues[key] ?? fallback;
  }

  static final Map<String, String> _dotEnvValues = {};

  static void _loadDotEnv() {
    final envFile = File('.env');
    if (!envFile.existsSync()) return;

    for (final line in envFile.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex < 0) continue;
      final key = trimmed.substring(0, eqIndex).trim();
      final value = trimmed.substring(eqIndex + 1).trim();
      _dotEnvValues[key] = value;
    }
  }

  @override
  String toString() => 'Config('
      'host=$host, port=$port, '
      'minio=$minioEndpoint:$minioPort/$minioBucket, '
      'firebase=$firebaseProjectId)';
}

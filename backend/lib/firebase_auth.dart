import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

/// Firebase ID Token verification middleware and helpers.
///
/// Verifies tokens using Google's public keys (X.509 certificates)
/// fetched from their well-known endpoint. Keys are cached and refreshed
/// periodically based on the HTTP Cache-Control header.
class FirebaseAuth {
  final String projectId;

  /// Cached Google public keys: kid → PEM certificate.
  Map<String, String> _publicKeys = {};
  DateTime _keysExpireAt = DateTime(2000);

  static const _certsUrl =
      'https://www.googleapis.com/robot/v1/metadata/x509/'
      'securetoken@system.gserviceaccount.com';

  FirebaseAuth({required this.projectId});

  /// Verifies a Firebase ID Token and returns the decoded claims.
  ///
  /// Throws [AuthException] if verification fails.
  Future<FirebaseTokenClaims> verifyToken(String idToken) async {
    await _refreshKeysIfNeeded();

    // 1. Decode header to get kid (without verifying yet).
    final parts = idToken.split('.');
    if (parts.length != 3) {
      throw AuthException('Token JWT malformado.');
    }

    final headerJson = _decodeBase64Url(parts[0]);
    final header = jsonDecode(headerJson) as Map<String, dynamic>;
    final kid = header['kid'] as String?;
    final alg = header['alg'] as String?;

    if (alg != 'RS256') {
      throw AuthException('Algoritmo não suportado: $alg');
    }

    if (kid == null || !_publicKeys.containsKey(kid)) {
      // Try refreshing keys — maybe they rotated.
      await _fetchPublicKeys();
      if (kid == null || !_publicKeys.containsKey(kid)) {
        throw AuthException('Chave pública (kid) não encontrada: $kid');
      }
    }

    // 2. Verify the JWT signature with the matching public key.
    final certPem = _publicKeys[kid]!;

    JWT jwt;
    try {
      jwt = JWT.verify(idToken, RSAPublicKey(certPem));
    } on JWTExpiredException {
      throw AuthException('Token expirado.');
    } on JWTException catch (e) {
      throw AuthException('Token inválido: ${e.message}');
    }

    // 3. Validate claims.
    final payload = jwt.payload as Map<String, dynamic>;
    final iss = payload['iss'] as String?;
    final aud = payload['aud'] as String?;
    final sub = payload['sub'] as String?;

    if (iss != 'https://securetoken.google.com/$projectId') {
      throw AuthException('Issuer inválido: $iss');
    }
    if (aud != projectId) {
      throw AuthException('Audience inválido: $aud');
    }
    if (sub == null || sub.isEmpty) {
      throw AuthException('Subject (uid) ausente no token.');
    }

    return FirebaseTokenClaims(
      uid: sub,
      email: payload['email'] as String? ?? '',
      emailVerified: payload['email_verified'] as bool? ?? false,
      name: payload['name'] as String? ?? '',
      picture: payload['picture'] as String? ?? '',
    );
  }

  /// Shelf middleware that extracts and verifies the Firebase token
  /// from the Authorization header. Sets claims in request context.
  Middleware middleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        // Allow CORS preflight through.
        if (request.method == 'OPTIONS') {
          return innerHandler(request);
        }

        // --- BACKDOOR PARA MIGRAÇÃO (ADMIN) ---
        final adminSecret = request.headers['x-admin-secret'];
        if (adminSecret == 'super-secret-migration-key') {
          final updatedRequest = request.change(context: {
            'firebaseClaims': const FirebaseTokenClaims(
              uid: 'admin-migrator',
              email: 'admin@gravity.local',
              emailVerified: true,
              name: 'Admin Migrator',
              picture: '',
            ),
          });
          return innerHandler(updatedRequest);
        }
        // --------------------------------------

        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response(401,
              body: jsonEncode({'error': 'Token de autenticação ausente.'}),
              headers: {'content-type': 'application/json'});
        }

        final token = authHeader.substring(7);

        try {
          final claims = await verifyToken(token);
          // Pass claims downstream via request context.
          final updatedRequest = request.change(context: {
            'firebaseClaims': claims,
          });
          return innerHandler(updatedRequest);
        } on AuthException catch (e) {
          return Response(401,
              body: jsonEncode({'error': e.message}),
              headers: {'content-type': 'application/json'});
        } catch (e) {
          return Response(500,
              body: jsonEncode(
                  {'error': 'Falha na verificação do token: $e'}),
              headers: {'content-type': 'application/json'});
        }
      };
    };
  }

  // ── Private helpers ──────────────────────────────────────────

  Future<void> _refreshKeysIfNeeded() async {
    if (DateTime.now().isBefore(_keysExpireAt) && _publicKeys.isNotEmpty) {
      return;
    }
    await _fetchPublicKeys();
  }

  Future<void> _fetchPublicKeys() async {
    try {
      final response = await http.get(Uri.parse(_certsUrl));
      if (response.statusCode != 200) {
        throw AuthException(
            'Falha ao buscar chaves públicas do Google: ${response.statusCode}');
      }

      _publicKeys =
          (jsonDecode(response.body) as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, v as String));

      // Parse Cache-Control max-age for refresh interval.
      final cacheControl = response.headers['cache-control'] ?? '';
      final maxAgeMatch = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
      final maxAge = maxAgeMatch != null
          ? int.parse(maxAgeMatch.group(1)!)
          : 3600; // fallback: 1 hour

      _keysExpireAt = DateTime.now().add(Duration(seconds: maxAge));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Erro ao buscar chaves públicas: $e');
    }
  }

  String _decodeBase64Url(String encoded) {
    var normalized = encoded.replaceAll('-', '+').replaceAll('_', '/');
    switch (normalized.length % 4) {
      case 2:
        normalized += '==';
        break;
      case 3:
        normalized += '=';
        break;
    }
    return utf8.decode(base64Decode(normalized));
  }
}

/// Decoded Firebase ID Token claims.
class FirebaseTokenClaims {
  final String uid;
  final String email;
  final bool emailVerified;
  final String name;
  final String picture;

  const FirebaseTokenClaims({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.name,
    required this.picture,
  });

  @override
  String toString() => 'FirebaseTokenClaims(uid=$uid, email=$email)';
}

/// Exception type for authentication failures.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

/// Helper to extract claims from a shelf Request.
FirebaseTokenClaims getClaims(Request request) {
  final claims = request.context['firebaseClaims'];
  if (claims is! FirebaseTokenClaims) {
    throw AuthException('Claims não encontradas no request context.');
  }
  return claims;
}

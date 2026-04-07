import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:gravity_api/config.dart';
import 'package:gravity_api/firebase_auth.dart';
import 'package:gravity_api/minio_service.dart';
import 'package:gravity_api/handlers.dart';

void main(List<String> args) async {
  // ── Configuration ──────────────────────────────────────────
  final config = Config.fromEnv();
  print('⚙️  Config: $config');

  // ── Services ───────────────────────────────────────────────
  final firebaseAuth = FirebaseAuth(projectId: config.firebaseProjectId);
  final minioService = MinioService(config: config);
  final handlers = Handlers(minio: minioService);

  // Verify MinIO connection and bucket.
  try {
    await minioService.ensureBucket();
  } catch (e) {
    print('⚠️  MinIO não disponível: $e');
    print('   A API iniciará mesmo assim, mas uploads falharão até que o MinIO esteja acessível.');
  }

  // ── CORS middleware ────────────────────────────────────────
  Middleware cors() {
    return (Handler handler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await handler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  // ── Routes ─────────────────────────────────────────────────
  final router = Router();

  // Public (no auth)
  router.get('/health', handlers.health);

  // Authenticated routes
  router.post('/api/v1/upload/product-image', handlers.uploadProductImage);
  router.post('/api/v1/upload/category-cover', handlers.uploadCategoryCover);
  router.post('/api/v1/upload/catalog-banner', handlers.uploadCatalogBanner);
  router.post('/api/v1/upload/catalog-pdf', handlers.uploadCatalogPdf);
  router.post('/api/v1/upload/profile-avatar', handlers.uploadProfileAvatar);
  router.get('/api/v1/file-url', handlers.getFileUrl);
  router.delete('/api/v1/file', handlers.deleteFile);
  router.delete('/api/v1/product-images', handlers.deleteProductImages);

  // ── Pipeline ───────────────────────────────────────────────
  // Auth middleware is applied only to /api/* routes.
  final authMiddleware = firebaseAuth.middleware();

  FutureOr<Response> pipeline(Request request) async {
    final path = request.url.path;

    // Skip auth for health check and OPTIONS.
    if (path == 'health' || request.method == 'OPTIONS') {
      return router.call(request);
    }

    // Apply auth to all /api/* routes.
    if (path.startsWith('api/')) {
      final authedHandler = const Pipeline()
          .addMiddleware(authMiddleware)
          .addHandler(router.call);
      return authedHandler(request);
    }

    return router.call(request);
  }

  final handler = const Pipeline()
      .addMiddleware(cors())
      .addMiddleware(logRequests())
      .addHandler(pipeline);

  // ── Start server ───────────────────────────────────────────
  final server = await shelf_io.serve(
    handler,
    config.host,
    config.port,
  );

  print('');
  print('🚀 Gravity API rodando em http://${server.address.host}:${server.port}');
  print('   Health check: http://${server.address.host}:${server.port}/health');
  print('');

  // Graceful shutdown.
  ProcessSignal.sigint.watch().listen((_) async {
    print('\n🛑 Encerrando servidor...');
    await server.close(force: true);
    exit(0);
  });
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, X-Requested-With, X-Admin-Secret',
  'Access-Control-Max-Age': '86400',
};

import 'dart:convert';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:mime/mime.dart' as mime_pkg;
import 'firebase_auth.dart';
import 'minio_service.dart';

/// All route handlers for the Gravity API.
class Handlers {
  final MinioService minio;

  const Handlers({required this.minio});

  // ─── Health ────────────────────────────────────────────────

  Response health(Request request) {
    return Response.ok(
      jsonEncode({
        'status': 'ok',
        'service': 'gravity-api',
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  // ─── Upload: Product Image ────────────────────────────────

  Future<Response> uploadProductImage(Request request) async {
    try {
      final claims = getClaims(request);
      final params = request.url.queryParameters;

      final storeId = params['storeId'];
      final productRef = params['productRef'];
      final label = params['label'] ?? 'P';
      final colorTag = params['colorTag'];

      if (storeId == null || storeId.isEmpty) {
        return _badRequest('Parâmetro "storeId" é obrigatório.');
      }
      if (productRef == null || productRef.isEmpty) {
        return _badRequest('Parâmetro "productRef" é obrigatório.');
      }

      final bytes = await _readBody(request);
      if (bytes.isEmpty) {
        return _badRequest('Corpo da requisição vazio (envie os bytes da imagem).');
      }

      final contentType =
          request.headers['content-type'] ?? 'image/jpeg';
      final ext = _extensionFromContentType(contentType);

      final objectPath = MinioService.productImagePath(
        storeId: storeId,
        productRef: productRef,
        label: label,
        colorTag: colorTag,
        extension: ext,
      );

      await minio.upload(
        objectPath: objectPath,
        bytes: bytes,
        contentType: contentType,
      );

      final url = await minio.presignedUrl(objectPath);

      print('📸 Upload: $objectPath (${bytes.length} bytes) by ${claims.email}');

      return Response.ok(
        jsonEncode({
          'path': objectPath,
          'url': url,
          'size': bytes.length,
          'contentType': contentType,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return _error('Erro no upload de imagem de produto: $e');
    }
  }

  // ─── Upload: Category/Collection Cover ────────────────────

  Future<Response> uploadCategoryCover(Request request) async {
    try {
      final claims = getClaims(request);
      final params = request.url.queryParameters;

      final storeId = params['storeId'];
      final categoryId = params['categoryId'];
      final type = params['type'] ?? 'cover';

      if (storeId == null || storeId.isEmpty) {
        return _badRequest('Parâmetro "storeId" é obrigatório.');
      }
      if (categoryId == null || categoryId.isEmpty) {
        return _badRequest('Parâmetro "categoryId" é obrigatório.');
      }

      final bytes = await _readBody(request);
      if (bytes.isEmpty) {
        return _badRequest('Corpo da requisição vazio.');
      }

      final contentType =
          request.headers['content-type'] ?? 'image/jpeg';
      final ext = _extensionFromContentType(contentType);

      final objectPath = MinioService.categoryImagePath(
        storeId: storeId,
        categoryId: categoryId,
        type: type,
        extension: ext,
      );

      await minio.upload(
        objectPath: objectPath,
        bytes: bytes,
        contentType: contentType,
      );

      final url = await minio.presignedUrl(objectPath);

      print('🖼️ Upload category cover: $objectPath by ${claims.email}');

      return Response.ok(
        jsonEncode({'path': objectPath, 'url': url, 'size': bytes.length}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return _error('Erro no upload de capa de categoria: $e');
    }
  }

  // ─── Upload: Catalog Banner ───────────────────────────────

  Future<Response> uploadCatalogBanner(Request request) async {
    try {
      final claims = getClaims(request);
      final params = request.url.queryParameters;

      final storeId = params['storeId'];
      final catalogId = params['catalogId'];
      final type = params['type'] ?? 'banner';

      if (storeId == null || storeId.isEmpty) {
        return _badRequest('Parâmetro "storeId" é obrigatório.');
      }
      if (catalogId == null || catalogId.isEmpty) {
        return _badRequest('Parâmetro "catalogId" é obrigatório.');
      }

      final bytes = await _readBody(request);
      if (bytes.isEmpty) {
        return _badRequest('Corpo da requisição vazio.');
      }

      final contentType =
          request.headers['content-type'] ?? 'image/jpeg';
      final ext = _extensionFromContentType(contentType);

      final objectPath = MinioService.catalogImagePath(
        storeId: storeId,
        catalogId: catalogId,
        type: type,
        extension: ext,
      );

      await minio.upload(
        objectPath: objectPath,
        bytes: bytes,
        contentType: contentType,
      );

      final url = await minio.presignedUrl(objectPath);

      print('🏷️ Upload catalog banner: $objectPath by ${claims.email}');

      return Response.ok(
        jsonEncode({'path': objectPath, 'url': url, 'size': bytes.length}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return _error('Erro no upload de banner de catálogo: $e');
    }
  }

  // ─── Upload: Catalog PDF ──────────────────────────────────

  Future<Response> uploadCatalogPdf(Request request) async {
    try {
      final claims = getClaims(request);
      final params = request.url.queryParameters;

      final storeId = params['storeId'];
      final catalogId = params['catalogId'];
      final name = params['name'] ?? 'catalogo';

      if (storeId == null || storeId.isEmpty) {
        return _badRequest('Parâmetro "storeId" é obrigatório.');
      }
      if (catalogId == null || catalogId.isEmpty) {
        return _badRequest('Parâmetro "catalogId" é obrigatório.');
      }

      final bytes = await _readBody(request);
      if (bytes.isEmpty) {
        return _badRequest('Corpo da requisição vazio.');
      }

      final objectPath = MinioService.catalogPdfPath(
        storeId: storeId,
        catalogId: catalogId,
        name: name,
      );

      await minio.upload(
        objectPath: objectPath,
        bytes: bytes,
        contentType: 'application/pdf',
      );

      final url = await minio.presignedUrl(objectPath);

      print('📄 Upload PDF: $objectPath by ${claims.email}');

      return Response.ok(
        jsonEncode({'path': objectPath, 'url': url, 'size': bytes.length}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return _error('Erro no upload de PDF: $e');
    }
  }

  // ─── Upload: Profile Avatar ───────────────────────────────

  Future<Response> uploadProfileAvatar(Request request) async {
    try {
      final claims = getClaims(request);
      final params = request.url.queryParameters;

      final storeId = params['storeId'];
      if (storeId == null || storeId.isEmpty) {
        return _badRequest('Parâmetro "storeId" é obrigatório.');
      }

      final bytes = await _readBody(request);
      if (bytes.isEmpty) {
        return _badRequest('Corpo da requisição vazio.');
      }

      final contentType =
          request.headers['content-type'] ?? 'image/jpeg';
      final ext = _extensionFromContentType(contentType);

      final objectPath = MinioService.profileImagePath(
        storeId: storeId,
        uid: claims.uid,
        extension: ext,
      );

      await minio.upload(
        objectPath: objectPath,
        bytes: bytes,
        contentType: contentType,
      );

      final url = await minio.presignedUrl(objectPath);

      print('👤 Upload avatar: $objectPath by ${claims.email}');

      return Response.ok(
        jsonEncode({'path': objectPath, 'url': url, 'size': bytes.length}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return _error('Erro no upload de avatar: $e');
    }
  }

  // ─── Get presigned URL ────────────────────────────────────

  Future<Response> getFileUrl(Request request) async {
    try {
      getClaims(request); // ensure authenticated

      final objectPath = request.url.queryParameters['path'];
      if (objectPath == null || objectPath.isEmpty) {
        return _badRequest('Parâmetro "path" é obrigatório.');
      }

      final url = await minio.presignedUrl(objectPath);

      return Response.ok(
        jsonEncode({'url': url, 'path': objectPath}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return _error('Erro ao gerar URL: $e');
    }
  }

  // ─── Delete file ──────────────────────────────────────────

  Future<Response> deleteFile(Request request) async {
    try {
      final claims = getClaims(request);
      final objectPath = request.url.queryParameters['path'];
      if (objectPath == null || objectPath.isEmpty) {
        return _badRequest('Parâmetro "path" é obrigatório.');
      }

      await minio.delete(objectPath);

      print('🗑️ Delete: $objectPath by ${claims.email}');

      return Response.ok(
        jsonEncode({'deleted': objectPath}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return _error('Erro ao deletar arquivo: $e');
    }
  }

  // ─── Delete all product images ────────────────────────────

  Future<Response> deleteProductImages(Request request) async {
    try {
      final claims = getClaims(request);
      final params = request.url.queryParameters;

      final storeId = params['storeId'];
      final productRef = params['productRef'];

      if (storeId == null || productRef == null) {
        return _badRequest(
            'Parâmetros "storeId" e "productRef" são obrigatórios.');
      }

      final prefix = 'stores/${MinioService.sanitize(storeId)}'
          '/products/${MinioService.sanitize(productRef)}/';

      final count = await minio.deleteByPrefix(prefix);

      print('🗑️ Deleted $count files under $prefix by ${claims.email}');

      return Response.ok(
        jsonEncode({'prefix': prefix, 'deletedCount': count}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return _error('Erro ao deletar imagens do produto: $e');
    }
  }

  // ─── Private helpers ──────────────────────────────────────

  Future<Uint8List> _readBody(Request request) async {
    final chunks = await request.read().toList();
    final totalLength = chunks.fold<int>(0, (sum, c) => sum + c.length);
    final bytes = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in chunks) {
      bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return bytes;
  }

  String _extensionFromContentType(String contentType) {
    final type = contentType.toLowerCase().split(';').first.trim();
    final ext = mime_pkg.extensionFromMime(type);
    return ext ?? 'jpg';
  }

  Response _badRequest(String message) {
    return Response(400,
        body: jsonEncode({'error': message}),
        headers: {'content-type': 'application/json'});
  }

  Response _error(String message) {
    print('❌ $message');
    return Response(500,
        body: jsonEncode({'error': message}),
        headers: {'content-type': 'application/json'});
  }
}

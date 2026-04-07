import 'dart:typed_data';
import 'package:minio/minio.dart';
import 'config.dart';

/// Wrapper around MinIO SDK providing typed operations for Gravity storage.
class MinioService {
  late final Minio _client;
  final String bucket;
  final int presignedExpiry;

  MinioService({required Config config})
      : bucket = config.minioBucket,
        presignedExpiry = config.presignedUrlExpiry {
    _client = Minio(
      endPoint: config.minioEndpoint,
      port: config.minioPort,
      accessKey: config.minioAccessKey,
      secretKey: config.minioSecretKey,
      useSSL: config.minioUseSsl,
    );
  }

  /// Ensures the configured bucket exists, creating it if needed.
  Future<void> ensureBucket() async {
    final exists = await _client.bucketExists(bucket);
    if (!exists) {
      await _client.makeBucket(bucket);
      print('✅ Bucket "$bucket" criado.');
    } else {
      print('✅ Bucket "$bucket" encontrado.');
    }
  }

  /// Uploads raw bytes to the given [objectPath] inside the bucket.
  ///
  /// Returns the object path (not a URL — use [presignedUrl] to get one).
  Future<String> upload({
    required String objectPath,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
  }) async {
    await _client.putObject(
      bucket,
      objectPath,
      Stream.value(bytes),
      size: bytes.length,
      metadata: {'Content-Type': contentType},
    );
    return objectPath;
  }

  /// Generates a presigned GET URL for the given [objectPath].
  ///
  /// The URL is valid for [presignedExpiry] seconds (default from config).
  Future<String> presignedUrl(
    String objectPath, {
    int? expirySeconds,
  }) async {
    return await _client.presignedGetObject(
      bucket,
      objectPath,
      expires: expirySeconds ?? presignedExpiry,
    );
  }

  /// Deletes a single object by its path.
  Future<void> delete(String objectPath) async {
    await _client.removeObject(bucket, objectPath);
  }

  /// Deletes all objects under a given prefix (e.g., all product images).
  Future<int> deleteByPrefix(String prefix) async {
    int count = 0;
    final objects = _client.listObjects(bucket, prefix: prefix, recursive: true);
    final paths = <String>[];

    await for (final result in objects) {
      for (final obj in result.objects) {
        if (obj.key != null) {
          paths.add(obj.key!);
          count++;
        }
      }
    }

    for (final path in paths) {
      await _client.removeObject(bucket, path);
    }

    return count;
  }

  /// Lists all object keys under a given prefix.
  Future<List<String>> list(String prefix) async {
    final keys = <String>[];
    final objects = _client.listObjects(bucket, prefix: prefix, recursive: true);
    await for (final result in objects) {
      for (final obj in result.objects) {
        if (obj.key != null) keys.add(obj.key!);
      }
    }
    return keys;
  }

  // ─── Path builders ─────────────────────────────────────────

  /// Builds the MinIO object path for a product image.
  ///
  /// Pattern: stores/{storeId}/products/{productRef}/{label}.{ext}
  /// For color images: stores/{storeId}/products/{productRef}/colors/{color}.{ext}
  static String productImagePath({
    required String storeId,
    required String productRef,
    required String label,
    String? colorTag,
    String extension = 'jpg',
  }) {
    final safeStoreId = sanitize(storeId);
    final safeRef = sanitize(productRef);
    final safeExt = extension.replaceAll('.', '');

    final fileName = _labelToFileName(label, colorTag: colorTag);
    final isColor = label.toUpperCase().startsWith('C') &&
        label.toUpperCase() != 'COVER';

    if (isColor && colorTag != null && colorTag.isNotEmpty) {
      return 'stores/$safeStoreId/products/$safeRef/colors/$fileName.$safeExt';
    }
    return 'stores/$safeStoreId/products/$safeRef/$fileName.$safeExt';
  }

  /// Builds the MinIO object path for a catalog cover/banner.
  ///
  /// Pattern: stores/{storeId}/catalogs/{catalogId}/{type}.{ext}
  static String catalogImagePath({
    required String storeId,
    required String catalogId,
    String type = 'cover',
    String extension = 'jpg',
  }) {
    final safeExt = extension.replaceAll('.', '');
    return 'stores/${sanitize(storeId)}/catalogs/${sanitize(catalogId)}/$type.$safeExt';
  }

  /// Builds the MinIO object path for a catalog PDF.
  ///
  /// Pattern: stores/{storeId}/catalogs/{catalogId}/pdf/{name}.pdf
  static String catalogPdfPath({
    required String storeId,
    required String catalogId,
    String name = 'catalogo',
  }) {
    return 'stores/${sanitize(storeId)}/catalogs/${sanitize(catalogId)}/pdf/$name.pdf';
  }

  /// Builds the MinIO object path for a category/collection cover image.
  ///
  /// Pattern: stores/{storeId}/categories/{categoryId}/{type}.{ext}
  static String categoryImagePath({
    required String storeId,
    required String categoryId,
    required String type,
    String extension = 'jpg',
  }) {
    final safeExt = extension.replaceAll('.', '');
    return 'stores/${sanitize(storeId)}/categories/${sanitize(categoryId)}/$type.$safeExt';
  }

  /// Builds the MinIO object path for a profile avatar.
  ///
  /// Pattern: stores/{storeId}/profile/{uid}/avatar.{ext}
  static String profileImagePath({
    required String storeId,
    required String uid,
    String extension = 'jpg',
  }) {
    final safeExt = extension.replaceAll('.', '');
    return 'stores/${sanitize(storeId)}/profile/${sanitize(uid)}/avatar.$safeExt';
  }

  /// Maps product image labels to readable file names.
  static String _labelToFileName(String label, {String? colorTag}) {
    switch (label.toUpperCase()) {
      case 'P':
      case 'PRINCIPAL':
        return 'principal';
      case 'D1':
      case 'DETALHE1':
        return 'detalhe1';
      case 'D2':
      case 'DETALHE2':
        return 'detalhe2';
      case 'C1':
      case 'C2':
      case 'C3':
      case 'C4':
        return sanitize(colorTag ?? label.toLowerCase());
      default:
        return sanitize(label.toLowerCase());
    }
  }

  /// Sanitizes a path component — removes special chars, lowercases.
  static String sanitize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\-.]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}

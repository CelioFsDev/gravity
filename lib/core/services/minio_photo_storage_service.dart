import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../data/repositories/auth_repository.dart';
import '../config/api_config.dart';
import 'storage_service_interface.dart';

class MinioPhotoStorageService implements IPhotoStorageService {
  final AuthRepository _authRepository;
  String? _adminSecret;

  MinioPhotoStorageService(this._authRepository);

  /// Seta a chave secreta de administrador (usada para migração)
  void setAdminSecret(String? secret) {
    _adminSecret = secret;
  }


  Future<String> _getToken() async {
    final user = _authRepository.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    return await user.getIdToken() ?? '';
  }

  Map<String, String> _headers(String token, {String contentType = 'application/json'}) {
    return {
      if (_adminSecret != null) 'X-Admin-Secret': _adminSecret!,
      'Authorization': 'Bearer $token',
      'Content-Type': contentType,
    };
  }

  @override
  Future<String?> uploadCategoryImage({
    required String tenantId,
    required String categoryId,
    String? localPath,
    Uint8List? bytes,
  }) async {
    return uploadCategoryCover(
      storeId: tenantId,
      categoryId: categoryId,
      bytes: bytes ?? await File(localPath!).readAsBytes(),
      type: 'cover',
    );
  }

  @override
  Future<String?> uploadCategoryCover({
    required String storeId,
    required String categoryId,
    required Uint8List bytes,
    required String type,
  }) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse(ApiConfig.uploadCategoryCover).replace(
        queryParameters: {
          'storeId': storeId,
          'categoryId': categoryId,
          'type': type,
        },
      );

      final response = await http.post(
        uri,
        headers: _headers(token, contentType: 'image/jpeg'),
        body: bytes,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body)['url'];
      }
      throw Exception('Falha no upload (MinIO): ${response.body}');
    } catch (e) {
      debugPrint('Erro MinioStorage.uploadCategoryCover: $e');
      return null;
    }
  }

  @override
  Future<String?> uploadCatalogImage({
    required String tenantId,
    required String catalogId,
    String? localPath,
    Uint8List? bytes,
  }) async {
    return uploadCatalogBanner(
      storeId: tenantId,
      catalogId: catalogId,
      bytes: bytes ?? await File(localPath!).readAsBytes(),
    );
  }

  @override
  Future<String?> uploadCatalogBanner({
    required String storeId,
    required String catalogId,
    required Uint8List bytes,
  }) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse(ApiConfig.uploadCatalogBanner).replace(
        queryParameters: {
          'storeId': storeId,
          'catalogId': catalogId,
          'type': 'banner',
        },
      );

      final response = await http.post(
        uri,
        headers: _headers(token, contentType: 'image/jpeg'),
        body: bytes,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body)['url'];
      }
      throw Exception('Falha no upload (MinIO): ${response.body}');
    } catch (e) {
      debugPrint('Erro MinioStorage.uploadCatalogBanner: $e');
      return null;
    }
  }

  @override
  Future<String> uploadProductImage({
    required String tenantId,
    required String productId,
    String? localPath,
    Uint8List? bytes,
    String? label,
    String? colorTag,
    bool temporary = false,
  }) async {
    final token = await _getToken();
    final data = bytes ?? await File(localPath!).readAsBytes();
    
    final uri = Uri.parse(ApiConfig.uploadProductImage).replace(
      queryParameters: {
        'storeId': tenantId,
        'productRef': productId,
        'label': label ?? 'P',
        if (colorTag != null) 'colorTag': colorTag,
      },
    );

    final response = await http.post(
      uri,
      headers: _headers(token, contentType: 'image/jpeg'),
      body: data,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body)['url'];
    }
    throw Exception('Falha no upload (MinIO): ${response.body}');
  }

  @override
  Future<void> finalizeProductImage(String downloadUrl) async {
    // No-op for current Backend API logic
  }

  @override
  Future<void> deleteFileByUrl(String downloadUrl) async {
    // Ideally we would extract the path and call DELETE /api/v1/delete?path=...
  }

  @override
  Future<void> deleteProductPhotos({
    required String tenantId,
    required String productId,
  }) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse(ApiConfig.deleteProductImages).replace(
        queryParameters: {
          'storeId': tenantId,
          'productRef': productId,
        },
      );

      final response = await http.delete(uri, headers: _headers(token));
      if (response.statusCode != 200) {
        throw Exception('Falha ao deletar fotos: ${response.body}');
      }
    } catch (e) {
      debugPrint('Erro MinioStorage.deleteProductPhotos: $e');
    }
  }

  @override
  Future<String?> uploadProfileImage({
    required String? tenantId,
    required String email,
    required String? localPath,
    Uint8List? bytes,
  }) async {
    try {
      final token = await _getToken();
      final data = bytes ?? await File(localPath!).readAsBytes();
      
      final uri = Uri.parse(ApiConfig.uploadProfileAvatar).replace(
        queryParameters: {
          if (tenantId != null) 'storeId': tenantId,
        },
      );

      final response = await http.post(
        uri,
        headers: _headers(token, contentType: 'image/jpeg'),
        body: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body)['url'];
      }
      return null;
    } catch (e) {
      debugPrint('Erro MinioStorage.uploadProfileImage: $e');
      return null;
    }
  }

  @override
  Future<String?> uploadCatalogPdf({
    required String tenantId,
    required String catalogId,
    required Uint8List pdfBytes,
    String name = 'catalogo',
  }) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse(ApiConfig.uploadCatalogPdf).replace(
        queryParameters: {
          'storeId': tenantId,
          'catalogId': catalogId,
          'name': name,
        },
      );

      final response = await http.post(
        uri,
        headers: _headers(token, contentType: 'application/pdf'),
        body: pdfBytes,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body)['url'];
      }
      return null;
    } catch (e) {
      debugPrint('Erro MinioStorage.uploadCatalogPdf: $e');
      return null;
    }
  }
}

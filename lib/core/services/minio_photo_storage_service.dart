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

  MinioPhotoStorageService(this._authRepository);

  Future<String> _getToken() async {
    final user = _authRepository.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    return await user.getIdToken() ?? '';
  }

  Map<String, String> _headers(String token, {String contentType = 'application/json'}) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': contentType,
    };
  }

  @override
  Future<String?> uploadCategoryImage({
    required String localPath,
    required String categoryId,
    required String tenantId,
    Uint8List? bytes,
  }) async {
    try {
      final token = await _getToken();
      final data = bytes ?? await File(localPath).readAsBytes();
      
      final uri = Uri.parse(ApiConfig.uploadCategoryCover).replace(
        queryParameters: {
          'storeId': tenantId,
          'categoryId': categoryId,
          'type': 'cover',
        },
      );

      final response = await http.post(
        uri,
        headers: _headers(token, contentType: 'image/jpeg'),
        body: data,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['url'];
      }
      throw Exception('Falha no upload (MinIO): ${response.body}');
    } catch (e) {
      debugPrint('Erro MinioStorage.uploadCategoryImage: $e');
      return null;
    }
  }

  @override
  Future<String?> uploadCatalogImage({
    required String localPath,
    required String catalogId,
    required String tenantId,
    Uint8List? bytes,
  }) async {
    try {
      final token = await _getToken();
      final data = bytes ?? await File(localPath).readAsBytes();
      
      final uri = Uri.parse(ApiConfig.uploadCatalogBanner).replace(
        queryParameters: {
          'storeId': tenantId,
          'catalogId': catalogId,
          'type': 'banner',
        },
      );

      final response = await http.post(
        uri,
        headers: _headers(token, contentType: 'image/jpeg'),
        body: data,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['url'];
      }
      throw Exception('Falha no upload (MinIO): ${response.body}');
    } catch (e) {
      debugPrint('Erro MinioStorage.uploadCatalogImage: $e');
      return null;
    }
  }

  @override
  Future<String> uploadProductImage({
    required String tenantId,
    required String productId,
    required String localPath,
    Uint8List? bytes,
    String? label,
    bool temporary = false,
  }) async {
    final token = await _getToken();
    final data = bytes ?? await File(localPath).readAsBytes();
    
    final uri = Uri.parse(ApiConfig.uploadProductImage).replace(
      queryParameters: {
        'storeId': tenantId,
        'productRef': productId,
        'label': label ?? 'P',
        // Note: colorTag can be added if label starts with C
      },
    );

    final response = await http.post(
      uri,
      headers: _headers(token, contentType: 'image/jpeg'),
      body: data,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['url'];
    }
    throw Exception('Falha no upload (MinIO): ${response.body}');
  }

  @override
  Future<void> finalizeProductImage(String downloadUrl) async {
    // No MinIO/Backend implementation, we might not need a 'temporary' flag 
    // unless we implement the same logic. For now, it's a no-op.
  }

  @override
  Future<void> deleteFileByUrl(String downloadUrl) async {
    try {
      final token = await _getToken();
      
      // Extract path from URL or use a dedicated endpoint if needed.
      // Our backend handles 'path' parameter.
      final uri = Uri.parse(downloadUrl);
      final path = uri.pathSegments.last; // This depends on how MinIO generates pre-signed URLs
      
      // Better: use a dedicated delete method that takes the object path
      // But IPhotoStorageService uses downloadUrl. 
      // For MinIO, we should ideally store the PATH in the DB too.
      // For now, let's try to extract it or handle via a dedicated delete endpoint.
      
      // If the URL contains the path as a query param or in the path:
      // Our backend returns 'path' in the upload response. 
      // We should ideally use that.
    } catch (e) {
      debugPrint('Erro MinioStorage.deleteFileByUrl: $e');
    }
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

      if (response.statusCode == 200) {
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

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['url'];
      }
      return null;
    } catch (e) {
      debugPrint('Erro MinioStorage.uploadCatalogPdf: $e');
      return null;
    }
  }
}

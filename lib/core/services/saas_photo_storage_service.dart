import 'dart:typed_data';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'storage_service_interface.dart';

class SaaSPhotoStorageService implements IPhotoStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://catalogo-ja-89aae.firebasestorage.app',
  );

  @override
  Future<String?> uploadCategoryImage({
    required String tenantId,
    required String categoryId,
    String? localPath,
    Uint8List? bytes,
  }) async {
    try {
      final fileName = localPath != null ? p.basename(localPath) : 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('$tenantId/categories/$categoryId/$fileName');
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'processed': 'true', 'tenant': tenantId},
      );

      TaskSnapshot task;
      if (kIsWeb || bytes != null) {
        if (bytes == null) return null;
        task = await ref.putData(bytes, metadata);
      } else {
        final file = File(localPath!);
        if (!file.existsSync()) return null;
        task = await ref.putFile(file, metadata);
      }
      return await task.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Erro no upload da imagem da categoria: $e');
      return null;
    }
  }

  @override
  Future<String?> uploadCategoryCover({
    required String storeId,
    required String categoryId,
    required Uint8List bytes,
    required String type,
  }) async {
    return uploadCategoryImage(
      tenantId: storeId,
      categoryId: categoryId,
      bytes: bytes,
    );
  }

  @override
  Future<String?> uploadCatalogImage({
    required String tenantId,
    required String catalogId,
    String? localPath,
    Uint8List? bytes,
  }) async {
    try {
      final fileName = localPath != null ? p.basename(localPath) : 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('$tenantId/catalogs/$catalogId/$fileName');
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'processed': 'true', 'tenant': tenantId},
      );

      TaskSnapshot task;
      if (kIsWeb || bytes != null) {
        if (bytes == null) return null;
        task = await ref.putData(bytes, metadata);
      } else {
        final file = File(localPath!);
        if (!file.existsSync()) return null;
        task = await ref.putFile(file, metadata);
      }
      return await task.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Erro no upload da imagem do catálogo: $e');
      return null;
    }
  }

  @override
  Future<String?> uploadCatalogBanner({
    required String storeId,
    required String catalogId,
    required Uint8List bytes,
  }) async {
    return uploadCatalogImage(
      tenantId: storeId,
      catalogId: catalogId,
      bytes: bytes,
    );
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
    final ext = (localPath != null && p.extension(localPath).isNotEmpty) ? p.extension(localPath) : '.jpg';
    final fileName = '${label ?? "image"}_${DateTime.now().millisecondsSinceEpoch}$ext';
    
    final ref = _storage.ref().child('tenants/$tenantId/products/$productId/$fileName');

    final metadata = SettableMetadata(
      contentType: 'image/${ext.replaceAll('.', '')}',
      customMetadata: {
        'tenantId': tenantId,
        'productId': productId,
        'label': label ?? '',
        if (colorTag != null) 'colorTag': colorTag,
        'temporary': temporary ? 'true' : 'false',
      },
    );

    TaskSnapshot uploadTask;
    if (kIsWeb || bytes != null) {
      if (bytes == null) throw Exception('Bytes necessários para upload web/memory.');
      uploadTask = await ref.putData(bytes, metadata);
    } else {
      final file = File(localPath!);
      if (!await file.exists()) throw Exception('Arquivo local não encontrado: $localPath');
      uploadTask = await ref.putFile(file, metadata);
    }
    
    return await uploadTask.ref.getDownloadURL();
  }

  @override
  Future<void> finalizeProductImage(String downloadUrl) async {
    final ref = _storage.refFromURL(downloadUrl);
    final current = await ref.getMetadata();
    final updatedMetadata = <String, String>{
      ...?current.customMetadata,
      'temporary': 'false',
    };
    await ref.updateMetadata(SettableMetadata(customMetadata: updatedMetadata));
  }

  @override
  Future<void> deleteFileByUrl(String downloadUrl) async {
    final ref = _storage.refFromURL(downloadUrl);
    await ref.delete();
  }

  @override
  Future<void> deleteProductPhotos({
    required String tenantId,
    required String productId,
  }) async {
    final listResult = await _storage
        .ref()
        .child('tenants/$tenantId/products/$productId')
        .listAll();
    
    for (var item in listResult.items) {
      await item.delete();
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
      final String refPath = (tenantId != null && tenantId.isNotEmpty)
          ? 'tenants/$tenantId/profile/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : 'users/$email/profile/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final ref = _storage.ref().child(refPath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'email': email,
          if (tenantId != null) 'tenantId': tenantId,
        },
      );

      TaskSnapshot task;
      if (kIsWeb || bytes != null) {
        if (bytes == null) return null;
        task = await ref.putData(bytes, metadata);
      } else {
        final file = File(localPath!);
        if (!file.existsSync()) return null;
        task = await ref.putFile(file, metadata);
      }
      return await task.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Erro no upload da foto de perfil: $e');
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
      final ref = _storage.ref().child('$tenantId/catalogs/$catalogId/pdf/$name.pdf');
      final metadata = SettableMetadata(contentType: 'application/pdf');
      final task = await ref.putData(pdfBytes, metadata);
      return await task.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Erro no upload do PDF (Firebase): $e');
      return null;
    }
  }
}

import 'dart:typed_data';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class SaaSPhotoStorageService {
  // Bucket fornecido pelo usuário
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://catalogo-ja-89aae.firebasestorage.app',
  );

  // ✨ UPLOAD DE CATEGORIA
  Future<String?> uploadCategoryImage({
    required String localPath,
    required String categoryId,
    required String tenantId,
  }) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) return null;

      final fileName = p.basename(localPath); // Use p.basename for consistency
      final ref = _storage.ref().child('$tenantId/categories/$categoryId/$fileName');
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'processed': 'true', 'tenant': tenantId},
      );

      final task = await ref.putFile(file, metadata);
      return await task.ref.getDownloadURL();
    } catch (e) {
      print('Erro no upload da imagem da categoria: $e');
      return null;
    }
  }

  // ✨ UPLOAD DE CATÁLOGO (Banners)
  Future<String?> uploadCatalogImage({
    required String localPath,
    required String catalogId,
    required String tenantId,
  }) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) return null;

      final fileName = p.basename(localPath); // Use p.basename for consistency
      final ref = _storage.ref().child('$tenantId/catalogs/$catalogId/$fileName');
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'processed': 'true', 'tenant': tenantId},
      );

      final task = await ref.putFile(file, metadata);
      return await task.ref.getDownloadURL();
    } catch (e) {
      print('Erro no upload da imagem do catálogo: $e');
      return null;
    }
  }

  /// Sobe uma imagem de produto para a nuvem
  /// Retorna a URL pública de download
  Future<String> uploadProductImage({
    required String tenantId,
    required String productId,
    required String localPath,
    Uint8List? bytes, // Adicionado para suporte Web
    String? label,
  }) async {
    final ext = p.extension(localPath).isNotEmpty ? p.extension(localPath) : '.jpg';
    final fileName = '${label ?? "image"}_${DateTime.now().millisecondsSinceEpoch}$ext';
    
    // Organiza por Empresa -> Produto -> Arquivo
    final ref = _storage.ref().child('tenants/$tenantId/products/$productId/$fileName');

    // Metadata para ajudar na organização
    final metadata = SettableMetadata(
      contentType: 'image/${ext.replaceAll('.', '')}',
      customMetadata: {
        'tenantId': tenantId,
        'productId': productId,
        'label': label ?? '',
      },
    );

    TaskSnapshot uploadTask;
    
    if (kIsWeb || bytes != null) {
      // Caso Web ou se já tivermos os bytes na memória
      if (bytes == null) {
        throw Exception('Para fazer upload na web, os bytes da imagem devem ser fornecidos.');
      }
      uploadTask = await ref.putData(bytes, metadata);
    } else {
      // Caso Celular/Desktop (Android, iOS, Windows)
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Arquivo local não encontrado: $localPath');
      }
      uploadTask = await ref.putFile(file, metadata);
    }
    
    return await uploadTask.ref.getDownloadURL();
  }

  /// Limpa as fotos de um produto (opcional, quando o produto é deletado)
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

  /// Sobe uma imagem de perfil
  Future<String?> uploadProfileImage({
    required String? tenantId,
    required String email,
    required String? localPath,
    List<int>? bytes, // Para suporte Web
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
        task = await ref.putData(Uint8List.fromList(bytes), metadata);
      } else {
        final file = File(localPath!);
        if (!file.existsSync()) return null;
        task = await ref.putFile(file, metadata);
      }
      return await task.ref.getDownloadURL();
    } catch (e) {
      print('Erro no upload da foto de perfil: $e');
      return null;
    }
  }
}

// Provedor do Serviço de Storage do SaaS
final saasPhotoStorageProvider = Provider((ref) => SaaSPhotoStorageService());

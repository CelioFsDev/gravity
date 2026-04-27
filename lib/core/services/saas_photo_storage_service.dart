import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SaaSPhotoStorageService {
  static const int _maxUploadBytes = 900 * 1024;
  static const int _maxImageWidth = 1280;
  static const int _jpegQuality = 72;

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

      final uploadFile = await _prepareImageForUpload(file);
      final fileName = p.basename(uploadFile.path);
      final ref = _storage.ref().child(
        'tenants/$tenantId/categories/$categoryId/$fileName',
      );

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'processed': 'true', 'tenant': tenantId},
      );

      final task = await ref.putFile(uploadFile, metadata);
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

      final uploadFile = await _prepareImageForUpload(file);
      final fileName = p.basename(uploadFile.path);
      final ref = _storage.ref().child(
        'tenants/$tenantId/catalogs/$catalogId/$fileName',
      );

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'processed': 'true', 'tenant': tenantId},
      );

      final task = await ref.putFile(uploadFile, metadata);
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
    bool temporary = false,
  }) async {
    final ext = p.extension(localPath).isNotEmpty
        ? p.extension(localPath)
        : '.jpg';
    final fileName =
        '${label ?? "image"}_${DateTime.now().millisecondsSinceEpoch}$ext';

    // Organiza por Empresa -> Produto -> Arquivo
    final ref = _storage.ref().child(
      'tenants/$tenantId/products/$productId/$fileName',
    );

    // Metadata para ajudar na organização
    final metadata = SettableMetadata(
      contentType: 'image/${ext.replaceAll('.', '')}',
      customMetadata: {
        'tenantId': tenantId,
        'productId': productId,
        'label': label ?? '',
        'temporary': temporary ? 'true' : 'false',
      },
    );

    TaskSnapshot uploadTask;

    if (kIsWeb || bytes != null) {
      // Caso Web ou se já tivermos os bytes na memória
      if (bytes == null) {
        throw Exception(
          'Para fazer upload na web, os bytes da imagem devem ser fornecidos.',
        );
      }
      uploadTask = await ref.putData(bytes, metadata);
    } else {
      // Caso Celular/Desktop (Android, iOS, Windows)
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Arquivo local não encontrado: $localPath');
      }
      final uploadFile = await _prepareImageForUpload(file);
      uploadTask = await ref.putFile(uploadFile, metadata);
    }

    return await uploadTask.ref.getDownloadURL();
  }

  Future<void> finalizeProductImage(String downloadUrl) async {
    final ref = _storage.refFromURL(downloadUrl);
    final current = await ref.getMetadata();
    final updatedMetadata = <String, String>{
      ...?current.customMetadata,
      'temporary': 'false',
    };
    await ref.updateMetadata(SettableMetadata(customMetadata: updatedMetadata));
  }

  Future<void> deleteFileByUrl(String downloadUrl) async {
    final ref = _storage.refFromURL(downloadUrl);
    await ref.delete();
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
        customMetadata: {'email': email, 'tenantId': tenantId ?? ''},
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

  Future<File> _prepareImageForUpload(File file) async {
    if (kIsWeb) return file;

    try {
      final size = await file.length();
      if (size <= _maxUploadBytes) return file;

      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        '${p.basenameWithoutExtension(file.path)}_upload.jpg',
      );

      final compressed = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: _jpegQuality,
        minWidth: _maxImageWidth,
        minHeight: _maxImageWidth,
        format: CompressFormat.jpeg,
      );

      if (compressed == null) return file;
      final compressedFile = File(compressed.path);
      return await compressedFile.exists() ? compressedFile : file;
    } catch (e) {
      debugPrint('Falha ao otimizar imagem para upload: $e');
      return file;
    }
  }
}

// Provedor do Serviço de Storage do SaaS
final saasPhotoStorageProvider = Provider((ref) => SaaSPhotoStorageService());

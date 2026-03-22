import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class SaaSPhotoStorageService {
  // Bucket fornecido pelo usuário
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://catalogo-ja-89aae.firebasestorage.app',
  );

  /// Sobe uma imagem de produto para a nuvem
  /// Retorna a URL pública de download
  Future<String> uploadProductImage({
    required String tenantId,
    required String productId,
    required String localPath,
    String? label,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('Arquivo local n\u00e3o encontrado: $localPath');
    }

    final ext = p.extension(localPath);
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

    final uploadTask = await ref.putFile(file, metadata);
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
}

// Provedor do Serviço de Storage do SaaS
final saasPhotoStorageProvider = Provider((ref) => SaaSPhotoStorageService());

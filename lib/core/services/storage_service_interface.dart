import 'dart:typed_data';

abstract class IPhotoStorageService {
  /// Sobe uma imagem de categora/coleção
  Future<String?> uploadCategoryImage({
    required String localPath,
    required String categoryId,
    required String tenantId,
    Uint8List? bytes,
  });

  /// Sobe uma imagem de catálogo (banners)
  Future<String?> uploadCatalogImage({
    required String localPath,
    required String catalogId,
    required String tenantId,
    Uint8List? bytes,
  });

  /// Sobe uma imagem de produto
  Future<String> uploadProductImage({
    required String tenantId,
    required String productId,
    required String localPath,
    Uint8List? bytes,
    String? label,
    bool temporary = false,
  });

  /// Finaliza imagem (remove flag temporary se houver)
  Future<void> finalizeProductImage(String downloadUrl);

  /// Deleta um arquivo pela URL
  Future<void> deleteFileByUrl(String downloadUrl);

  /// Deleta as fotos de um produto
  Future<void> deleteProductPhotos({
    required String tenantId,
    required String productId,
  });

  /// Sobe imagem de perfil
  Future<String?> uploadProfileImage({
    required String? tenantId,
    required String email,
    required String? localPath,
    Uint8List? bytes,
  });

  /// Sobe o PDF de um catálogo (Novo requisito para MinIO)
  Future<String?> uploadCatalogPdf({
    required String tenantId,
    required String catalogId,
    required Uint8List pdfBytes,
    String name = 'catalogo',
  });
}

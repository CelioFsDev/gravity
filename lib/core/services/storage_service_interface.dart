import 'dart:typed_data';

abstract class IPhotoStorageService {
  /// Sobe uma imagem de categoria/coleção
  Future<String?> uploadCategoryImage({
    required String tenantId,
    required String categoryId,
    String? localPath,
    Uint8List? bytes,
  });

  /// Sobe uma imagem de categoria (Capa específica)
  Future<String?> uploadCategoryCover({
    required String storeId,
    required String categoryId,
    required Uint8List bytes,
    required String type,
  });

  /// Sobe uma imagem de catálogo (banners)
  Future<String?> uploadCatalogImage({
    required String tenantId,
    required String catalogId,
    String? localPath,
    Uint8List? bytes,
  });

  /// Sobe uma imagem de banner de catálogo
  Future<String?> uploadCatalogBanner({
    required String storeId,
    required String catalogId,
    required Uint8List bytes,
  });

  /// Sobe uma imagem de produto
  Future<String> uploadProductImage({
    required String tenantId,
    required String productId,
    String? localPath,
    Uint8List? bytes,
    String? label,
    String? colorTag,
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

  /// Sobe o PDF de um catálogo
  Future<String?> uploadCatalogPdf({
    required String tenantId,
    required String catalogId,
    required Uint8List pdfBytes,
    String name = 'catalogo',
  });
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:catalogo_ja/core/services/saas_photo_storage_service.dart';
import 'package:image_picker/image_picker.dart';

/// Serviço isolado responsável por interceptar mídias locais ou base64
/// e subir para o Firebase Storage antes de persistir o documento mestre.
class MediaUploadResolver {
  final SaaSPhotoStorageService _storageService;

  MediaUploadResolver(this._storageService);

  bool _isCloudResolvableImageUri(String uri) {
    final trimmed = uri.trim();
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('gs://') ||
        trimmed.startsWith('tenants/') ||
        trimmed.startsWith('public_catalogs/');
  }

  /// Recebe um caminho local/base64, sobe no Storage e retorna a URL remota definitiva.
  /// Se já for uma URL remota válida (http/gs://), retorna imediatamente.
  Future<String> resolveImageUri({
    required String localUri,
    required String entityId,
    required String tenantId,
    String? label,
  }) async {
    final isLocal =
        localUri.startsWith('data:') ||
        localUri.startsWith('blob:') ||
        !_isCloudResolvableImageUri(localUri);

    if (!isLocal) {
      return localUri;
    }

    Uint8List? webBytes;
    if (kIsWeb) {
      if (localUri.startsWith('data:')) {
        final commaIndex = localUri.indexOf(',');
        if (commaIndex != -1) {
          webBytes = base64Decode(localUri.substring(commaIndex + 1));
        }
      } else if (localUri.startsWith('blob:')) {
        final xFile = XFile(localUri);
        webBytes = await xFile.readAsBytes();
      }
    }

    final cloudUrl = await _storageService.uploadProductImage(
      localPath: localUri,
      productId: entityId, // Reaproveitando o bucket logicamente
      tenantId: tenantId,
      bytes: webBytes,
      label: label,
    );

    return cloudUrl.isNotEmpty ? cloudUrl : localUri;
  }
}

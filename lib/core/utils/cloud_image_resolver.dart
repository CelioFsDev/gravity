import 'package:firebase_storage/firebase_storage.dart';

class CloudImageResolver {
  static Future<String?> resolveCloudImageUrl(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    final trimmed = path.trim();

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (trimmed.startsWith('gs://') || trimmed.startsWith('tenants/') || trimmed.startsWith('public_catalogs/') || trimmed.startsWith('users/')) {
      try {
        final ref = trimmed.startsWith('gs://')
            ? FirebaseStorage.instanceFor(bucket: 'gs://catalogo-ja-89aae.firebasestorage.app').refFromURL(trimmed)
            : FirebaseStorage.instanceFor(bucket: 'gs://catalogo-ja-89aae.firebasestorage.app').ref().child(trimmed);
        return await ref.getDownloadURL();
      } catch (e) {
        print('Erro ao resolver URL de imagem na nuvem ($trimmed): $e');
        return null;
      }
    }
    return null;
  }
}

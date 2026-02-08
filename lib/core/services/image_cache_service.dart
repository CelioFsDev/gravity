import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'image_cache_service.g.dart';

@Riverpod(keepAlive: true)
ImageCacheService imageCacheService(ImageCacheServiceRef ref) {
  return ImageCacheService();
}

class ImageCacheService {
  static const String _imagesDirName = 'product_images';

  /// Downloads an image from [url] and saves it locally.
  /// Returns the absolute path of the saved file, or null if failed.
  Future<String?> downloadAndCacheImage(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        return null;
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) return null;

      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(directory.path, _imagesDirName));

      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Try to keep extension from URL or semantic
      String extension = p.extension(uri.path).toLowerCase();
      if (extension.isEmpty ||
          !['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
        // Simple fallback or detection could be better, but acceptable for now
        extension = '.jpg';
      }

      // We deduplicate by content hash? Or just random UUID?
      // User requested "dedupe paths", maybe simple checking if we already have it?
      // For now, unique file per download to ensure safety.
      final fileName = '${const Uuid().v4()}$extension';
      final file = File(p.join(imagesDir.path, fileName));

      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      // Log error?
      return null;
    }
  }

  /// Copies a local file to the product images directory.
  Future<String?> cacheLocalFile(File sourceFile) async {
    try {
      if (!await sourceFile.exists()) return null;

      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(directory.path, _imagesDirName));

      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final extension = p.extension(sourceFile.path);
      final fileName = '${const Uuid().v4()}$extension';
      final targetFile = File(p.join(imagesDir.path, fileName));

      await sourceFile.copy(targetFile.path);
      return targetFile.path;
    } catch (e) {
      return null;
    }
  }
}

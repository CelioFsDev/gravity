import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_optimizer_service.g.dart';

@riverpod
class ImageOptimizerService extends _$ImageOptimizerService {
  @override
  void build() {}

  Future<File?> compressImage(
    File file, {
    int quality = 80,
    int maxWidth = 1200,
  }) async {
    // flutter_image_compress uses native code, skip on web
    if (kIsWeb) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        "${DateTime.now().millisecondsSinceEpoch}_optimized.jpg",
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxWidth,
        format: CompressFormat.jpeg,
      );

      if (result == null) return null;
      return File(result.path);
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  Future<Uint8List?> compressBytes(
    Uint8List bytes, {
    int quality = 80,
    int maxWidth = 1200,
  }) async {
    // flutter_image_compress uses native code, skip on web
    if (kIsWeb) return null;

    try {
      return await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxWidth,
      );
    } catch (e) {
      print('Error compressing bytes: $e');
      return null;
    }
  }
}

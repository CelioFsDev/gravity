import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalMediaService {
  static Future<String> savePickedImage(
    File picked, {
    required String folder,
    required String fileName,
  }) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(baseDir.path, folder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final targetPath = p.join(targetDir.path, fileName);
    await picked.copy(targetPath);
    return targetPath;
  }
}

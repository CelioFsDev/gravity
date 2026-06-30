import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'backup_file_service.dart';

BackupFileService getBackupFileService() => BackupFileServiceWeb();

class BackupFileServiceWeb implements BackupFileService {
  @override
  Future<Uint8List?> pickBackupFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;
      return result.files.single.bytes;
    } catch (e) {
      debugPrint('Erro ao selecionar arquivo na Web: $e');
      return null;
    }
  }

  @override
  Future<String?> saveBackupFile(Uint8List bytes, {required String fileName}) async {
    try {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      return url;
    } catch (e) {
      debugPrint('Erro ao salvar arquivo na Web: $e');
      return null;
    }
  }
}

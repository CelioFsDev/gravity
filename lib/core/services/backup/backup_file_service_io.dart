import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'backup_file_service.dart';

BackupFileService getBackupFileService() => BackupFileServiceIo();

class BackupFileServiceIo implements BackupFileService {
  @override
  Future<Uint8List?> pickBackupFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;
      
      final file = result.files.single;
      if (file.bytes != null) {
        return file.bytes;
      }
      
      if (file.path != null) {
        return await File(file.path!).readAsBytes();
      }
      
      return null;
    } catch (e) {
      debugPrint('Erro ao selecionar arquivo no IO: $e');
      return null;
    }
  }

  @override
  Future<String?> saveBackupFile(Uint8List bytes, {required String fileName}) async {
    try {
      final outputPath = await FilePicker.saveFile(
        dialogTitle: 'Salvar backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [fileName.split('.').last],
        bytes: bytes,
      );

      if (outputPath == null) return null;

      final file = File(outputPath);
      await file.writeAsBytes(bytes);
      return outputPath;
    } catch (e) {
      debugPrint('Erro ao salvar arquivo no IO: $e');
      return null;
    }
  }
}

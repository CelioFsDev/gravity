import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'backup_file_service_stub.dart'
    if (dart.library.html) 'backup_file_service_web.dart'
    if (dart.library.io) 'backup_file_service_io.dart';

abstract class BackupFileService {
  /// Picks a JSON or ZIP backup file from the user's device.
  /// Returns the bytes of the selected file, or null if cancelled.
  Future<Uint8List?> pickBackupFile();

  /// Saves the given [bytes] as a backup file.
  /// Returns the path/URL where the file was saved, or null if cancelled.
  Future<String?> saveBackupFile(Uint8List bytes, {required String fileName});

  /// Factory constructor that returns the correct implementation for the current platform.
  factory BackupFileService() => getBackupFileService();
}

final backupFileServiceProvider = Provider<BackupFileService>((ref) {
  return BackupFileService();
});

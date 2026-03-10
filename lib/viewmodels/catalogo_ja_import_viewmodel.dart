import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:catalogo_ja/core/services/catalogo_ja_package_service.dart';

import 'package:file_picker/file_picker.dart';
import 'package:catalogo_ja/core/services/dto/catalogo_ja_export_dtos.dart';
import 'package:catalogo_ja/core/services/export_import_service.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalog_public_viewmodel.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalogo_ja_import_viewmodel.g.dart';

class CatalogoJaImportState {
  final int step; // 0: Pick File, 1: Preview/Mode, 2: Result
  final bool isLoading;
  final String? errorMessage;
  final CatalogoJaExportPayload? payload;
  final ImportPreview? preview;
  final ImportMode selectedMode;
  final ImportResult? result;
  final String? extractDirPath; // Path to temp dir for ZIP imports
  final Uint8List? packageBytes;
  final bool isZipPackage;

  CatalogoJaImportState({
    this.step = 0,
    this.isLoading = false,
    this.errorMessage,
    this.payload,
    this.preview,
    this.selectedMode = ImportMode.merge,
    this.result,
    this.extractDirPath,
    this.packageBytes,
    this.isZipPackage = false,
  });

  CatalogoJaImportState copyWith({
    int? step,
    bool? isLoading,
    String? errorMessage,
    CatalogoJaExportPayload? payload,
    ImportPreview? preview,
    ImportMode? selectedMode,
    ImportResult? result,
    String? extractDirPath,
    Uint8List? packageBytes,
    bool? isZipPackage,
  }) {
    return CatalogoJaImportState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      payload: payload ?? this.payload,
      preview: preview ?? this.preview,
      selectedMode: selectedMode ?? this.selectedMode,
      result: result ?? this.result,
      extractDirPath: extractDirPath ?? this.extractDirPath,
      packageBytes: packageBytes ?? this.packageBytes,
      isZipPackage: isZipPackage ?? this.isZipPackage,
    );
  }
}

@riverpod
class CatalogoJaImportViewModel extends _$CatalogoJaImportViewModel {
  @override
  CatalogoJaImportState build() {
    return CatalogoJaImportState();
  }

  void setMode(ImportMode mode) {
    state = state.copyWith(selectedMode: mode);
  }

  Future<void> pickFile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip'],
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.single;
        final filePath = pickedFile.path;
        final fileBytes = pickedFile.bytes;
        final exportService = ref.read(exportImportServiceProvider);
        CatalogoJaExportPayload payload;
        String? extractDir;
        Uint8List? packageBytes;

        bool isActuallyZip = pickedFile.name.toLowerCase().endsWith('.zip');
        if (!isActuallyZip && fileBytes != null && fileBytes.length >= 2) {
          isActuallyZip = fileBytes[0] == 0x50 && fileBytes[1] == 0x4B;
        } else if (!isActuallyZip && filePath != null) {
          try {
            final file = File(filePath);
            if (await file.exists()) {
              final bytes = await file.openRead(0, 2).first;
              if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
                isActuallyZip = true;
              }
            }
          } catch (_) {
            // If checking header fails, we treat it based on extension
          }
        }

        if (isActuallyZip) {
          final packageService = ref.read(catalogoJaPackageServiceProvider);
          if (kIsWeb) {
            if (fileBytes == null) {
              throw Exception('Nao foi possivel ler os bytes do arquivo ZIP.');
            }
            payload = await exportService.parsePayloadFromBytes(
              _extractProductsJsonFromZip(fileBytes),
            );
            packageBytes = fileBytes;
          } else {
            if (filePath == null) {
              throw Exception('Caminho do arquivo ZIP indisponivel.');
            }
            final (p, dir) = await packageService.preparePackage(File(filePath));
            payload = p;
            extractDir = dir.path;
          }
        } else {
          if (fileBytes != null) {
            payload = await exportService.parsePayloadFromBytes(fileBytes);
          } else {
            if (filePath == null) {
              throw Exception('Caminho do arquivo JSON indisponivel.');
            }
            payload = await exportService.parsePayload(File(filePath));
          }
        }

        final preview = await exportService.previewImport(payload);

        state = state.copyWith(
          payload: payload,
          preview: preview,
          extractDirPath: extractDir,
          packageBytes: packageBytes,
          isZipPackage: isActuallyZip,
          step: 1, // Move to Preview
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao ler arquivo: $e',
      );
    }
  }

  Future<void> executeImport() async {
    if (state.payload == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      ImportResult result;

      if (state.extractDirPath != null) {
        // ZIP IMPORT
        final packageService = ref.read(catalogoJaPackageServiceProvider);
        final report = await packageService.importPackageFromDir(
          payload: state.payload!,
          extractDir: Directory(state.extractDirPath!),
          mode: state.selectedMode,
        );
        result = ImportResult(
          successCount: report.createdCount,
          skipCount: 0,
          errorCount: report.warnings.length,
          errors: report.warnings,
        );
      } else if (state.isZipPackage && state.packageBytes != null) {
        final packageService = ref.read(catalogoJaPackageServiceProvider);
        final report = await packageService.importPackageFromBytes(
          zipBytes: state.packageBytes!,
          mode: state.selectedMode,
        );
        result = ImportResult(
          successCount: report.createdCount,
          skipCount: 0,
          errorCount: report.warnings.length,
          errors: report.warnings,
        );
      } else {
        // JSON IMPORT
        final service = ref.read(exportImportServiceProvider);
        result = await service.executeImport(
          state.payload!,
          state.selectedMode,
        );
      }

      state = state.copyWith(
        result: result,
        step: 2, // Move to Result
        isLoading: false,
      );

      // Refresh relevant data providers
      _notifyChanges();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao importar: $e',
      );
    }
  }

  void reset() {
    if (state.extractDirPath != null) {
      final dir = Directory(state.extractDirPath!);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
    state = CatalogoJaImportState();
  }

  void _notifyChanges() {
    ref.invalidate(productsViewModelProvider);
    ref.invalidate(categoriesViewModelProvider);
    ref.invalidate(catalogsViewModelProvider);
    ref.invalidate(catalogPublicProvider);
  }

  Uint8List _extractProductsJsonFromZip(Uint8List zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    for (final file in archive) {
      if (file.isFile && file.name.toLowerCase() == 'products.json') {
        return Uint8List.fromList((file.content as List).cast<int>());
      }
    }
    throw Exception('Invalid package: products.json missing');
  }
}

import 'dart:io';
import 'package:catalogo_ja/core/services/catalogo_ja_package_service.dart';

import 'package:file_picker/file_picker.dart';
import 'package:catalogo_ja/core/services/dto/catalogo_ja_export_dtos.dart';
import 'package:catalogo_ja/core/services/export_import_service.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalog_public_viewmodel.dart';
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

  CatalogoJaImportState({
    this.step = 0,
    this.isLoading = false,
    this.errorMessage,
    this.payload,
    this.preview,
    this.selectedMode = ImportMode.merge,
    this.result,
    this.extractDirPath,
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
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final exportService = ref.read(exportImportServiceProvider);
        CatalogoJaExportPayload payload;
        String? extractDir;

        // More robust ZIP detection: Check extension OR check file header (PK)
        bool isActuallyZip = filePath.toLowerCase().endsWith('.zip');
        if (!isActuallyZip) {
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
          final (p, dir) = await packageService.preparePackage(File(filePath));
          payload = p;
          extractDir = dir.path;
        } else {
          payload = await exportService.parsePayload(File(filePath));
        }

        final preview = await exportService.previewImport(payload);

        state = state.copyWith(
          payload: payload,
          preview: preview,
          extractDirPath: extractDir,
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
}

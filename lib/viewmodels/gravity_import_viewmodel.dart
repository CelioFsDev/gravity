import 'dart:io';
import 'package:gravity/core/services/gravity_package_service.dart';

import 'package:file_picker/file_picker.dart';
import 'package:gravity/core/services/dto/gravity_export_dtos.dart';
import 'package:gravity/core/services/export_import_service.dart';
import 'package:gravity/viewmodels/products_viewmodel.dart';
import 'package:gravity/viewmodels/categories_viewmodel.dart';
import 'package:gravity/viewmodels/catalogs_viewmodel.dart';
import 'package:gravity/viewmodels/catalog_public_viewmodel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gravity_import_viewmodel.g.dart';

class GravityImportState {
  final int step; // 0: Pick File, 1: Preview/Mode, 2: Result
  final bool isLoading;
  final String? errorMessage;
  final GravityExportPayload? payload;
  final ImportPreview? preview;
  final ImportMode selectedMode;
  final ImportResult? result;
  final String? extractDirPath; // Path to temp dir for ZIP imports

  GravityImportState({
    this.step = 0,
    this.isLoading = false,
    this.errorMessage,
    this.payload,
    this.preview,
    this.selectedMode = ImportMode.merge,
    this.result,
    this.extractDirPath,
  });

  GravityImportState copyWith({
    int? step,
    bool? isLoading,
    String? errorMessage,
    GravityExportPayload? payload,
    ImportPreview? preview,
    ImportMode? selectedMode,
    ImportResult? result,
    String? extractDirPath,
  }) {
    return GravityImportState(
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
class GravityImportViewModel extends _$GravityImportViewModel {
  @override
  GravityImportState build() {
    return GravityImportState();
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
        GravityExportPayload payload;
        String? extractDir;

        // More robust ZIP detection: Check extension OR check file header (PK)
        bool isActuallyZip = filePath.toLowerCase().endsWith('.zip');
        if (!isActuallyZip) {
          final file = File(filePath);
          final bytes = await file.openRead(0, 2).first;
          if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
            isActuallyZip = true;
          }
        }

        if (isActuallyZip) {
          final packageService = ref.read(gravityPackageServiceProvider);
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
        final packageService = ref.read(gravityPackageServiceProvider);
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
    state = GravityImportState();
  }

  void _notifyChanges() {
    ref.invalidate(productsViewModelProvider);
    ref.invalidate(categoriesViewModelProvider);
    ref.invalidate(catalogsViewModelProvider);
    ref.invalidate(catalogPublicProvider);
  }
}

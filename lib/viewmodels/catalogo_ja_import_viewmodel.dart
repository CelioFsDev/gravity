import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:catalogo_ja/core/services/catalogo_ja_package_service.dart';

import 'package:catalogo_ja/core/services/dto/catalogo_ja_export_dtos.dart';
import 'package:catalogo_ja/core/services/export_import_service.dart';
import 'package:catalogo_ja/core/services/backup/backup_file_service.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalog_public_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:catalogo_ja/core/utils/user_friendly_error.dart';
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
  final double progressPercent;
  final String? progressMessage;
  final bool isCancelled;

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
    this.progressPercent = 0.0,
    this.progressMessage,
    this.isCancelled = false,
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
    double? progressPercent,
    String? progressMessage,
    bool? isCancelled,
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
      progressPercent: progressPercent ?? this.progressPercent,
      progressMessage: progressMessage ?? this.progressMessage,
      isCancelled: isCancelled ?? this.isCancelled,
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

  void cancelImport() {
    state = state.copyWith(isCancelled: true);
  }

  void _updateProgress(double percent, String message) {
    state = state.copyWith(progressPercent: percent, progressMessage: message);
  }

  Future<void> pickFile() async {
    // 🛡️ Segurança: Evita abrir o seletor se já houver um processo em curso
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final backupService = ref.read(backupFileServiceProvider);
      final fileBytes = await backupService.pickBackupFile();

      if (fileBytes != null && fileBytes.isNotEmpty) {
        final exportService = ref.read(exportImportServiceProvider);
        CatalogoJaExportPayload payload;
        Uint8List? packageBytes;

        final isActuallyZip =
            fileBytes.length >= 2 &&
            fileBytes[0] == 0x50 &&
            fileBytes[1] == 0x4B;

        if (isActuallyZip) {
          payload = await exportService.parsePayloadFromBytes(
            _extractProductsJsonFromZip(fileBytes),
          );
          packageBytes = fileBytes;
        } else {
          payload = await exportService.parsePayloadFromBytes(fileBytes);
        }

        final preview = await exportService.previewImport(payload);

        state = state.copyWith(
          payload: payload,
          preview: preview,
          extractDirPath: null,
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
        errorMessage: UserFriendlyError.message(
          e,
          fallback:
              'N\u00e3o foi poss\u00edvel ler esse backup. Verifique se o arquivo est\u00e1 correto e tente novamente.',
        ),
      );
    }
  }

  Future<void> executeImport() async {
    if (state.payload == null) return;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isCancelled: false,
      progressPercent: 0.0,
      progressMessage: 'Preparando importação...',
    );

    try {
      ImportResult result;
      final tenantId = ref.read(currentTenantProvider).asData?.value?.id;

      bool isCancelled() => state.isCancelled;

      if (state.extractDirPath != null) {
        // ZIP IMPORT
        final packageService = ref.read(catalogoJaPackageServiceProvider);
        final report = await packageService.importPackageFromDir(
          payload: state.payload!,
          extractDir: Directory(state.extractDirPath!),
          mode: state.selectedMode,
          tenantId: tenantId,
          onProgress: _updateProgress,
          isCancelled: isCancelled,
        ).timeout(const Duration(minutes: 10));
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
          tenantId: tenantId,
          onProgress: _updateProgress,
          isCancelled: isCancelled,
        ).timeout(const Duration(minutes: 10));
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
          tenantId: tenantId,
          onProgress: _updateProgress,
          isCancelled: isCancelled,
        ).timeout(const Duration(minutes: 10));
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
        errorMessage: UserFriendlyError.message(
          e,
          fallback:
              'N\u00e3o foi poss\u00edvel importar o backup agora. Tente novamente em alguns instantes.',
        ),
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

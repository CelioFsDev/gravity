import 'package:catalogo_ja/core/services/catalogo_ja_package_service.dart';
import 'package:catalogo_ja/core/services/whatsapp_share_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'product_export_viewmodel.g.dart';

class ProductExportState {
  final bool isLoading;
  final double progress;
  final String? message;
  final String? errorMessage;
  final String? successMessage;

  ProductExportState({
    this.isLoading = false,
    this.progress = 0,
    this.message,
    this.errorMessage,
    this.successMessage,
  });

  ProductExportState copyWith({
    bool? isLoading,
    double? progress,
    String? message,
    String? errorMessage,
    String? successMessage,
  }) {
    return ProductExportState(
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      errorMessage: errorMessage ?? this.errorMessage,
      successMessage: successMessage ?? this.successMessage,
    );
  }
}

@riverpod
class ProductExportViewModel extends _$ProductExportViewModel {
  @override
  ProductExportState build() {
    return ProductExportState();
  }

  Future<void> exportPackage() async {
    state = state.copyWith(
      isLoading: true,
      progress: 0.01,
      message: 'Preparando arquivos...',
      errorMessage: null,
      successMessage: null,
    );

    try {
      // The provided code edit seems to be a partial snippet from a different context
      // that includes `_runWithLoadingDialog`, `context`, `catalogProducts`, `availableCollections`,
      // `DateFormat`, `_sanitizeFileNamePart`, and `catalog.name`.
      // Since these are not present in the current file, I will adapt the change
      // to fit the existing structure and variables, assuming the intent is to
      // update the export logic to use the new `exportPackage` method signature
      // and then share the resulting bytes.

      // Original code:
      // final CatalogoJaService = ref.read(catalogoJaPackageServiceProvider);
      // final bytes = await CatalogoJaService.exportPackage(
      //   onProgress: (progress, message) {
      //     state = state.copyWith(progress: progress, message: message);
      //   },
      // );

      // Adapted change:
      final bytes = await ref
          .read(catalogoJaPackageServiceProvider)
          .exportPackage(
            onProgress: (progress, message) {
              state = state.copyWith(progress: progress, message: message);
            },
          );

      // Original fileName generation:
      // final fileName = 'CatalogoJa_Backup_${DateTime.now().millisecondsSinceEpoch}.zip';

      // Adapted fileName generation (simplified from the provided snippet as context is missing):
      final fileName =
          'CatalogoJa_Backup_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.zip';

      await WhatsAppShareService.shareFile(
        bytes: bytes,
        fileName: fileName,
        // Original text: 'Backup do Cat\u00e1logo CatalogoJa'
        // Adapted text (from the provided snippet, but simplified as catalog.name is missing):
        text: 'Confira o pacote de dados do seu catálogo!',
        mimeType: 'application/zip',
      );

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Exporta\u00e7\u00e3o conclu\u00edda',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao exportar: $e',
      );
    }
  }
}

import 'package:gravity/core/services/gravity_package_service.dart';
import 'package:gravity/core/services/whatsapp_share_service.dart';
import 'package:path/path.dart' as p;
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
      final gravityService = ref.read(gravityPackageServiceProvider);
      final zipFile = await gravityService.exportPackage(
        onProgress: (progress, message) {
          state = state.copyWith(progress: progress, message: message);
        },
      );

      await WhatsAppShareService.shareFile(
        bytes: await zipFile.readAsBytes(),
        fileName: p.basename(zipFile.path),
        text: 'Backup do Catálogo Gravity',
        mimeType: 'application/zip',
      );

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Exportação concluída',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao exportar: $e',
      );
    }
  }
}

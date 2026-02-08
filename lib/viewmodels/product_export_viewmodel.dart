
import 'package:gravity/core/services/gravity_package_service.dart';
import 'package:gravity/core/services/whatsapp_share_service.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'product_export_viewmodel.g.dart';

class ProductExportState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  ProductExportState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  ProductExportState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return ProductExportState(
      isLoading: isLoading ?? this.isLoading,
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
      errorMessage: null,
      successMessage: null,
    );

    try {
      final gravityService = ref.read(gravityPackageServiceProvider);
      final zipFile = await gravityService.exportPackage();

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

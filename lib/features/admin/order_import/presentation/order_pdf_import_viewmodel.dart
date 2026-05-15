import 'package:catalogo_ja/data/repositories/firestore_catalogs_repository.dart';
import 'package:catalogo_ja/data/repositories/firestore_products_repository.dart';
import 'package:catalogo_ja/features/admin/order_import/data/order_pdf_parser_service.dart';
import 'package:catalogo_ja/features/admin/order_import/data/order_to_catalog_service.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

enum OrderPdfImportStatus {
  idle,
  loadingPdf,
  parsing,
  readyToCreate,
  creatingCatalog,
  success,
  error,
}

class OrderPdfImportState {
  final OrderPdfImportStatus status;
  final String? selectedFileName;
  final int? selectedFileSize;
  final String catalogName;
  final List<String> references;
  final List<Product> productsFound;
  final List<String> referencesNotFound;
  final Catalog? createdCatalog;
  final String? errorMessage;

  const OrderPdfImportState({
    required this.status,
    required this.catalogName,
    this.selectedFileName,
    this.selectedFileSize,
    this.references = const [],
    this.productsFound = const [],
    this.referencesNotFound = const [],
    this.createdCatalog,
    this.errorMessage,
  });

  factory OrderPdfImportState.initial() {
    return OrderPdfImportState(
      status: OrderPdfImportStatus.idle,
      catalogName: _defaultCatalogName(),
    );
  }

  bool get isBusy =>
      status == OrderPdfImportStatus.loadingPdf ||
      status == OrderPdfImportStatus.parsing ||
      status == OrderPdfImportStatus.creatingCatalog;

  bool get canCreate =>
      status == OrderPdfImportStatus.readyToCreate &&
      productsFound.isNotEmpty &&
      catalogName.trim().isNotEmpty;

  OrderPdfImportState copyWith({
    OrderPdfImportStatus? status,
    String? selectedFileName,
    int? selectedFileSize,
    String? catalogName,
    List<String>? references,
    List<Product>? productsFound,
    List<String>? referencesNotFound,
    Catalog? createdCatalog,
    String? errorMessage,
    bool clearCreatedCatalog = false,
    bool clearError = false,
  }) {
    return OrderPdfImportState(
      status: status ?? this.status,
      selectedFileName: selectedFileName ?? this.selectedFileName,
      selectedFileSize: selectedFileSize ?? this.selectedFileSize,
      catalogName: catalogName ?? this.catalogName,
      references: references ?? this.references,
      productsFound: productsFound ?? this.productsFound,
      referencesNotFound: referencesNotFound ?? this.referencesNotFound,
      createdCatalog: clearCreatedCatalog
          ? null
          : (createdCatalog ?? this.createdCatalog),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  static String _defaultCatalogName() {
    final formatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    return 'Pedido importado - $formatted';
  }
}

final orderPdfParserServiceProvider = Provider<OrderPdfParserService>((ref) {
  return OrderPdfParserService();
});

final orderPdfTextExtractorServiceProvider =
    Provider<OrderPdfTextExtractorService>((ref) {
      return OrderPdfTextExtractorService();
    });

final orderToCatalogServiceProvider = Provider<OrderToCatalogService>((ref) {
  return OrderToCatalogService(
    productsRepository: ref.watch(syncProductsRepositoryProvider),
    catalogsRepository: ref.watch(syncCatalogsRepositoryProvider),
  );
});

final orderPdfImportViewModelProvider =
    StateNotifierProvider.autoDispose<
      OrderPdfImportViewModel,
      OrderPdfImportState
    >((ref) {
      return OrderPdfImportViewModel(
        ref: ref,
        parserService: ref.watch(orderPdfParserServiceProvider),
        textExtractorService: ref.watch(orderPdfTextExtractorServiceProvider),
        catalogService: ref.watch(orderToCatalogServiceProvider),
      );
    });

class OrderPdfImportViewModel extends StateNotifier<OrderPdfImportState> {
  final Ref ref;
  final OrderPdfParserService parserService;
  final OrderPdfTextExtractorService textExtractorService;
  final OrderToCatalogService catalogService;

  OrderPdfImportViewModel({
    required this.ref,
    required this.parserService,
    required this.textExtractorService,
    required this.catalogService,
  }) : super(OrderPdfImportState.initial());

  void updateCatalogName(String value) {
    state = state.copyWith(catalogName: value, clearError: true);
  }

  Future<void> pickAndParsePdf() async {
    state = state.copyWith(
      status: OrderPdfImportStatus.loadingPdf,
      references: const [],
      productsFound: const [],
      referencesNotFound: const [],
      clearCreatedCatalog: true,
      clearError: true,
    );

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(
          status: OrderPdfImportStatus.error,
          errorMessage: 'Nenhum PDF foi selecionado.',
        );
        return;
      }

      final file = result.files.single;
      debugPrint('Order PDF selected: ${file.name} (${file.size} bytes)');

      if (!file.name.toLowerCase().endsWith('.pdf')) {
        state = state.copyWith(
          status: OrderPdfImportStatus.error,
          selectedFileName: file.name,
          selectedFileSize: file.size,
          errorMessage: 'Selecione um arquivo PDF válido.',
        );
        return;
      }

      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        state = state.copyWith(
          status: OrderPdfImportStatus.error,
          selectedFileName: file.name,
          selectedFileSize: file.size,
          errorMessage:
              'Não foi possível ler o arquivo selecionado. Tente escolher o PDF novamente.',
        );
        return;
      }

      state = state.copyWith(
        status: OrderPdfImportStatus.parsing,
        selectedFileName: file.name,
        selectedFileSize: file.size,
      );

      final text = textExtractorService.extractTextFromBytes(bytes);
      debugPrint('Order PDF extracted text length: ${text.length}');

      if (text.trim().isEmpty) {
        state = state.copyWith(
          status: OrderPdfImportStatus.error,
          errorMessage:
              'Este PDF parece não conter texto selecionável. Nesta versão, envie um PDF gerado pelo sistema/CRM, não uma imagem escaneada.',
        );
        return;
      }

      final references = parserService.extractReferencesFromText(text);
      debugPrint(
        'Order PDF references found (${references.length}): ${references.join(', ')}',
      );

      if (references.isEmpty) {
        state = state.copyWith(
          status: OrderPdfImportStatus.error,
          references: const [],
          productsFound: const [],
          referencesNotFound: const [],
          errorMessage: 'Nenhuma referência encontrada no PDF.',
        );
        return;
      }

      final match = await catalogService.matchReferences(references);
      debugPrint(
        'Order PDF products found (${match.productsFound.length}): '
        '${match.productsFound.map((product) => '${product.reference} ${product.name}').join(', ')}',
      );
      debugPrint(
        'Order PDF references not found (${match.referencesNotFound.length}): '
        '${match.referencesNotFound.join(', ')}',
      );

      state = state.copyWith(
        status: match.productsFound.isEmpty
            ? OrderPdfImportStatus.error
            : OrderPdfImportStatus.readyToCreate,
        references: match.references,
        productsFound: match.productsFound,
        referencesNotFound: match.referencesNotFound,
        errorMessage: match.productsFound.isEmpty
            ? 'Nenhum produto encontrado no cadastro.'
            : null,
        clearError: match.productsFound.isNotEmpty,
      );
    } catch (error, stackTrace) {
      debugPrint('Order PDF import error: $error\n$stackTrace');
      state = state.copyWith(
        status: OrderPdfImportStatus.error,
        errorMessage:
            'Não foi possível processar este PDF. Verifique o arquivo e tente novamente.',
      );
    }
  }

  Future<void> createCatalog() async {
    if (state.references.isEmpty) {
      state = state.copyWith(
        status: OrderPdfImportStatus.error,
        errorMessage: 'Nenhuma referência encontrada no PDF.',
      );
      return;
    }

    if (state.productsFound.isEmpty) {
      state = state.copyWith(
        status: OrderPdfImportStatus.error,
        errorMessage: 'Nenhum produto encontrado no cadastro.',
      );
      return;
    }

    if (state.catalogName.trim().isEmpty) {
      state = state.copyWith(
        status: OrderPdfImportStatus.readyToCreate,
        errorMessage: 'Informe o nome do catálogo.',
      );
      return;
    }

    state = state.copyWith(
      status: OrderPdfImportStatus.creatingCatalog,
      clearError: true,
    );

    try {
      final catalog = await catalogService.createCatalogFromReferences(
        catalogName: state.catalogName,
        references: state.references,
      );
      debugPrint(
        'Order PDF catalog created: ${catalog.id} with ${catalog.productIds.length} products',
      );
      ref.invalidate(catalogsViewModelProvider);
      state = state.copyWith(
        status: OrderPdfImportStatus.success,
        createdCatalog: catalog,
      );
    } catch (error, stackTrace) {
      debugPrint('Order PDF catalog creation error: $error\n$stackTrace');
      state = state.copyWith(
        status: OrderPdfImportStatus.error,
        errorMessage:
            'Não foi possível criar o catálogo. Tente novamente em instantes.',
      );
    }
  }
}

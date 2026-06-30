import 'dart:typed_data';
import 'package:catalogo_ja/core/services/stock_pdf_import_service.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_variant.dart';
import 'package:catalogo_ja/models/stock_import_history.dart';
import 'package:catalogo_ja/models/stock_pdf_row.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class StockImportState {
  final bool isProcessing;
  final String? fileName;
  final StockPdfMetadata? metadata;
  final List<StockPdfRow> rows;
  final StockImportMode mode;
  final String? targetStoreId;
  final String? error;
  final bool isApplied;
  
  StockImportState({
    this.isProcessing = false,
    this.fileName,
    this.metadata,
    this.rows = const [],
    this.mode = StockImportMode.replace,
    this.targetStoreId,
    this.error,
    this.isApplied = false,
  });

  StockImportState copyWith({
    bool? isProcessing,
    String? fileName,
    StockPdfMetadata? metadata,
    List<StockPdfRow>? rows,
    StockImportMode? mode,
    String? targetStoreId,
    String? error,
    bool? isApplied,
  }) {
    return StockImportState(
      isProcessing: isProcessing ?? this.isProcessing,
      fileName: fileName ?? this.fileName,
      metadata: metadata ?? this.metadata,
      rows: rows ?? this.rows,
      mode: mode ?? this.mode,
      targetStoreId: targetStoreId ?? this.targetStoreId,
      error: error, // Clear error if not provided
      isApplied: isApplied ?? this.isApplied,
    );
  }
}

final stockImportViewModelProvider = StateNotifierProvider<StockImportViewModel, StockImportState>((ref) {
  return StockImportViewModel(ref);
});

class StockImportViewModel extends StateNotifier<StockImportState> {
  final Ref _ref;
  final _service = StockPdfImportService();
  
  StockImportViewModel(this._ref) : super(StockImportState());

  void setMode(StockImportMode mode) {
    state = state.copyWith(mode: mode);
    _resolveRows();
  }

  void setTargetStoreId(String? storeId) {
    state = state.copyWith(targetStoreId: storeId);
  }

  void clear() {
    state = StockImportState();
  }

  Future<void> processPdf(Uint8List bytes, String fileName) async {
    state = state.copyWith(isProcessing: true, fileName: fileName, error: null);
    try {
      final result = await _service.parsePdf(bytes);
      state = state.copyWith(
        metadata: result.metadata,
        rows: result.rows,
      );
      _resolveRows();
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: 'Erro ao ler PDF: $e');
    }
  }

  void _resolveRows() {
    final productsState = _ref.read(productsViewModelProvider).valueOrNull;
    final allProducts = productsState?.allProducts ?? [];
    
    final resolvedRows = <StockPdfRow>[];
    
    for (var row in state.rows) {
      if (row.status == StockPdfRowStatus.colorNotFound || row.status == StockPdfRowStatus.sizeNotFound) {
         // Keep existing status if it failed parsing validation
         resolvedRows.add(_calculateFinalStock(row));
         continue;
      }

      // 1. Find product by ref
      final product = allProducts.where((p) => p.ref == row.reference).firstOrNull;
      if (product == null) {
        row.status = StockPdfRowStatus.productNotFound;
        resolvedRows.add(_calculateFinalStock(row));
        continue;
      }
      
      if (!product.isActive) {
        row.status = StockPdfRowStatus.inactiveProduct;
      }
      
      row.resolvedProductId = product.id;

      // 2. Find variant by color and size
      // Variantes em attributes geralmente tem { 'color': 'PRETO', 'size': 'M' } ou parecidos.
      // O codigo da cor pode não estar lá, então buscamos por colorName ou colorCode
      ProductVariant? matchedVariant;
      for (var v in product.variants) {
         final vColor = v.attributes['color']?.toUpperCase() ?? '';
         final vSize = v.attributes['size']?.toUpperCase() ?? '';
         
         if ((vColor == row.colorName.toUpperCase() || vColor == row.colorCode) && vSize == row.size.toUpperCase()) {
            matchedVariant = v;
            break;
         }
      }

      if (matchedVariant != null) {
        row.resolvedVariantSku = matchedVariant.sku;
        row.currentStock = matchedVariant.stock;
      } else {
        row.currentStock = 0; // It might be created later or flagged as not found
      }

      resolvedRows.add(_calculateFinalStock(row));
    }

    state = state.copyWith(rows: resolvedRows, isProcessing: false);
  }

  StockPdfRow _calculateFinalStock(StockPdfRow row) {
     int finalStock = row.currentStock;
     if (row.status == StockPdfRowStatus.productNotFound || 
         row.status == StockPdfRowStatus.colorNotFound ||
         row.status == StockPdfRowStatus.sizeNotFound) {
        row.finalStock = 0;
        return row;
     }

     switch (state.mode) {
       case StockImportMode.replace:
         finalStock = row.quantity;
         break;
       case StockImportMode.add:
         finalStock = row.currentStock + row.quantity;
         break;
       case StockImportMode.subtract:
         finalStock = row.currentStock - row.quantity;
         break;
       case StockImportMode.verify:
         finalStock = row.currentStock;
         break;
     }

     if (finalStock < 0) {
        row.status = StockPdfRowStatus.negativeStock;
        row.selected = false;
     } else if (row.status == StockPdfRowStatus.ok || row.status == StockPdfRowStatus.inactiveProduct) {
        row.status = StockPdfRowStatus.ok; // Reset if it was negative before
     }

     row.finalStock = finalStock;
     return row;
  }

  void toggleRowSelection(int index) {
    final rows = List<StockPdfRow>.from(state.rows);
    rows[index].selected = !rows[index].selected;
    state = state.copyWith(rows: rows);
  }

  void updateRowColor(int index, String newColorName) {
    final rows = List<StockPdfRow>.from(state.rows);
    final row = rows[index].copyWith(colorName: newColorName, status: StockPdfRowStatus.ok);
    rows[index] = row;
    state = state.copyWith(rows: rows);
    _resolveRows(); // Re-resolve with new color
  }

  Future<void> applyImport() async {
    if (state.mode == StockImportMode.verify) return;
    
    state = state.copyWith(isProcessing: true);
    
    try {
      final validRows = state.rows.where((r) => r.selected && r.status == StockPdfRowStatus.ok && r.resolvedProductId != null).toList();
      
      // Group by productId
      final Map<String, List<StockPdfRow>> updatesByProduct = {};
      for (var r in validRows) {
        updatesByProduct.putIfAbsent(r.resolvedProductId!, () => []).add(r);
      }
      
      final productsNotifier = _ref.read(productsViewModelProvider.notifier);
      final tenantId = _ref.read(tenantViewModelProvider).valueOrNull?.tenant?.id ?? 'default';

      int successCount = 0;

      for (var entry in updatesByProduct.entries) {
        final productId = entry.key;
        final rowsToApply = entry.value;
        
        final productsState = _ref.read(productsViewModelProvider).valueOrNull;
        final product = productsState?.allProducts.firstWhere((p) => p.id == productId);
        if (product == null) continue;
        
        List<ProductVariant> newVariants = List.from(product.variants);
        
        for (var row in rowsToApply) {
           final vIndex = newVariants.indexWhere((v) => v.sku == row.resolvedVariantSku);
           if (vIndex >= 0) {
              newVariants[vIndex] = ProductVariant(
                sku: newVariants[vIndex].sku,
                stock: row.finalStock,
                attributes: newVariants[vIndex].attributes,
              );
              successCount++;
           } else {
              // Create variant if it didn't exist but product exists
              final newSku = '${product.ref}.${row.colorCode}.${row.size}';
              newVariants.add(ProductVariant(
                sku: newSku,
                stock: row.finalStock,
                attributes: {'color': row.colorName, 'size': row.size},
              ));
              successCount++;
           }
        }
        
        // Recalculate isOutOfStock
        bool isOutOfStock = newVariants.every((v) => v.stock <= 0);
        
        final updatedProduct = product.copyWith(
          variants: newVariants,
          isOutOfStock: isOutOfStock,
          updatedAt: DateTime.now(),
        );
        
        // Update product in backend/Hive via ProductsViewModel
        await productsNotifier.updateProduct(updatedProduct);
      }

      // Save History
      final history = StockImportHistory(
        id: const Uuid().v4(),
        fileName: state.fileName ?? 'unknown.pdf',
        createdAt: DateTime.now(),
        createdBy: 'currentUser', // In real app, get from AuthViewModel
        tenantId: tenantId,
        storeId: state.targetStoreId,
        detectedCompanyCode: state.metadata?.companyCode,
        detectedStoreName: state.metadata?.companyName,
        stockDate: state.metadata?.stockDate,
        generatedAt: state.metadata?.generationDate,
        mode: state.mode,
        totalPdfQuantity: state.metadata?.totalQuantity ?? 0,
        totalParsedRows: state.rows.length,
        successCount: successCount,
        warningCount: 0,
        errorCount: state.rows.where((r) => r.status != StockPdfRowStatus.ok).length,
        ignoredCount: state.rows.where((r) => !r.selected).length,
        status: 'completed',
        sourceSystem: 'pdf_import',
      );

      // Save history to Firestore
      try {
        await FirebaseFirestore.instance
            .collection('tenants')
            .doc(tenantId)
            .collection('imports')
            .doc(history.id)
            .set(history.toMap());
      } catch (e) {
        // Ignorar falha de log se estiver offline
      }

      state = state.copyWith(isProcessing: false, isApplied: true);
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: 'Erro ao aplicar: $e');
    }
  }
}

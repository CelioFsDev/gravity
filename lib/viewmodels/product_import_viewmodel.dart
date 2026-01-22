import 'dart:io';

import 'package:gravity/data/repositories/products_repository.dart';
import 'package:gravity/models/product.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

part 'product_import_viewmodel.g.dart';

// State for Import Flow
class ProductImportState {
  final int currentStep;
  final List<List<dynamic>>? csvData; // Raw parsed CSV
  final List<Product> parsedProducts; // Products converted from CSV
  final List<String> matchedImages; // List of image paths found
  final int imagesMatchedCount;
  final int imagesTotalCount; // Total expected based on CSV SKU count or file upload count
  final bool isLoading;
  final String? errorMessage;
  final bool isDone;

  ProductImportState({
    this.currentStep = 0,
    this.csvData,
    this.parsedProducts = const [],
    this.matchedImages = const [],
    this.imagesMatchedCount = 0,
    this.imagesTotalCount = 0,
    this.isLoading = false,
    this.errorMessage,
    this.isDone = false,
  });

  ProductImportState copyWith({
    int? currentStep,
    List<List<dynamic>>? csvData,
    List<Product>? parsedProducts,
    List<String>? matchedImages,
    int? imagesMatchedCount,
    int? imagesTotalCount,
    bool? isLoading,
    String? errorMessage,
    bool? isDone,
  }) {
    return ProductImportState(
      currentStep: currentStep ?? this.currentStep,
      csvData: csvData ?? this.csvData,
      parsedProducts: parsedProducts ?? this.parsedProducts,
      matchedImages: matchedImages ?? this.matchedImages,
      imagesMatchedCount: imagesMatchedCount ?? this.imagesMatchedCount,
      imagesTotalCount: imagesTotalCount ?? this.imagesTotalCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isDone: isDone ?? this.isDone,
    );
  }
}

@riverpod
class ProductImportViewModel extends _$ProductImportViewModel {
  @override
  ProductImportState build() {
    return ProductImportState();
  }

  void nextStep() {
    state = state.copyWith(currentStep: state.currentStep + 1);
  }

  void prevStep() {
    state = state.copyWith(currentStep: state.currentStep - 1);
  }

  // Step 1: Download Template (No state change really, UI handles)
  // Step 2: Upload CSV
  Future<void> pickAndParseCsv() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        // Read file
        final file = File(result.files.single.path!);
        final input = await file.readAsString();
        final fields = const CsvToListConverter().convert(input);
        
        // Basic validation: Expect Header
        if (fields.isEmpty) throw Exception("Arquivo vazio");
        
        // Parse Products
        // Assuming Header: Name, REF, SKU, Category, Retail, Wholesale, MinQty, Sizes, Colors, Status
        final products = <Product>[];
        // Skip header
        for (var i = 1; i < fields.length; i++) {
            final row = fields[i];
            if (row.length < 3) continue; // Skip bad row
            
            // Map row to Product
            // This assumes a strict structure. In real world, we'd map columns.
            products.add(_mapRowToProduct(row));
        }

        state = state.copyWith(
          csvData: fields,
          parsedProducts: products,
          isLoading: false,
        );
        // Auto advance?
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Erro ao ler CSV: $e");
    }
  }

  // Step 3: Upload Images
  Future<void> pickAndMatchImages() async {
     state = state.copyWith(isLoading: true, errorMessage: null);
     try {
       FilePickerResult? result = await FilePicker.platform.pickFiles(
         allowMultiple: true,
         type: FileType.image,
       );

       if (result != null) {
         Map<String, List<String>> productImages = {};
         int matched = 0;
         
         // Logic: Filename "SKU.jpg" or "SKU_1.jpg"
         for (var file in result.files) {
            if (file.path == null) continue;
            
            final filename = p.basenameWithoutExtension(file.path!); // e.g. "SKU123_1"
            
            // Look for matching SKU in parsedProducts
            for (var product in state.parsedProducts) {
               // Checking if filename starts with SKU
               // e.g. SKU="ABC", filename="ABC.jpg" or "ABC_1.jpg"
               if (filename == product.sku || filename.startsWith('${product.sku}_')) {
                  if (!productImages.containsKey(product.id)) {
                    productImages[product.id] = [];
                  }
                  productImages[product.id]!.add(file.path!);
                  matched++;
                  break; // Found owner
               }
            }
         }
         
         // Update products with matched images
         final updatedProducts = state.parsedProducts.map((p) {
             if (productImages.containsKey(p.id)) {
               return p.copyWith(images: productImages[p.id]!);
             }
             return p;
         }).toList();

         state = state.copyWith(
           parsedProducts: updatedProducts,
           imagesMatchedCount: matched,
           imagesTotalCount: result.files.length, 
           isLoading: false,
         );
       } else {
         state = state.copyWith(isLoading: false);
       }
     } catch (e) {
       state = state.copyWith(isLoading: false, errorMessage: "Erro ao processar imagens: $e");
     }
  }

  // Finalize
  Future<void> finalizeImport() async {
    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(productsRepositoryProvider);
      
      // Save all products
      for (var p in state.parsedProducts) {
        await repository.addProduct(p);
      }
      
      state = state.copyWith(isLoading: false, isDone: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Erro ao salvar: $e");
    }
  }

  Product _mapRowToProduct(List<dynamic> row) {
    // Schema: Name(0), REF(1), SKU(2), CategoryID(3), Retail(4), Wholesale(5), MinQty(6), Sizes(7), Colors(8), Active(9)
    // CSV numbers usually integers or doubles.
    return Product(
      id: const Uuid().v4(),
      name: row[0].toString(),
      reference: row[1].toString(),
      sku: row[2].toString(),
      categoryId: row[3].toString(), // Assuming ID. In advanced version, map Name -> ID.
      retailPrice: double.tryParse(row[4].toString()) ?? 0.0,
      wholesalePrice: double.tryParse(row[5].toString()) ?? 0.0,
      minWholesaleQty: int.tryParse(row[6].toString()) ?? 1,
      sizes: row[7].toString().split(',').map((e) => e.trim()).toList(),
      colors: row[8].toString().split(',').map((e) => e.trim()).toList(),
      images: [],
      mainImageIndex: 0,
      isActive: row[9].toString().toLowerCase() == 'true' || row[9] == 1,
      isOutOfStock: false,
      isOnSale: false,
      createdAt: DateTime.now(),
    );
  }
}

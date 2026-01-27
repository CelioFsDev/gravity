import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gravity/data/repositories/products_repository.dart';
import 'package:gravity/models/product.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: kIsWeb,
      );

      if (result != null) {
        // Read file
        final input = await _readCsvContent(result.files.single);
        final fields = const CsvToListConverter().convert(input);
        
        // Basic validation: Expect Header
        if (fields.isEmpty) throw Exception("Arquivo vazio");
        
        // Parse Products
        final products = <Product>[];
        // Skip header
        for (var i = 1; i < fields.length; i++) {
            final row = fields[i];
            if (row.length < 3) continue; // Skip bad row
            
            products.add(_mapRowToProduct(row));
        }

        state = state.copyWith(
          csvData: fields,
          parsedProducts: products,
          isLoading: false,
        );
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
       FilePickerResult? result = await FilePicker.pickFiles(
         allowMultiple: true,
         type: FileType.custom,
         allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
         withData: kIsWeb,
       );

       if (result != null) {
         Map<String, List<String>> productImages = {};
         int matched = 0;
         
         for (var file in result.files) {
            if (!kIsWeb && file.path == null) continue;

            for (var product in state.parsedProducts) {
                  final copiedPath = await _resolveImageForPlatform(file);
                  if (copiedPath != null) {
                    productImages.putIfAbsent(product.id, () => []).add(copiedPath);
                    matched++;
                  }
                  break; // Found owner
            }
         }
         
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
      
      for (var p in state.parsedProducts) {
        await repository.addProduct(p);
      }
      
      state = state.copyWith(isLoading: false, isDone: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Erro ao salvar: $e");
    }
  }

  double _parsePrice(String text) {
    if (text.isEmpty) return 0.0;
    String cleaned = text.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.split('.').length > 2) {
      final parts = cleaned.split('.');
      final decimal = parts.removeLast();
      cleaned = '${parts.join('')}.$decimal';
    }
    return double.tryParse(cleaned) ?? 0.0;
  }

  Product _mapRowToProduct(List<dynamic> row) {
    return Product(
      id: const Uuid().v4(),
      name: row[0].toString(),
      reference: row[1].toString(),
      sku: row[2].toString(),
      categoryId: row[3].toString(), 
      retailPrice: _parsePrice(row[4].toString()),
      wholesalePrice: _parsePrice(row[5].toString()),
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

  Future<String> _readCsvContent(PlatformFile file) async {
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Arquivo CSV sem bytes (web)');
      }
      return utf8.decode(bytes);
    }

    if (file.path != null) {
      final ioFile = File(file.path!);
      return ioFile.readAsString();
    }

    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('Arquivo CSV sem path/bytes');
    }
    return utf8.decode(bytes);
  }

  String _inferMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String?> _resolveImageForPlatform(PlatformFile file) async {
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) return null;
      final mime = _inferMimeType(file.name);
      return 'data:$mime;base64,${base64Encode(bytes)}';
    }

    if (file.path == null) return null;
    return _copyImageToPersistentStorage(file.path!);
  }

  Future<String?> _copyImageToPersistentStorage(String sourcePath) async {
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(baseDir.path, 'product_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final fileName = '${const Uuid().v4()}${p.extension(sourcePath)}';
      final targetPath = p.join(imagesDir.path, fileName);
      final File targetFile = File(targetPath);
      
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        final bytes = await sourceFile.readAsBytes();
        await targetFile.writeAsBytes(bytes);
        return targetPath;
      }
      return null;
    } on MissingPluginException {
      if (kDebugMode) print('MissingPluginException: path_provider not implemented on this platform or stale build.');
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to copy import image: $e');
      }
      return null;
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/core/services/export_import_service.dart';
import 'package:catalogo_ja/core/services/whatsapp_share_service.dart';
import 'package:catalogo_ja/data/repositories/categories_repository.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/core/utils/user_friendly_error.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProductTransferService {
  static const String _csvFileName = 'products.csv';
  static const String _imagesDirName = 'images';

  static Future<void> shareProductsPackage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final productsRepo = ref.read(productsRepositoryProvider);
      final categoriesRepo = ref.read(categoriesRepositoryProvider);
      final products = await productsRepo.getProducts();
      if (products.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum produto para exportar.')),
          );
        }
        return;
      }

      final categories = await categoriesRepo.getCategories();
      final bytes = await _runWithLoadingDialog(
        context,
        () => _buildZipBytes(products, categories),
      );
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'CatalogoJa_produtos_$timestamp.zip';
      await WhatsAppShareService.shareFile(
        bytes: bytes,
        fileName: fileName,
        text: 'Exporta\u00e7\u00e3o de produtos',
        mimeType: 'application/zip',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(UserFriendlyError.message(e))));
      }
    }
  }

  static Future<void> shareCatalogoJaBackup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final service = ref.read(exportImportServiceProvider);
      final bytes = await _runWithLoadingDialog(
        context,
        () => service.exportToJsonBytes(),
      );

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'CatalogoJa_backup_$timestamp.json';

      await WhatsAppShareService.shareFile(
        bytes: bytes,
        fileName: fileName,
        text: 'Backup CatalogoJa',
        mimeType: 'application/json',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(UserFriendlyError.message(e))));
      }
    }
  }

  static Future<void> saveTemplateCsv(BuildContext context) async {
    if (kIsWeb) return;
    try {
      final csv = const CsvEncoder().convert([_csvHeader]);
      final dir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final filePath = p.join(dir.path, 'template_produtos.csv');
      await File(filePath).writeAsString(csv);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Template salvo em $filePath')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(UserFriendlyError.message(e))));
      }
    }
  }

  static Future<Uint8List> _buildZipBytes(
    List<Product> products,
    List<Category> categories,
  ) async {
    final categoryById = {for (final c in categories) c.id: c.name};
    final categoryTypeById = {for (final c in categories) c.id: c.type};
    final rows = <List<dynamic>>[];
    rows.add(_csvHeader);

    final archive = Archive();
    final imageNamesBySku = <String, List<String>>{};

    final appDocDir = kIsWeb ? null : await getApplicationDocumentsDirectory();

    for (final product in products) {
      final imageNames = <String>[];
      for (var i = 0; i < product.images.length; i++) {
        final path = product.images[i].uri;
        Uint8List? bytes;

        if (path.startsWith('data:')) {
          try {
            final commaIndex = path.indexOf(',');
            if (commaIndex != -1) {
              bytes = base64Decode(path.substring(commaIndex + 1));
            }
          } catch (_) {}
        } else if (!kIsWeb) {
          try {
            var file = File(path);
            if (file.existsSync()) {
              bytes = await file.readAsBytes();
            } else if (appDocDir != null) {
              file = File(p.join(appDocDir.path, p.basename(path)));
              if (file.existsSync()) {
                bytes = await file.readAsBytes();
              } else {
                file = File(
                  p.join(appDocDir.path, 'product_images', p.basename(path)),
                );
                if (file.existsSync()) {
                  bytes = await file.readAsBytes();
                }
              }
            }
          } catch (_) {}
        }

        if (bytes == null) continue;

        final ext = p.extension(path).isEmpty
            ? '.jpg'
            : p.extension(path).toLowerCase();
        final skuSafe = _sanitizeSku(product.sku);
        final fileName = '${skuSafe.isNotEmpty ? skuSafe : product.id}_$i$ext';
        final entryName = '$_imagesDirName/$fileName';

        archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
        imageNames.add(fileName);
      }
      imageNamesBySku[product.sku] = imageNames;

      final sizes = product.sizes.join('|');
      final colors = product.colors.join('|');
      final images = imageNames.join('|');
      final productTypeId = product.categoryIds.firstWhere(
        (id) => categoryTypeById[id] == CategoryType.productType,
        orElse: () => '',
      );
      rows.add([
        product.sku,
        product.name,
        product.reference,
        categoryById[productTypeId] ?? '',
        product.priceVarejo,
        product.priceAtacado,
        product.minWholesaleQty,
        sizes,
        colors,
        product.isActive,
        product.isOutOfStock,
        product.isOnSale,
        product.saleDiscountPercent,
        product.mainImageIndex,
        product.createdAt.toIso8601String(),
        images,
      ]);
    }

    final csv = const CsvEncoder().convert(rows);
    final csvBytes = utf8.encode(csv);
    archive.addFile(ArchiveFile(_csvFileName, csvBytes.length, csvBytes));

    final zipBits = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipBits);
  }

  static String _sanitizeSku(String sku) {
    return sku.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  }

  static Future<T> _runWithLoadingDialog<T>(
    BuildContext context,
    Future<T> Function() action,
  ) async {
    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Preparando arquivo...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Aguarde enquanto o aplicativo organiza os dados.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      return await action();
    } finally {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }
    }
  }

  static const List<String> _csvHeader = [
    'SKU',
    'Name',
    'REF',
    'Category',
    'RetailPrice',
    'WholesalePrice',
    'MinQty',
    'Sizes',
    'Colors',
    'IsActive',
    'IsOutOfStock',
    'IsOnSale',
    'SaleDiscountPercent',
    'MainImageIndex',
    'CreatedAt',
    'ImageFiles',
  ];
}

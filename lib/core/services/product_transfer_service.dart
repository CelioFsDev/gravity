import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/core/services/whatsapp_share_service.dart';
import 'package:gravity/data/repositories/categories_repository.dart';
import 'package:gravity/data/repositories/products_repository.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/product.dart';
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
      final fileName = 'gravity_produtos_$timestamp.zip';
      await WhatsAppShareService.shareFile(
        bytes: bytes,
        fileName: fileName,
        text: 'Exportação de produtos',
        mimeType: 'application/zip',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
      }
    }
  }

  static Future<void> saveTemplateCsv(BuildContext context) async {
    try {
      final csv = const ListToCsvConverter().convert([
        _csvHeader,
      ]);
      final dir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final filePath = p.join(dir.path, 'template_produtos.csv');
      await File(filePath).writeAsString(csv);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template salvo em $filePath')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar template: $e')));
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

    for (final product in products) {
      final imageNames = <String>[];
      for (var i = 0; i < product.images.length; i++) {
        final path = product.images[i];
        final file = File(path);
        if (!await file.exists()) continue;
        final ext = p.extension(path).toLowerCase();
        final skuSafe = _sanitizeSku(product.sku);
        final fileName = '${skuSafe.isNotEmpty ? skuSafe : product.id}_$i$ext';
        final entryName = '$_imagesDirName/$fileName';
        final bytes = await file.readAsBytes();
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

    final csv = const ListToCsvConverter().convert(rows);
    final csvBytes = utf8.encode(csv);
    archive.addFile(ArchiveFile(_csvFileName, csvBytes.length, csvBytes));

    final zipBytes = ZipEncoder().encode(archive) ?? <int>[];
    return Uint8List.fromList(zipBytes);
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
        return const Center(child: CircularProgressIndicator());
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

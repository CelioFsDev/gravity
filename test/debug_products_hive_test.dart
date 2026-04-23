import 'dart:io';

import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:catalogo_ja/models/product_variant.dart';
import 'package:catalogo_ja/models/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('debug local products hive image paths', () async {
    const basePath =
        r'C:\Users\celio\AppData\Roaming\com.example\catalogo_ja\catalogo_ja\db_v2';

    Hive.init(basePath);

    Hive
      ..registerAdapter(SyncStatusAdapter())
      ..registerAdapter(CategoryTypeAdapter())
      ..registerAdapter(CollectionCoverModeAdapter())
      ..registerAdapter(CollectionCoverAdapter())
      ..registerAdapter(CategoryAdapter())
      ..registerAdapter(ProductVariantAdapter())
      ..registerAdapter(ProductPhotoAdapter())
      ..registerAdapter(ProductImageSourceAdapter())
      ..registerAdapter(ProductImageAdapter())
      ..registerAdapter(AppSettingsAdapter())
      ..registerAdapter(ProductAdapter())
      ..registerAdapter(CatalogBannerAdapter())
      ..registerAdapter(CatalogModeAdapter())
      ..registerAdapter(CatalogAdapter())
      ..registerAdapter(SyncQueueItemAdapter());

    final box = await Hive.openBox<Product>('products');
    final products = box.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // ignore: avoid_print
    print('products_count=${products.length}');
    for (final product in products.take(10)) {
      final mainImage = product.mainImage;
      // ignore: avoid_print
      print('---');
      // ignore: avoid_print
      print('id=${product.id}');
      // ignore: avoid_print
      print('name=${product.name}');
      // ignore: avoid_print
      print('tenantId=${product.tenantId}');
      // ignore: avoid_print
      print('updatedAt=${product.updatedAt.toIso8601String()}');
      // ignore: avoid_print
      print('images_count=${product.images.length}');
      // ignore: avoid_print
      print('photos_count=${product.photos.length}');
      // ignore: avoid_print
      print('mainImage_uri=${mainImage?.uri}');
      // ignore: avoid_print
      print('mainImage_source=${mainImage?.sourceType.name}');
      if (mainImage != null && mainImage.uri.isNotEmpty) {
        // ignore: avoid_print
        print('mainImage_exists=${await _pathExists(mainImage.uri)}');
      }
      for (final image in product.images.take(4)) {
        // ignore: avoid_print
        print(
          'image uri=${image.uri} source=${image.sourceType.name} label=${image.label} exists=${await _pathExists(image.uri)}',
        );
      }
      for (final photo in product.photos.take(4)) {
        // ignore: avoid_print
        print(
          'photo path=${photo.path} type=${photo.photoType} primary=${photo.isPrimary} exists=${await _pathExists(photo.path)}',
        );
      }
    }

    await box.close();
  });
}

Future<bool> _pathExists(String path) async {
  if (path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('data:') ||
      path.startsWith('blob:')) {
    return true;
  }
  return File(path).exists();
}

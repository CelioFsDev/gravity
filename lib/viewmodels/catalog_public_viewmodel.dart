import 'package:catalogo_ja/data/repositories/public_catalog_repository.dart';
import 'package:catalogo_ja/core/error/app_failure.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog_public_viewmodel.g.dart';

// Type alias backwards compatibility
typedef PublicCatalogData = PublicCatalogDataResponse;

@riverpod
Future<PublicCatalogData?> catalogPublic(
  CatalogPublicRef ref,
  String shareCode,
) async {
  try {
    final repo = ref.watch(publicCatalogRepositoryProvider);
    final data = await repo.getPublicCatalogData(shareCode.trim().toLowerCase());
    return data;
  } catch (e, s) {
    debugPrint('❌ Error loading public catalog ($shareCode): $e');
    debugPrint(s.toString());
    throw e.toAppFailure(action: 'fetch', entity: 'PublicCatalog');
  }
}

import 'package:catalogo_ja/data/repositories/public_catalog_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog_public_viewmodel.g.dart';

// Type alias backwards compatibility
typedef PublicCatalogData = PublicCatalogDataResponse;

@riverpod
Stream<PublicCatalogData?> catalogPublic(
  CatalogPublicRef ref,
  String shareCode,
) async* {
  final repo = ref.watch(publicCatalogRepositoryProvider);
  final normalizedShareCode = shareCode.trim().toLowerCase();
  debugPrint('catalogPublicProvider load: shareCode="$normalizedShareCode"');
  try {
    yield* repo.getPublicCatalogStream(normalizedShareCode);
  } catch (e, s) {
    debugPrint('catalogPublicProvider error for $normalizedShareCode: $e');
    debugPrint(e.toString());
    debugPrint(s.toString());
    rethrow;
  }
}

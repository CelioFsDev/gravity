import 'dart:async';
import 'package:catalogo_ja/core/services/public_catalog_snapshot_service.dart';
import 'package:catalogo_ja/data/repositories/firestore_catalogs_repository.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/sync_status.dart';
import 'package:catalogo_ja/viewmodels/catalog_public_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/core/utils/string_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'catalog_editor_viewmodel.g.dart';

class CatalogEditorState {
  final Catalog catalog;
  final bool isSaving;
  final String? slugError;

  CatalogEditorState({
    required this.catalog,
    this.isSaving = false,
    this.slugError,
  });

  CatalogEditorState copyWith({
    Catalog? catalog,
    bool? isSaving,
    String? slugError,
    bool clearSlugError = false,
  }) {
    return CatalogEditorState(
      catalog: catalog ?? this.catalog,
      isSaving: isSaving ?? this.isSaving,
      slugError: clearSlugError ? null : (slugError ?? this.slugError),
    );
  }
}

@riverpod
class CatalogEditorViewModel extends _$CatalogEditorViewModel {
  @override
  CatalogEditorState build(String? catalogId) {
    if (catalogId != null) {
      // Synchronous read if possible or fetch in build
      // To keep it simple, we'll try to find it in the already loaded list
      // Or just read from box. Since Hive is sync, we can use Hive.box.get.
      final catalogs = ref.watch(catalogsViewModelProvider).value ?? [];
      final existing = catalogs.firstWhere(
        (c) => c.id == catalogId,
        orElse: () => _emptyCatalog(),
      );
      return CatalogEditorState(catalog: existing);
    }
    return CatalogEditorState(catalog: _emptyCatalog());
  }

  Catalog _emptyCatalog() {
    return Catalog(
      id: const Uuid().v4(),
      name: '',
      slug: '',
      active: true,
      productIds: [],
      requireCustomerData: false,
      photoLayout: 'grid',
      announcementEnabled: false,
      banners: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mode: CatalogMode.varejo,
      isPublic: false,
      shareCode: '',
      ownerUid: '',
      includeCover: true,
    );
  }

  void updateName(String name) {
    state = state.copyWith(catalog: state.catalog.copyWith(name: name));
  }

  void updateSlug(String slug) {
    final normalized = slug
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-]'), '-')
        .replaceAll(RegExp(r'-+'), '-');

    state = state.copyWith(
      catalog: state.catalog.copyWith(slug: normalized),
      clearSlugError: true,
    );
  }

  void toggleActive(bool val) {
    state = state.copyWith(catalog: state.catalog.copyWith(active: val));
  }

  void toggleProduct(String productId) {
    final currentIds = List<String>.from(state.catalog.productIds);
    if (currentIds.contains(productId)) {
      currentIds.remove(productId);
    } else {
      currentIds.add(productId);
    }
    state = state.copyWith(
      catalog: state.catalog.copyWith(productIds: currentIds),
    );
  }

  void selectProducts(Iterable<String> productIds) {
    final merged = {...state.catalog.productIds, ...productIds}.toList();
    state = state.copyWith(
      catalog: state.catalog.copyWith(productIds: merged),
    );
  }

  void deselectProducts(Iterable<String> productIds) {
    final toRemove = productIds.toSet();
    final updated = state.catalog.productIds
        .where((id) => !toRemove.contains(id))
        .toList();
    state = state.copyWith(
      catalog: state.catalog.copyWith(productIds: updated),
    );
  }

  void setRequireCustomerData(bool val) {
    state = state.copyWith(
      catalog: state.catalog.copyWith(requireCustomerData: val),
    );
  }

  void setPhotoLayout(String val) {
    state = state.copyWith(catalog: state.catalog.copyWith(photoLayout: val));
  }

  void setAnnouncementEnabled(bool val) {
    state = state.copyWith(
      catalog: state.catalog.copyWith(announcementEnabled: val),
    );
  }

  void setAnnouncementText(String val) {
    state = state.copyWith(
      catalog: state.catalog.copyWith(announcementText: val),
    );
  }

  void setMode(CatalogMode mode) {
    state = state.copyWith(catalog: state.catalog.copyWith(mode: mode));
  }

  void setIsPublic(bool value) {
    var catalog = state.catalog;
    if (value && catalog.shareCode.trim().isEmpty) {
      catalog = catalog.copyWith(shareCode: _generateShareCode());
    } else if (catalog.shareCode.trim().isNotEmpty) {
      catalog = catalog.copyWith(shareCode: catalog.shareCode.trim().toLowerCase());
    }
    state = state.copyWith(catalog: catalog.copyWith(isPublic: value));
  }

  void setIncludeCover(bool value) {
    state = state.copyWith(
      catalog: state.catalog.copyWith(includeCover: value),
    );
  }

  void setCoverType(String? value) {
    state = state.copyWith(catalog: state.catalog.copyWith(coverType: value));
  }

  void regenerateShareCode() {
    state = state.copyWith(
      catalog: state.catalog.copyWith(shareCode: _generateShareCode()),
    );
  }

  Future<bool> save() async {
    try {
      state = state.copyWith(isSaving: true, clearSlugError: true);

      if (state.catalog.name.isEmpty) {
        state = state.copyWith(isSaving: false);
        return false;
      }

      if (state.catalog.slug.isEmpty || state.catalog.slug.length < 3) {
        state = state.copyWith(isSaving: false, slugError: 'Slug muito curto');
        return false;
      }

      final repository = ref.read(syncCatalogsRepositoryProvider);
      final isTaken = await repository.isSlugTaken(
        state.catalog.slug,
        excludeId: state.catalog.id,
      );

      if (isTaken) {
        state = state.copyWith(
          isSaving: false,
          slugError: 'Esta URL já está em uso.',
        );
        return false;
      }

      var toSave = state.catalog;
      final normalizedShareCode = toSave.shareCode.trim().isEmpty
          ? _generateShareCode()
          : toSave.shareCode.trim().toLowerCase();
      toSave = toSave.copyWith(
        shareCode: normalizedShareCode,
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pendingUpdate,
      );

      await repository.addCatalog(toSave);

      if (toSave.isPublic) {
        try {
          await ref.read(publicCatalogSnapshotServiceProvider).publish(toSave);
        } catch (e) {
          // O link publico ainda funciona via fallback do Firestore.
          // A publicacao do snapshot nao deve impedir salvar/compartilhar.
          // ignore: avoid_print
          print('Erro ao publicar snapshot do catalogo: $e');
        }
      }

      ref.invalidate(catalogsViewModelProvider);
      if (toSave.shareCode.isNotEmpty) {
        ref.invalidate(catalogPublicProvider(toSave.shareCode));
      }

      state = state.copyWith(catalog: toSave, isSaving: false);
      return true;
    } catch (e, s) {
      // ignore: avoid_print
      print('Error saving catalog: $e\n$s');
      state = state.copyWith(isSaving: false, slugError: 'Erro ao salvar: $e');
      return false;
    }
  }

  String _generateShareCode() => StringUtils.generateBase62(10).toLowerCase();
}

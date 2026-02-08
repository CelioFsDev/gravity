import 'package:gravity/core/auth/auth_controller.dart';
import 'package:gravity/core/auth/auth_guards.dart';
import 'package:gravity/data/repositories/catalogs_repository.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/viewmodels/catalog_public_viewmodel.dart';
import 'package:gravity/viewmodels/catalogs_viewmodel.dart';
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
    if (value && catalog.shareCode.isEmpty) {
      catalog = catalog.copyWith(shareCode: _generateShareCode());
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

      final repository = ref.read(catalogsRepositoryProvider);
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

      final user = ref.read(currentUserProvider);
      var toSave = state.catalog;
      if (!isLoggedIn(user)) {
        state = state.copyWith(
          isSaving: false,
          slugError: 'Usuário não autenticado.',
        );
        return false;
      }
      if (user != null &&
          toSave.ownerUid.isNotEmpty &&
          toSave.ownerUid != user.uid) {
        state = state.copyWith(
          isSaving: false,
          slugError: 'Sem permissão para editar este catálogo.',
        );
        return false;
      }
      if (toSave.shareCode.isEmpty) {
        toSave = toSave.copyWith(shareCode: _generateShareCode());
      }
      toSave = toSave.copyWith(
        updatedAt: DateTime.now(),
        ownerUid: toSave.ownerUid.isEmpty && user != null
            ? user.uid
            : toSave.ownerUid,
      );

      await repository.addCatalog(toSave);

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

  String _generateShareCode() =>
      const Uuid().v4().split('-').first.toLowerCase();
}


import 'package:gravity/data/repositories/catalogs_repository.dart';
import 'package:gravity/models/catalog.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'catalog_editor_viewmodel.g.dart';

// State to hold form data
class CatalogEditorState {
  final Catalog catalog;
  final bool isSaving;
  final String? slugError;

  CatalogEditorState({required this.catalog, this.isSaving = false, this.slugError});

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
  CatalogEditorState build(Catalog? initialCatalog) {
    if (initialCatalog != null) {
      return CatalogEditorState(catalog: initialCatalog);
    }
    // Draft
    return CatalogEditorState(
      catalog: Catalog(
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
      ),
    );
  }
  
  void updateName(String name) {
    state = state.copyWith(catalog: state.catalog.copyWith(name: name));
  }

  void updateSlug(String slug) {
    // Normalization
    final normalized = slug.trim().toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-]'), '-')
        .replaceAll(RegExp(r'-+'), '-'); // remove double dash
        
    state = state.copyWith(catalog: state.catalog.copyWith(slug: normalized), clearSlugError: true);
  }
  
  void toggleActive(bool val) {
    state = state.copyWith(catalog: state.catalog.copyWith(active: val));
  }
  
  // Products
  void toggleProduct(String productId) {
    final currentIds = List<String>.from(state.catalog.productIds);
    if (currentIds.contains(productId)) {
      currentIds.remove(productId);
    } else {
      currentIds.add(productId);
    }
    state = state.copyWith(catalog: state.catalog.copyWith(productIds: currentIds));
  }
  
  // Personalize
  void setRequireCustomerData(bool val) {
    state = state.copyWith(catalog: state.catalog.copyWith(requireCustomerData: val));
  }
  
  void setPhotoLayout(String val) {
    state = state.copyWith(catalog: state.catalog.copyWith(photoLayout: val));
  }
  
  void setAnnouncementEnabled(bool val) {
    state = state.copyWith(catalog: state.catalog.copyWith(announcementEnabled: val));
  }

  void setAnnouncementText(String val) {
     state = state.copyWith(catalog: state.catalog.copyWith(announcementText: val));
  }

  // Banners
  void addBanner(String imagePath, {String? title}) {
     final banner = CatalogBanner(id: const Uuid().v4(), imagePath: imagePath, title: title);
     state = state.copyWith(catalog: state.catalog.copyWith(banners: [...state.catalog.banners, banner]));
  }
  
  void removeBanner(String id) {
     final banners = state.catalog.banners.where((b) => b.id != id).toList();
     state = state.copyWith(catalog: state.catalog.copyWith(banners: banners));
  }
  
  void reorderBanners(int oldIndex, int newIndex) {
     if (oldIndex < newIndex) newIndex -= 1;
     final banners = List<CatalogBanner>.from(state.catalog.banners);
     final item = banners.removeAt(oldIndex);
     banners.insert(newIndex, item);
     state = state.copyWith(catalog: state.catalog.copyWith(banners: banners));
  }

  Future<bool> save() async {
     state = state.copyWith(isSaving: true, clearSlugError: true);
     
     // Validate
     if (state.catalog.name.isEmpty) {
        // UI validation usually handles this but good to have safety
        state = state.copyWith(isSaving: false);
        return false;
     }

     if (state.catalog.slug.isEmpty || state.catalog.slug.length < 3) {
       state = state.copyWith(isSaving: false, slugError: 'Slug muito curto');
       return false;
     }
     
     final repository = ref.read(catalogsRepositoryProvider);
     final isTaken = await repository.isSlugTaken(state.catalog.slug, excludeId: state.catalog.id);
     
     if (isTaken) {
       state = state.copyWith(isSaving: false, slugError: 'Esta URL já está em uso.');
       return false;
     }

     // Save
     if (state.catalog.createdAt.isAfter(DateTime.now())) { // Logic check: is it update? 
        // Actually we check if we passed initialCatalog but here we just check if it exists in DB logic or just use update
     }
     
     // We can just use add/update based on if ID exists (it always has ID)
     // But repository logic is same (put)
     await repository.addCatalog(state.catalog.copyWith(updatedAt: DateTime.now()));
     
     state = state.copyWith(isSaving: false);
     return true;
  }
}

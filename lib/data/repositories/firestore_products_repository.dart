import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:catalogo_ja/data/repositories/contracts/products_repository_contract.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/core/services/saas_photo_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';

class FirestoreProductsRepository implements ProductsRepositoryContract {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HiveProductsRepository _localRepo;
  final SaaSPhotoStorageService _storageService;
  final String _tenantId;

  FirestoreProductsRepository(
    this._localRepo,
    this._storageService,
    this._tenantId,
  );

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('products');

  @override
  Future<List<Product>> getProducts() async {
    final snapshot = await _collection
        .where('tenantId', isEqualTo: _tenantId)
        .get();
    return snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList();
  }

  @override
  Future<void> addProduct(Product product) async {
    // 1. Prepara a lista de imagens para upload (une o novo com o legado se necessário)
    var imagesToSync = List<ProductImage>.from(product.images);
    
    // Se a lista moderna estiver vazia, tenta converter do legado 'photos'
    if (imagesToSync.isEmpty && product.photos.isNotEmpty) {
      imagesToSync = product.photos.map((p) => p.toProductImage()).toList();
    }

    // Sincroniza fotos locais com a nuvem uma por uma
    final List<ProductImage> updatedImages = [];
    for (var image in imagesToSync) {
      final isLocal = !image.uri.startsWith('http') && !image.uri.startsWith('gs://');
      
      if (isLocal || image.sourceType == ProductImageSource.localPath) {
        try {
          print('🚀 Iniciando upload da imagem: ${image.uri}');
          final cloudUrl = await _storageService.uploadProductImage(
            localPath: image.uri,
            productId: product.id,
            tenantId: _tenantId,
          ).timeout(const Duration(seconds: 60)); 
          
          if (cloudUrl.isNotEmpty) {
            updatedImages.add(image.copyWith(
              uri: cloudUrl,
              sourceType: ProductImageSource.networkUrl,
            ));
            print('✅ Upload concluído: $cloudUrl');
          } else {
            updatedImages.add(image);
          }
        } catch (e) {
          print('❌ Erro no upload da foto ${image.uri}: $e');
          updatedImages.add(image);
        }
      } else {
        // Já é link de nuvem
        updatedImages.add(image);
      }
    }

    // Sincroniza o campo 'photos' (legado) com os novos links da nuvem
    final updatedPhotos = updatedImages.map((img) => ProductPhoto(
      path: img.uri,
      isPrimary: img.label?.toLowerCase() == 'p' || img.label?.toLowerCase() == 'principal',
      photoType: img.label,
      colorKey: img.colorTag,
    )).toList();

    final productWithSaaS = product.copyWith(
      tenantId: _tenantId,
      images: updatedImages,
      photos: updatedPhotos,
    );

    // 2. Salva na Nuvem (Firestore)
    await _collection.doc(product.id).set(productWithSaaS.toMap());
    // 3. Salva no Local (Hive) para velocidade e offline imediato
    await _localRepo.addProduct(productWithSaaS);
  }

  @override
  Future<void> updateProduct(Product product) async => addProduct(product);

  @override
  Future<void> deleteProduct(String id) async {
    await _collection.doc(id).delete();
    await _localRepo.deleteProduct(id);
  }

  @override
  Future<void> clearAll() async {
    // Nota: Deletar tudo no Firestore exige cuidado (batch), aqui limpamos o local
    await _localRepo.clearAll();
  }

  @override
  Future<Product?> getByRef(String ref) async {
    final snapshot = await _collection
        .where('tenantId', isEqualTo: _tenantId)
        .where('ref', isEqualTo: ref)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return Product.fromMap(snapshot.docs.first.data());
    }
    return _localRepo.getByRef(ref);
  }

  @override
  Stream<List<Product>> watchProducts() {
    // Sincronização Reativa: Escuta o Firestore e atualiza o estado
    return _collection.where('tenantId', isEqualTo: _tenantId).snapshots().map((
      snapshot,
    ) {
      final products = snapshot.docs
          .map((doc) => Product.fromMap(doc.data()))
          .toList();
      // Opcional: Atualizar o Hive local em background aqui
      return products;
    });
  }

  @override
  Future<List<Product>> getProductsByCategory(String categoryId) async {
    final snapshot = await _collection
        .where('tenantId', isEqualTo: _tenantId)
        .where('categoryIds', arrayContains: categoryId)
        .get();
    return snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList();
  }

  @override
  Stream<List<Product>> watchProductsByCategory(String categoryId) {
    return _collection
        .where('tenantId', isEqualTo: _tenantId)
        .where('categoryIds', arrayContains: categoryId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList(),
        );
  }
}

// Provedor que decide qual repositório usar baseado no login
final syncProductsRepositoryProvider = Provider<ProductsRepositoryContract>((
  ref,
) {
  final tenantAsync = ref.watch(currentTenantProvider);
  final localRepo =
      ref.watch(productsRepositoryProvider) as HiveProductsRepository;
  final storageService = ref.watch(saasPhotoStorageProvider);

  return tenantAsync.when(
    data: (tenant) {
      if (tenant != null) {
        // ✨ SaaS Logic: Na Web, usamos a nuvem em tempo real (Live Cloud)
        // No Celular/Desktop, usamos o cache local resiliente.
        if (kIsWeb) {
          // O FirestoreProductsRepository lida com Firestore e Hive. 
          // Mas aqui garantimos que a fonte da verdade na Web é sempre a nuvem.
          return FirestoreProductsRepository(
            localRepo,
            storageService,
            tenant.id,
          );
        }
        
        return FirestoreProductsRepository(
          localRepo,
          storageService,
          tenant.id,
        );
      }
      return localRepo;
    },
    loading: () => localRepo,
    error: (_, _) => localRepo,
  );
});

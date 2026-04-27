import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';
import 'package:catalogo_ja/core/sync/handlers/sync_entity_handler.dart';
import 'package:catalogo_ja/core/sync/handlers/media_upload_resolver.dart';
import 'package:catalogo_ja/core/sync/policies/sync_conflict_policy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';

class ProductSyncHandler implements SyncEntityHandler {
  final MediaUploadResolver _mediaResolver;
  final SyncConflictPolicy _conflictPolicy;
  final HiveProductsRepository _localRepo;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ProductSyncHandler(this._mediaResolver, this._conflictPolicy, this._localRepo);

  @override
  String get entityType => 'product';

  @override
  Future<void> processItem(SyncQueueItem item) async {
    final docRef = _firestore
        .collection('tenants')
        .doc(item.tenantId)
        .collection('products')
        .doc(item.entityId);

    if (item.operation == SyncOperation.delete) {
      await docRef.delete();
      return;
    }

    if (item.payload == null) {
      throw Exception('Missing payload for operation ${item.operation}');
    }

    // RESOLUÇÃO DE CONFLITO
    if (item.operation == SyncOperation.update) {
      final snapshot = await docRef.get(const GetOptions(source: Source.server));
      final remoteData = snapshot.exists ? snapshot.data() : null;

      final localWins = await _conflictPolicy.resolveConflict(
        localItem: item,
        remoteData: remoteData,
      );

      if (!localWins) {
        item.status = SyncItemStatus.conflict;
        item.errorMessage = 'Conflict detected: Server has newer version.';
        throw Exception(item.errorMessage);
      }
    }

    // 🌟 RESOLUÇÃO DE MÍDIA: Processa fotos locais antes de enviar para nuvem
    Map<String, dynamic> payload = Map<String, dynamic>.from(item.payload!);
    bool hasUrlModifications = false;
    
    if (payload['images'] != null) {
      List<dynamic> imagesList = payload['images'];
      List<Map<String, dynamic>> updatedImages = [];

      for (var imgData in imagesList) {
        Map<String, dynamic> imgMap = Map<String, dynamic>.from(imgData);
        final uri = imgMap['uri'] as String?;
        final label = imgMap['label'] as String?;
        
        if (uri != null) {
          final cloudUrl = await _mediaResolver.resolveImageUri(
            localUri: uri,
            entityId: item.entityId,
            tenantId: item.tenantId,
            label: label,
          );
          
          if (cloudUrl != uri) {
            imgMap['uri'] = cloudUrl;
            imgMap['sourceType'] = ProductImageSource.networkUrl.name;
            hasUrlModifications = true;
          }
        }
        updatedImages.add(imgMap);
      }
      payload['images'] = updatedImages;
    }

    // Compatibilidade com a lista legada de photos
    if (payload['photos'] != null) {
      List<dynamic> photosList = payload['photos'];
      List<Map<String, dynamic>> updatedPhotos = [];
      for (var photoData in photosList) {
        Map<String, dynamic> photoMap = Map<String, dynamic>.from(photoData);
        final path = photoMap['path'] as String?;
        if (path != null) {
          final cloudUrl = await _mediaResolver.resolveImageUri(
            localUri: path,
            entityId: item.entityId,
            tenantId: item.tenantId,
          );
          if (cloudUrl != path) {
            photoMap['path'] = cloudUrl;
            hasUrlModifications = true;
          }
        }
        updatedPhotos.add(photoMap);
      }
      payload['photos'] = updatedPhotos;
    }

    // PERSISTÊNCIA REMOTA CONSOLIDADA
    payload['tenantId'] = item.tenantId;

    if (item.operation == SyncOperation.create) {
      await docRef.set(payload);
    } else if (item.operation == SyncOperation.update) {
      await docRef.set(payload, SetOptions(merge: true));
    }

    // PÓS-SYNC LOCAL: Se resolvemos mídias, atualiza o Hive para o usuário não ver loadings eternos
    if (hasUrlModifications) {
      try {
        final updatedProduct = Product.fromMap(payload);
        await _localRepo.updateProduct(updatedProduct);
      } catch (e) {
        // Ignora erro, pois o principal foi sincronizado
      }
    }
  }
}

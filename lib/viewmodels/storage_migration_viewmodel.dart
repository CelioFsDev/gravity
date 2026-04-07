import 'dart:async';
import 'dart:convert';
import 'package:catalogo_ja/core/services/minio_photo_storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/providers/storage_provider.dart';
import '../models/product_image.dart';

class MigrationLog {
  final String message;
  final bool isError;
  final DateTime timestamp;

  MigrationLog(this.message, {this.isError = false}) : timestamp = DateTime.now();
}

class MigrationState {
  final bool isRunning;
  final int totalItems;
  final int processedItems;
  final List<MigrationLog> logs;
  final String? currentItem;

  MigrationState({
    this.isRunning = false,
    this.totalItems = 0,
    this.processedItems = 0,
    this.logs = const [],
    this.currentItem,
  });

  MigrationState copyWith({
    bool? isRunning,
    int? totalItems,
    int? processedItems,
    List<MigrationLog>? logs,
    String? currentItem,
  }) {
    return MigrationState(
      isRunning: isRunning ?? this.isRunning,
      totalItems: totalItems ?? this.totalItems,
      processedItems: processedItems ?? this.processedItems,
      logs: logs ?? this.logs,
      currentItem: currentItem ?? this.currentItem,
    );
  }

  double get progress => totalItems == 0 ? 0 : processedItems / totalItems;
}

final storageMigrationViewModelProvider =
    StateNotifierProvider<StorageMigrationViewModel, MigrationState>((ref) {
  return StorageMigrationViewModel(ref);
});

class StorageMigrationViewModel extends StateNotifier<MigrationState> {
  final Ref _ref;
  StorageMigrationViewModel(this._ref) : super(MigrationState());

  void _addLog(String message, {bool isError = false}) {
    state = state.copyWith(
      logs: [MigrationLog(message, isError: isError), ...state.logs.take(100)],
    );
  }

  Future<void> startMigration() async {
    if (state.isRunning) return;

    state = MigrationState(isRunning: true, logs: [MigrationLog('🚀 Iniciando migração...')]);

    try {
      final storageService = _ref.read(storageServiceProvider);

      // --- BYPASS DE SEGURANÇA PARA MIGRAÇÃO ---
      if (storageService is MinioPhotoStorageService) {
        storageService.setAdminSecret('super-secret-migration-key');
      }
      // ------------------------------------------

      // 1. Coletar tarefas
      _addLog('🔍 Varrendo banco de dados...');

      final firestore = FirebaseFirestore.instance;
      final productDocs = await firestore.collection('products').get();
      final categoryDocs = await firestore.collection('categories').get();
      final catalogDocs = await firestore.collection('catalogs').get();

      final total = productDocs.docs.length + categoryDocs.docs.length + catalogDocs.docs.length;
      state = state.copyWith(totalItems: total);

      // 2. Processar Produtos
      for (var doc in productDocs.docs) {
        if (!state.isRunning) break;
        final data = doc.data();
        final productId = doc.id;
        final tenantId = (data['tenantId'] ?? 'default').toString();
        state = state.copyWith(currentItem: 'Produto: ${data['name'] ?? productId}', processedItems: state.processedItems + 1);

        bool changed = false;
        
        // Imagens modernas
        final images = List<Map<String, dynamic>>.from(data['images'] as List? ?? []);
        for (int i = 0; i < images.length; i++) {
          final uri = images[i]['uri'] as String?;
          if (uri != null && uri.contains('firebasestorage.googleapis.com')) {
            _addLog('📸 Migrando imagem de produto $productId...');
            final newUrl = await _migrateFile(uri, (bytes, fileName) => storageService.uploadProductImage(
              bytes: bytes,
              productId: productId,
              tenantId: tenantId,
              label: (images[i]['label'] ?? 'P').toString(),
              colorTag: images[i]['colorTag']?.toString(),
            ));
            if (newUrl != null) {
              images[i]['uri'] = newUrl;
              changed = true;
            }
          }
        }

        // Photos legado
        final photos = List<Map<String, dynamic>>.from(data['photos'] as List? ?? []);
        for (int i = 0; i < photos.length; i++) {
          final path = photos[i]['path'] as String?;
          if (path != null && path.contains('firebasestorage.googleapis.com')) {
             _addLog('📷 Migrando foto legado de produto $productId...');
             final newUrl = await _migrateFile(path, (bytes, fileName) => storageService.uploadProductImage(
              bytes: bytes,
              productId: productId,
              tenantId: tenantId,
              label: (photos[i]['photoType'] ?? (photos[i]['isPrimary'] == true ? 'principal' : 'P')).toString(),
              colorTag: photos[i]['colorKey']?.toString(),
             ));
             if (newUrl != null) {
               photos[i]['path'] = newUrl;
               changed = true;
             }
          }
        }

        if (changed) {
          await doc.reference.update({'images': images, 'photos': photos});
        }
      }

      // 3. Processar Categorias
      for (var doc in categoryDocs.docs) {
        if (!state.isRunning) break;
        final data = doc.data();
        final categoryId = doc.id;
        final tenantId = (data['tenantId'] ?? 'default').toString();
        state = state.copyWith(currentItem: 'Categoria: ${data['name'] ?? categoryId}', processedItems: state.processedItems + 1);

        final cover = data['cover'] != null ? Map<String, dynamic>.from(data['cover'] as Map) : null;
        if (cover != null) {
          bool changed = false;
          final keys = ['coverImagePath', 'bannerImagePath', 'heroImagePath', 'coverHeaderImagePath', 'coverMainImagePath', 'coverMiniPath', 'coverPagePath'];
          
          for (var key in keys) {
            final uri = cover[key] as String?;
            if (uri != null && uri.contains('firebasestorage.googleapis.com')) {
               _addLog('🎨 Migrando capa $key de categoria $categoryId...');
               final newUrl = await _migrateFile(uri, (bytes, fileName) => storageService.uploadCategoryCover(
                 bytes: bytes,
                 categoryId: categoryId,
                 storeId: tenantId,
                 type: key.replaceAll('ImagePath', ''),
               ));
               if (newUrl != null) {
                 cover[key] = newUrl;
                 changed = true;
               }
            }
          }
          if (changed) {
            await doc.reference.update({'cover': cover});
          }
        }
      }

      // 4. Processar Catálogos
      for (var doc in catalogDocs.docs) {
        if (!state.isRunning) break;
        final data = doc.data();
        final catalogId = doc.id;
        final tenantId = (data['tenantId'] ?? 'default').toString();
        state = state.copyWith(currentItem: 'Catálogo: ${data['name'] ?? catalogId}', processedItems: state.processedItems + 1);

        final bannerUrl = data['bannerUrl'] as String?;
        final pdfUrl = data['pdfUrl'] as String?;
        Map<String, dynamic> updates = {};

        if (bannerUrl != null && bannerUrl.contains('firebasestorage.googleapis.com')) {
          _addLog('🖼️ Migrando banner de catálogo $catalogId...');
          final newUrl = await _migrateFile(bannerUrl, (bytes, fileName) => storageService.uploadCatalogBanner(
            bytes: bytes,
            catalogId: catalogId,
            storeId: tenantId,
          ));
          if (newUrl != null) updates['bannerUrl'] = newUrl;
        }

        if (pdfUrl != null && pdfUrl.contains('firebasestorage.googleapis.com')) {
           _addLog('📄 Migrando PDF de catálogo $catalogId...');
           final newUrl = await _migrateFile(pdfUrl, (bytes, fileName) => storageService.uploadCatalogPdf(
            pdfBytes: bytes,
            catalogId: catalogId,
            tenantId: tenantId,
           ));
           if (newUrl != null) updates['pdfUrl'] = newUrl;
        }

        if (updates.isNotEmpty) {
          await doc.reference.update(updates);
        }
      }

      _addLog('✅ Migração concluída com sucesso!');
      state = state.copyWith(isRunning: false, currentItem: 'Concluído');

    } catch (e) {
      _addLog('❌ Erro na migração: $e', isError: true);
      state = state.copyWith(isRunning: false);
    } finally {
      // Limpa a chave mestra
      final storageService = _ref.read(storageServiceProvider);
      if (storageService is MinioPhotoStorageService) {
        storageService.setAdminSecret(null);
      }
    }
  }

  Future<String?> _migrateFile(String firebaseUri, Future<String?> Function(Uint8List, String) uploadFn) async {
    try {
      final response = await http.get(Uri.parse(firebaseUri));
      if (response.statusCode != 200) return null;
      
      final bytes = response.bodyBytes;
      final fileName = firebaseUri.split('/').last.split('?').first;
      
      return await uploadFn(bytes, fileName);
    } catch (e) {
      _addLog('   ⚠️ Falha ao migrar arquivo: $e', isError: true);
      return null;
    }
  }

  void stop() {
    state = state.copyWith(isRunning: false);
    _addLog('⏹️ Migração interrompida pelo usuário.');
  }
}

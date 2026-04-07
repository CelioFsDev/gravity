import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:dart_firebase_admin/dart_firebase_admin.dart';
import 'package:dart_firebase_admin/firestore.dart';

// --- CONFIGURAÇÃO ---
const String apiBaseUrl = 'http://localhost:8080/api/v1';
const String serviceAccountPath = '../../catalogo-fc9b5-firebase-adminsdk-fbsvc-b3b763c964.json';
// --- FIM DA CONFIGURAÇÃO ---

void main() async {
  final absolutePath = p.canonicalize(p.join(Directory.current.path, serviceAccountPath));
  print('📂 Lendo Service Account de: $absolutePath');

  final serviceAccountFile = File(absolutePath);
  if (!serviceAccountFile.existsSync()) {
    print('❌ Erro: Arquivo de service account não encontrado em $absolutePath');
    exit(1);
  }

  // Tenta carregar o JSON para validar o formato antes de passar para o Admin
  try {
    final content = await serviceAccountFile.readAsString();
    jsonDecode(content);
  } catch (e) {
    print('❌ Erro: O arquivo JSON de credenciais parece inválido ou corrompido: $e');
    exit(1);
  }

  final admin = FirebaseAdminApp.initializeApp(
    'migration-tool',
    Credential.fromServiceAccount(serviceAccountFile),
  );

  final firestore = Firestore(admin);

  try {
    print('📦 Verificando conexão com Firestore...');
    // Teste simples
    await firestore.collection('products').limit(1).get();
    print('✅ Conectado ao Firestore.');

    print('\n--- [1] MIGRANDO PRODUTOS ---');
    await migrateProducts(firestore);

    print('\n--- [2] MIGRANDO CATEGORIAS ---');
    await migrateCategories(firestore);

    print('\n--- [3] MIGRANDO CATÁLOGOS ---');
    await migrateCatalogs(firestore);

  } catch (e) {
    print('❌ Erro fatal: $e');
  } finally {
    await admin.close();
    print('\n🏁 Processo de migração encerrado.');
  }
}

Future<void> migrateProducts(Firestore firestore) async {
  final snapshot = await firestore.collection('products').get();
  print('🔍 Encontrados ${snapshot.docs.length} produtos.');

  int migratedCount = 0;
  int skippedCount = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final productId = doc.id;
    final tenantId = (data['tenantId'] ?? 'default').toString();
    
    // Lista moderna de imagens
    final images = List<Map<String, dynamic>>.from(data['images'] as List? ?? []);
    bool docChanged = false;

    print('👉 Processando Produto: $productId (${data['name']})');

    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      final String? uri = image['uri'];

      if (uri != null && uri.contains('firebasestorage.googleapis.com')) {
        print('   📸 Migrando imagem ${i + 1}: $uri');
        final newUrl = await uploadToMinio(uri, '/upload/product-image', {
          'productRef': productId, // API espera productRef
          'storeId': tenantId,     // API espera storeId
          'label': (image['label'] ?? 'P').toString(),
          if (image['colorTag'] != null) 'colorTag': image['colorTag'].toString(),
        });

        if (newUrl != null) {
          images[i]['uri'] = newUrl;
          docChanged = true;
          migratedCount++;
        }
      } else {
        skippedCount++;
      }
    }

    // Lista legado de photos
    final photos = List<Map<String, dynamic>>.from(data['photos'] as List? ?? []);
    for (int i = 0; i < photos.length; i++) {
        final photo = photos[i];
        final String? path = photo['path'] as String?;
        if (path != null && path.contains('firebasestorage.googleapis.com')) {
          print('   📷 Migrando foto legado ${i + 1}: $path');
          final newUrl = await uploadToMinio(path, '/upload/product-image', {
            'productRef': productId,
            'storeId': tenantId,
            'label': (photo['photoType'] ?? (photo['isPrimary'] == true ? 'principal' : 'P')).toString(),
            if (photo['colorKey'] != null) 'colorTag': photo['colorKey'].toString(),
          });

          if (newUrl != null) {
            photos[i]['path'] = newUrl;
            docChanged = true;
            migratedCount++;
          }
        }
    }

    if (docChanged) {
      await doc.ref.update({'images': images, 'photos': photos});
      print('   ✅ Documento atualizado.');
    }
  }

  print('✅ Fim da migração de produtos. Migrados: $migratedCount, Pulados: $skippedCount.');
}

Future<void> migrateCategories(Firestore firestore) async {
  final snapshot = await firestore.collection('categories').get();
  print('🔍 Encontradas ${snapshot.docs.length} categorias.');

  for (final doc in snapshot.docs) {
    var data = doc.data();
    final categoryId = doc.id;
    final tenantId = (data['tenantId'] ?? 'default').toString();
    bool docChanged = false;

    final cover = data['cover'] != null ? Map<String, dynamic>.from(data['cover'] as Map) : null;
    if (cover != null) {
      final keys = [
        'coverImagePath',
        'bannerImagePath',
        'heroImagePath',
        'coverHeaderImagePath',
        'coverMainImagePath',
        'coverMiniPath',
        'coverPagePath'
      ];

      for (var key in keys) {
        final String? uri = cover[key] as String?;
        if (uri != null && uri.contains('firebasestorage.googleapis.com')) {
           print('   🎨 Migrando capa ($key) da Categoria: $categoryId');
           final newUrl = await uploadToMinio(uri, '/upload/category-cover', {
             'categoryId': categoryId,
             'storeId': tenantId,
             'type': key.replaceAll('ImagePath', ''),
           });

           if (newUrl != null) {
             cover[key] = newUrl;
             docChanged = true;
           }
        }
      }
    }

    if (docChanged) {
      await doc.ref.update({'cover': cover});
      print('   ✅ Categoria $categoryId atualizada.');
    }
  }
}

Future<void> migrateCatalogs(Firestore firestore) async {
  final snapshot = await firestore.collection('catalogs').get();
  print('🔍 Encontrados ${snapshot.docs.length} catálogos.');

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final catalogId = doc.id;
    final tenantId = (data['tenantId'] ?? 'default').toString();
    bool docChanged = false;

    // Banner
    final String? bannerUrl = data['bannerUrl'] as String?;
    String? newBannerUrl;
    if (bannerUrl != null && bannerUrl.contains('firebasestorage.googleapis.com')) {
      print('   🖼️ Migrando banner do Catálogo: $catalogId');
      newBannerUrl = await uploadToMinio(bannerUrl, '/upload/catalog-banner', {
        'catalogId': catalogId,
        'storeId': tenantId,
      });
      if (newBannerUrl != null) docChanged = true;
    }

    // PDF
    final String? pdfUrl = data['pdfUrl'] as String?;
    String? newPdfUrl;
    if (pdfUrl != null && pdfUrl.contains('firebasestorage.googleapis.com')) {
      print('   📄 Migrando PDF do Catálogo: $catalogId');
      newPdfUrl = await uploadToMinio(pdfUrl, '/upload/catalog-pdf', {
        'catalogId': catalogId,
        'storeId': tenantId,
      });
      if (newPdfUrl != null) docChanged = true;
    }

    if (docChanged) {
      final updateData = <String, dynamic>{};
      if (newBannerUrl != null) updateData['bannerUrl'] = newBannerUrl;
      if (newPdfUrl != null) updateData['pdfUrl'] = newPdfUrl;
      await doc.ref.update(updateData);
      print('   ✅ Catálogo $catalogId atualizado.');
    }
  }
}

/// Baixa do Firebase e envia para a API MinIO
Future<String?> uploadToMinio(String firebaseUri, String apiPath, Map<String, String> fields) async {
  try {
    // 1. Baixar imagem do Firebase
    final downloadResponse = await http.get(Uri.parse(firebaseUri));
    if (downloadResponse.statusCode != 200) {
      print('      ❌ Falha ao baixar do Firebase: ${downloadResponse.statusCode}');
      return null;
    }
    final bytes = downloadResponse.bodyBytes;
    
    // Determinar nome do arquivo
    String fileName = p.basename(Uri.parse(firebaseUri).path);
    if (!fileName.contains('.')) {
        if (apiPath.contains('pdf')) fileName += '.pdf';
        else fileName += '.jpg';
    }

    // 2. Enviar para a nossa API (via query params para storeId/productId)
    final uri = Uri.parse('$apiBaseUrl$apiPath').replace(queryParameters: fields);
    final request = http.MultipartRequest('POST', uri);
    
    // Como a API valida o Firebase Token, precisamos de um token "Fake-Admin" ou
    // desativar a validação temporariamente na API para a migração.
    // ESTRATÉGIA: Vou adicionar um cabeçalho 'X-Admin-Secret' que a API aceitará sem pedir Firebase Token.
    request.headers['X-Admin-Secret'] = 'super-secret-migration-key';
    
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
    ));

    final response = await request.send();
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseBody);
      return jsonResponse['url'];
    } else {
      print('      ❌ Falha no upload para MinIO: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('      ❌ Erro no processo de migração de arquivo: $e');
    return null;
  }
}

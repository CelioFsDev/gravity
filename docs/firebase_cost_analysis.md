# 🔥 Análise de Custos Firebase — Gravity / Catálogo Já

> Análise completa de todos os pontos onde o Firebase é lido/escrito desnecessariamente, com soluções priorizadas.

---

## 📊 Resumo Executivo dos Problemas

| # | Arquivo | Problema | Impacto | Prioridade |
|---|---------|----------|---------|------------|
| 1 | `tenant_viewmodel.dart` | `StreamProvider` com `.snapshots()` + `asyncMap` que faz **2 leituras Firestore** em tempo real por sessão | 🔴 Alto | P1 |
| 2 | `auth_viewmodel.dart` | `_triggerInitialDataDownload()` chama `syncFromCloud` no login que **relê todo Firestore** mesmo com dados locais frescos | 🔴 Alto | P1 |
| 3 | `firestore_products_repository.dart → getProducts()` | **Merge Cloud+Local sempre** — relê todos os produtos do Firestore a cada `build()` do ViewModel | 🔴 Alto | P1 |
| 4 | `firestore_catalogs_repository.dart → getCatalogs()` | Lê **todos** os catálogos do Firestore (sem cache, sem verificação de staleness) | 🟡 Médio | P2 |
| 5 | `firestore_categories_repository.dart → getCategories()` | Idem — lê todas as categorias do Firestore a cada `build()` | 🟡 Médio | P2 |
| 6 | `categories_viewmodel.dart → _fetchData()` | Chama `productRepository.getProducts()` via `syncProductsRepositoryProvider` (**leitura Firestore**) só para contar produtos | 🟡 Médio | P2 |
| 7 | `catalogs_viewmodel.dart` + `categories_viewmodel.dart` | Fallback de `tenantId` via `FirebaseFirestore.instance.collection('users').doc(email).get()` duplicado em **3 viewmodels** | 🟠 Médio | P2 |
| 8 | `firestore_products_repository.dart → watchProducts()` | Stream em tempo real de **todos** os produtos — não é usado na tela principal mas está disponível | 🟠 Médio | P3 |
| 9 | `firestore_catalogs_repository.dart → watchCatalogs()` | Idem — stream real-time exposta sem necessidade | 🟠 Baixo | P3 |
| 10 | `user_repository.dart → ensureUserProfile()` | **Read + Write** no Firestore a **cada login/refresh** de authState | 🟡 Médio | P2 |
| 11 | `firestore_products_repository.dart → addProduct()` | No Desktop/Mobile, todo `addProduct` ainda passa pelo `syncProductsRepositoryProvider` que **é Firestore** | 🔴 Alto | P1 |
| 12 | `categories_viewmodel.dart → addCategory/updateCategory` | Usa `syncCategoriesRepositoryProvider` que **salva direto no Firestore** no Desktop/Mobile | 🔴 Alto | P1 |
| 13 | `categories_viewmodel.dart → reorder()` | Faz N writes no Firestore (um por categoria) em cada reordenação de drag-and-drop | 🟡 Médio | P2 |
| 14 | `products_viewmodel.dart → updateStatusSelected / updateCategorySelected` | Loop de N updates, cada um = 1 write Firestore (no Web) | 🟠 Médio | P2 |
| 15 | `firestore_products_repository.dart → getByRef()` | Leitura Firestore para busca por referência, ignora cache local | 🟠 Baixo | P3 |
| 16 | `products_viewmodel.dart → syncFromCloud()` | `firestoreRepo.getProducts()` chama `getProducts()` que **também tenta merge cloud+local**, duplicando leitura | 🔴 Alto | P1 |

---

## 🔍 Análise Detalhada por Problema

---

### P1-A · `tenant_viewmodel.dart` — Stream dupla no Firestore

**PROBLEMA:** Abre 2 listeners em tempo real simultâneos. Cada mudança em `/users/{email}` dispara automaticamente uma nova leitura em `/tenants/{id}`.

```dart
// ANTES (gera 2-3 leituras por trigger)
return FirebaseFirestore.instance
    .collection('users')
    .doc(email)
    .snapshots()           // Stream 1: listener permanente em /users/{email}
    .asyncMap((userDoc) async {
      final tenantId = userDoc.data()?['tenantId'];
      return ref.read(tenantRepositoryProvider).getTenant(tenantId); // Read /tenants/{id}
    });
```

**SOLUÇÃO:** Adicionar `.distinct()` para filtrar re-emissões sem mudança real de tenantId:

```dart
// DEPOIS (só relê tenant quando tenantId mudou de fato)
return FirebaseFirestore.instance
    .collection('users')
    .doc(email)
    .snapshots()
    .distinct((a, b) => a.data()?['tenantId'] == b.data()?['tenantId'])
    .asyncMap((userDoc) async {
      if (!userDoc.exists) return null;
      final tenantId = userDoc.data()?['tenantId'] as String?;
      if (tenantId == null || tenantId.isEmpty) return null;
      return ref.read(tenantRepositoryProvider).getTenant(tenantId);
    });
```

---

### P1-B · `auth_viewmodel.dart` — Sync forçado no login ignora dados locais

**PROBLEMA:** Toda vez que o usuário faz login, `_triggerInitialDataDownload()` relê TODOS os dados da nuvem mesmo que o cache local esteja fresco.

**SOLUÇÃO:** Usar timestamp do último sync armazenado localmente:

```dart
// Adicionar em auth_viewmodel.dart
Future<bool> _shouldSync(String key, {Duration maxAge = const Duration(hours: 4)}) async {
  final prefs = await SharedPreferences.getInstance();
  final lastSyncMs = prefs.getInt('last_sync_$key');
  if (lastSyncMs == null) return true;
  final lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
  return DateTime.now().difference(lastSync) > maxAge;
}

void _triggerInitialDataDownload() async {
  // Só sincroniza se dados locais estão velhos (> 4 horas)
  final shouldSyncCategories = await _shouldSync('categories');
  final shouldSyncProducts = await _shouldSync('products');
  final shouldSyncCatalogs = await _shouldSync('catalogs');
  
  await Future.wait([
    if (shouldSyncCategories) 
      ref.read(categoriesViewModelProvider.notifier).syncFromCloud(),
    if (shouldSyncProducts) 
      ref.read(productsViewModelProvider.notifier).syncFromCloud(),
    if (shouldSyncCatalogs) 
      ref.read(catalogsViewModelProvider.notifier).syncFromCloud(),
  ]);
}
```

Cada `syncFromCloud()` deve salvar o timestamp ao terminar:
```dart
// No fim de cada syncFromCloud():
final prefs = await SharedPreferences.getInstance();
await prefs.setInt('last_sync_products', DateTime.now().millisecondsSinceEpoch);
```

---

### P1-C · Repositórios Firestore — Nenhum cache em memória

**PROBLEMA:** `getProducts()`, `getCategories()`, `getCatalogs()` sempre vão ao Firestore. O `build()` dos ViewModels é chamado com frequência (ao invalidar providers), gerando leituras duplicadas.

**SOLUÇÃO:** Cache em memória com TTL de 5 minutos + busca incremental:

```dart
// Adicionar em FirestoreProductsRepository:
List<Product>? _memoryCache;
DateTime? _cacheTimestamp;
static const _cacheDuration = Duration(minutes: 5);

bool get _isCacheValid =>
    _memoryCache != null &&
    _cacheTimestamp != null &&
    DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;

@override
Future<List<Product>> getProducts() async {
  if (_isCacheValid) return List.from(_memoryCache!); // Retorna cache instantâneo

  try {
    final localProducts = await _localRepo.getProducts();
    
    // Busca incremental: só o que mudou desde o produto mais recente local
    DateTime? mostRecentLocal;
    if (localProducts.isNotEmpty) {
      mostRecentLocal = localProducts
          .map((p) => p.updatedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }

    Query<Map<String, dynamic>> query = _collection
        .where('tenantId', isEqualTo: _tenantId);
    
    if (mostRecentLocal != null) {
      query = query.where('updatedAt',
          isGreaterThan: Timestamp.fromDate(mostRecentLocal));
    }

    final snapshot = await query.get().timeout(const Duration(seconds: 10));
    final newCloudProducts = snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList();

    final merged = <String, Product>{for (final p in localProducts) p.id: p};
    for (final p in newCloudProducts) {
      merged[p.id] = p;
      await _localRepo.addProduct(p); // Persiste localmente
    }

    final result = merged.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _memoryCache = result;
    _cacheTimestamp = DateTime.now();
    return result;
  } catch (e) {
    return _localRepo.getProducts(); // Fallback local
  }
}

void invalidateCache() {
  _memoryCache = null;
  _cacheTimestamp = null;
}
```

---

### P1-D · `categories_viewmodel.dart` — Salva direto no Firestore no Desktop/Mobile

**PROBLEMA:** O padrão local-first correto está implementado em `ProductsViewModel`, mas `CategoriesViewModel` e `CatalogsViewModel` não fazem a distinção Web × Desktop/Mobile.

```dart
// ANTES — categories_viewmodel.dart addCategory() (SEMPRE vai ao Firestore)
final categoriesRepo = ref.read(syncCategoriesRepositoryProvider); // FirestoreCategoriesRepository
await categoriesRepo.addCategory(newCat); // 💸 Write Firestore imediato
```

**SOLUÇÃO:** Mesma lógica de produtos:

```dart
// DEPOIS — categories_viewmodel.dart
Future<String?> addCategory(String name, CategoryType type, ...) async {
  // ...validações...
  
  if (kIsWeb) {
    // Web: salva direto na nuvem (sem armazenamento local permanente confiável)
    final cloudRepo = ref.read(syncCategoriesRepositoryProvider);
    await cloudRepo.addCategory(newCat);
  } else {
    // Desktop/Mobile: salva LOCAL, sincroniza quando o usuário quiser
    final localRepo = ref.read(categoriesRepositoryProvider);
    await localRepo.addCategory(newCat);
  }
  
  await _refresh();
  return null;
}
```

O mesmo padrão deve ser aplicado em:
- `CategoriesViewModel.updateCategory()`
- `CategoriesViewModel.addCollection()`
- `CategoriesViewModel.updateCollection()`
- `CatalogsViewModel.deleteCatalog()`
- Qualquer método de escrita em `CatalogsViewModel`

---

### P2-A · `categories_viewmodel._fetchData()` — Lê produtos do Firestore só para contar

```dart
// ANTES
final productRepository = ref.watch(syncProductsRepositoryProvider); // Firestore
final allProducts = await productRepository.getProducts(); // 💸 Leitura Full
```

**SOLUÇÃO:**
```dart
// DEPOIS — usa repo local (já sincronizado)
final localProductRepo = ref.read(productsRepositoryProvider); // Hive
final allProducts = await localProductRepo.getProducts(); // Leitura local zero-cost
```

---

### P2-B · Fallback de `tenantId` duplicado em 3 ViewModels

O mesmo bloco de código existe copiado em `products_viewmodel.dart`, `catalogs_viewmodel.dart` e `categories_viewmodel.dart`:

```dart
// Copiado 3 vezes — gera 1 leitura Firestore extra por ViewModel no syncAllToCloud
if (tenantId == null) {
  final userDoc = await FirebaseFirestore.instance
      .collection('users').doc(email).get(); // 💸 Leitura duplicada
  tenantId = userDoc.data()?['tenantId'] as String?;
}
```

**SOLUÇÃO:** Centralizar em `TenantRepository` com cache:

```dart
// tenant_repository.dart
String? _cachedTenantId;

Future<String?> getCachedTenantId(String email) async {
  if (_cachedTenantId != null) return _cachedTenantId;
  final doc = await _firestore.collection('users').doc(email).get();
  _cachedTenantId = doc.data()?['tenantId'] as String?;
  return _cachedTenantId;
}

void clearTenantCache() => _cachedTenantId = null; // Chamar no signOut()
```

---

### P2-C · `user_repository.dart ensureUserProfile()` — Read+Write a cada authStateChange

**PROBLEMA:** O stream `authStateChanges` pode emitir múltiplas vezes (ex: token refresh), e cada emissão chama `ensureUserProfile()` que faz 1 read + 1 write no Firestore.

**SOLUÇÃO:** Flag de sessão:

```dart
// user_repository.dart
static bool _profileSyncedThisSession = false;

Future<void> ensureUserProfileFromAuth(User user) async {
  if (_profileSyncedThisSession) return; // 🎯 Só uma vez por sessão
  _profileSyncedThisSession = true;
  
  final email = user.email?.trim().toLowerCase() ?? '';
  return ensureUserProfile(
    email: email,
    displayName: user.displayName ?? '',
    // ...
  );
}

static void resetSession() => _profileSyncedThisSession = false; // Chamar no signOut()
```

---

### P2-D · `categories_viewmodel.reorder()` — N writes por drag-and-drop

**PROBLEMA:** Cada `reorder()` escreve 1 documento por categoria. Com 20 categorias = 20 writes por drag.

**SOLUÇÃO:** Batch write para Web, local-only para Desktop/Mobile:

```dart
Future<void> reorder(int oldIndex, int newIndex) async {
  // 1. Atualiza UI otimisticamente
  // ...mover item na lista...
  state = AsyncData(newState);
  
  // 2. Persiste localmente primeiro (custo zero)
  final localRepo = ref.read(categoriesRepositoryProvider);
  for (var i = 0; i < list.length; i++) {
    await localRepo.updateCategory(list[i].copyWith(order: i));
  }
  
  // 3. Apenas no Web: escreve em batch (1 operação, não N)
  if (kIsWeb) {
    final tenant = await ref.read(currentTenantProvider.future);
    if (tenant != null) {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      for (var i = 0; i < list.length; i++) {
        final cat = list[i].copyWith(order: i, tenantId: tenant.id);
        batch.set(
          firestore.collection('categories').doc(cat.id),
          {'order': i, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true), // Só atualiza o campo 'order'
        );
      }
      await batch.commit(); // 💡 1 chamada de rede em vez de N
    }
  }
}
```

---

### P3-A · `syncFromCloud()` — Dupla leitura em `getProducts()`

```dart
// products_viewmodel.dart syncFromCloud()
final firestoreRepo = FirestoreProductsRepository(...);
final cloudProducts = await firestoreRepo.getProducts(); // getProducts() já faz merge com local!
// Depois ainda itera e escreve local novamente — TRABALHO DUPLICADO
```

**SOLUÇÃO:** `syncFromCloud()` deve chamar diretamente a collection Firestore, não `getProducts()`:

```dart
// Criar método dedicado no repositório
Future<List<Product>> fetchFromCloudOnly({DateTime? since}) async {
  Query<Map<String, dynamic>> query = _collection
      .where('tenantId', isEqualTo: _tenantId);
  if (since != null) {
    query = query.where('updatedAt', isGreaterThan: Timestamp.fromDate(since));
  }
  final snapshot = await query.get();
  return snapshot.docs.map((doc) => Product.fromMap(doc.data())).toList();
}
```

---

## ✅ Plano de Ação Prioritizado

### 🔴 FASE 1 — Impacto Imediato (maior retorno, menor risco)

1. **`user_repository.dart`** — Adicionar flag `_profileSyncedThisSession`
2. **`tenant_viewmodel.dart`** — Adicionar `.distinct()` no stream
3. **`categories_viewmodel.dart`** — Local-first em `addCategory`, `updateCategory`, `addCollection`, `updateCollection`
4. **`categories_viewmodel._fetchData()`** — Trocar `syncProductsRepositoryProvider` por `productsRepositoryProvider` na contagem
5. **`categories_viewmodel.reorder()`** — Batch write no Web, local-only no Desktop/Mobile

### 🟡 FASE 2 — Otimizações de Médio Prazo

6. **Cache em memória** nos 3 repositórios Firestore (Products, Categories, Catalogs)
7. **`auth_viewmodel._triggerInitialDataDownload()`** — Adicionar `lastSyncedAt` via SharedPreferences
8. **Centralizar fallback de `tenantId`** em `TenantRepository.getCachedTenantId()`
9. **`syncFromCloud()`** — Separar leitura cloud de merge local, evitar trabalho duplo

### 🟢 FASE 3 — Boas Práticas

10. **Remover `watchProducts()` + `watchCatalogs()`** do `FirestoreRepository` se não utilizados
11. **`getByRef()`** — tentar local antes de ir ao Firestore

---

## 📈 Estimativa de Redução de Custos

| Otimização | Ops/sessão atual | Ops/sessão após | Redução |
|------------|-----------------|-----------------|---------|
| Flag de sessão no ensureUserProfile | 2-4 reads/login | 1 read/login | -70% |
| distinct() no TenantProvider | 2-3 reads/trigger | 1 read/sessão | -70% |
| Local-first Categories/Catalogs (Desktop/Mobile) | N writes/ação | 0 writes imediatos | -100% escrita imediata |
| Cache em memória (5 min) nos repos | 5+ leituras full | 1 leitura incremental | -80% |
| lastSyncedAt no login | 3 full syncs/login | 0-3 condicional | -80% |
| Batch em reorder | N writes/drag | 1 batch/drag | -95% escrita |
| Contagem de produtos local | 1 leitura full extra | 0 | -100% |

> **Total estimado: redução de 70-85% nas operações Firestore por sessão típica.**

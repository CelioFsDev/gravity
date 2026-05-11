#!/usr/bin/env node

const crypto = require('crypto');
const path = require('path');

let admin;

const DEFAULT_PROJECT_ID = 'catalogo-ja-89aae';
const DEFAULT_BUCKET = 'catalogo-ja-89aae.firebasestorage.app';

function parseArgs(argv) {
  const args = {
    apply: false,
    project: DEFAULT_PROJECT_ID,
    bucket: DEFAULT_BUCKET,
    credentials: process.env.GOOGLE_APPLICATION_CREDENTIALS || '',
    tenant: '',
    catalog: '',
    whatsapp: '',
    rootOnly: false,
    tenantOnly: false,
  };

  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    switch (arg) {
      case '--apply':
        args.apply = true;
        break;
      case '--project':
        args.project = next || args.project;
        i += 1;
        break;
      case '--bucket':
        args.bucket = next || args.bucket;
        i += 1;
        break;
      case '--credentials':
        args.credentials = next || '';
        i += 1;
        break;
      case '--tenant':
        args.tenant = next || '';
        i += 1;
        break;
      case '--catalog':
        args.catalog = next || '';
        i += 1;
        break;
      case '--whatsapp':
        args.whatsapp = next || '';
        i += 1;
        break;
      case '--root-only':
        args.rootOnly = true;
        break;
      case '--tenant-only':
        args.tenantOnly = true;
        break;
      case '--help':
      case '-h':
        printHelp();
        process.exit(0);
        break;
      default:
        throw new Error(`Argumento desconhecido: ${arg}`);
    }
  }

  return args;
}

function printHelp() {
  console.log(`
Publica/repara vitrines publicas de catalogos.

Uso:
  node scripts/publish_public_catalogs.js --credentials service-account.json --whatsapp 5511999999999
  node scripts/publish_public_catalogs.js --credentials service-account.json --whatsapp 5511999999999 --apply

Opcoes:
  --apply              grava no Firestore/Storage. Sem isso, roda em simulacao.
  --credentials FILE   service account do projeto correto.
  --project ID         default: ${DEFAULT_PROJECT_ID}
  --bucket NAME        default: ${DEFAULT_BUCKET}
  --tenant ID          limita a um tenant.
  --catalog ID         limita a um catalogo.
  --whatsapp NUMBER    numero incluido em store.whatsappNumber do snapshot.
  --root-only          processa apenas /catalogs.
  --tenant-only        processa apenas /tenants/{tenantId}/catalogs.
`);
}

function loadFirebaseAdmin() {
  try {
    return require('firebase-admin');
  } catch (_) {
    try {
      return require(path.join(
        __dirname,
        '..',
        'functions',
        'node_modules',
        'firebase-admin',
      ));
    } catch (error) {
      throw new Error(
        'firebase-admin nao esta instalado. Rode "npm --prefix functions install" antes de publicar.',
        { cause: error },
      );
    }
  }
}

function initFirebase(args) {
  admin = loadFirebaseAdmin();
  const options = {
    projectId: args.project,
    storageBucket: args.bucket,
  };

  if (args.credentials) {
    const serviceAccount = require(path.resolve(args.credentials));
    options.credential = admin.credential.cert(serviceAccount);
  } else {
    options.credential = admin.credential.applicationDefault();
  }

  admin.initializeApp(options);
}

function generateShareCode() {
  const chars =
    '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const bytes = crypto.randomBytes(10);
  let code = '';
  for (const byte of bytes) {
    code += chars[byte % chars.length];
  }
  return code.toLowerCase();
}

function nowIso() {
  return new Date().toISOString();
}

function isTimestamp(value) {
  return value && typeof value.toDate === 'function';
}

function toJsonSafe(value) {
  if (isTimestamp(value)) return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(toJsonSafe);
  if (value && typeof value === 'object') {
    const out = {};
    for (const [key, item] of Object.entries(value)) {
      if (item === undefined) continue;
      out[key] = toJsonSafe(item);
    }
    return out;
  }
  return value;
}

function normalizeCatalog(raw, tenantId, docId) {
  const catalog = toJsonSafe(raw || {});
  const createdAt = catalog.createdAt || nowIso();
  const updatedAt = nowIso();
  const shareCode = String(catalog.shareCode || '').trim().toLowerCase();

  return {
    ...catalog,
    id: catalog.id || docId,
    tenantId: catalog.tenantId || tenantId,
    active: true,
    isPublic: true,
    shareCode: shareCode || generateShareCode(),
    productIds: Array.isArray(catalog.productIds)
      ? catalog.productIds.map(String)
      : [],
    createdAt,
    updatedAt,
    syncStatus: 'synced',
  };
}

function isHttpAsset(value) {
  return typeof value === 'string' && /^https?:\/\//i.test(value.trim());
}

function normalizePublicProduct(raw) {
  const product = toJsonSafe(raw || {});
  return {
    ...product,
    images: Array.isArray(product.images)
      ? product.images.filter((image) => isHttpAsset(image && image.uri))
      : [],
    photos: Array.isArray(product.photos)
      ? product.photos.filter((photo) => isHttpAsset(photo && photo.path))
      : [],
  };
}

async function loadTenants(db, tenantFilter) {
  if (tenantFilter) {
    const doc = await db.collection('tenants').doc(tenantFilter).get();
    return doc.exists ? [doc] : [];
  }
  const snapshot = await db.collection('tenants').get();
  return snapshot.docs;
}

async function loadCatalogDocs(tenantRef, catalogFilter) {
  if (catalogFilter) {
    const doc = await tenantRef.collection('catalogs').doc(catalogFilter).get();
    return doc.exists ? [doc] : [];
  }
  const snapshot = await tenantRef.collection('catalogs').get();
  return snapshot.docs;
}

async function loadRootCatalogDocs(db, catalogFilter) {
  if (catalogFilter) {
    const doc = await db.collection('catalogs').doc(catalogFilter).get();
    return doc.exists ? [doc] : [];
  }
  const snapshot = await db.collection('catalogs').get();
  return snapshot.docs;
}

async function loadTenantProducts(tenantRef) {
  const snapshot = await tenantRef.collection('products').get();
  const byId = new Map();

  for (const doc of snapshot.docs) {
    const data = toJsonSafe(doc.data());
    const ids = new Set([doc.id]);
    if (data.id) ids.add(String(data.id));
    for (const id of ids) byId.set(id, { id, data });
  }

  return byId;
}

async function loadTenantCategories(tenantRef) {
  const snapshot = await tenantRef.collection('categories').get();
  const byId = new Map();

  for (const doc of snapshot.docs) {
    const data = toJsonSafe(doc.data());
    const id = String(data.id || doc.id);
    byId.set(id, data);
  }

  return byId;
}

function buildSnapshot({ catalog, products, categories, whatsapp }) {
  return {
    schemaVersion: 1,
    publishedAt: nowIso(),
    store: {
      whatsappNumber: whatsapp || '',
      publicBaseUrl: 'https://catalogo-ja-89aae.web.app',
    },
    catalog,
    products: products.map(normalizePublicProduct),
    categories: categories.map(toJsonSafe),
  };
}

async function processCatalog({
  args,
  bucket,
  tenantRef,
  tenantId,
  catalogDoc,
  sourcePath,
  mirrorRoot,
  productsById,
  categoriesById,
}) {
  const original = catalogDoc.data();
  const catalog = normalizeCatalog(original, tenantId, catalogDoc.id);
  const missingProductIds = [];
  const inactiveProductIds = [];
  const existingProductIds = [];
  const publicProducts = [];

  for (const productId of catalog.productIds) {
    const found = productsById.get(productId);
    if (!found) {
      missingProductIds.push(productId);
      continue;
    }

    existingProductIds.push(String(found.data.id || found.id));
    if (found.data.isActive === false) {
      inactiveProductIds.push(productId);
      continue;
    }
    publicProducts.push(found.data);
  }

  catalog.productIds = existingProductIds;

  const usedCategoryIds = new Set();
  for (const product of publicProducts) {
    for (const id of product.categoryIds || []) usedCategoryIds.add(String(id));
  }

  const publicCategories = [...usedCategoryIds]
    .map((id) => categoriesById.get(id))
    .filter((category) => category && (category.type || 'productType') === 'productType');

  const snapshot = buildSnapshot({
    catalog,
    products: publicProducts,
    categories: publicCategories,
    whatsapp: args.whatsapp,
  });

  const snapshotPath = `public_catalogs/${catalog.shareCode}/catalog.json`;
  const link = `https://catalogo-ja-89aae.web.app/#/c/${catalog.shareCode}${
    args.whatsapp ? `?w=${encodeURIComponent(args.whatsapp)}` : ''
  }`;

  console.log(`\nCatalogo: ${catalog.name || catalog.id}`);
  console.log(`  origem: ${sourcePath || catalogDoc.ref.path}`);
  console.log(`  tenantId: ${catalog.tenantId}`);
  console.log(`  shareCode: ${catalog.shareCode}`);
  console.log(`  produtos: ${publicProducts.length} publicos / ${existingProductIds.length} existentes / ${catalog.productIds.length} vinculados`);
  if (missingProductIds.length) {
    console.log(`  produtos ausentes: ${missingProductIds.join(', ')}`);
  }
  if (inactiveProductIds.length) {
    console.log(`  produtos inativos ignorados no snapshot: ${inactiveProductIds.join(', ')}`);
  }
  if (!args.whatsapp) {
    console.log('  aviso: whatsapp vazio no snapshot. Use --whatsapp 55...');
  }
  console.log(`  snapshot: ${snapshotPath}`);
  console.log(`  link: ${link}`);

  if (!args.apply) return { changed: false, link };

  await tenantRef.collection('catalogs').doc(catalog.id).set(catalog, { merge: true });
  if (mirrorRoot) {
    await catalogDoc.ref.set(catalog, { merge: true });
  }
  await bucket.file(snapshotPath).save(JSON.stringify(snapshot, null, 2), {
    resumable: false,
    metadata: {
      contentType: 'application/json; charset=utf-8',
      cacheControl: 'public, max-age=60',
      metadata: {
        shareCode: catalog.shareCode,
        tenantId,
      },
    },
  });

  return { changed: true, link };
}

async function processRootCatalogs({ args, db, bucket }) {
  if (args.tenantOnly) return [];

  const rootCatalogDocs = await loadRootCatalogDocs(db, args.catalog);
  const links = [];

  for (const catalogDoc of rootCatalogDocs) {
    const raw = catalogDoc.data() || {};
    const tenantId = String(raw.tenantId || args.tenant || '').trim();
    if (!tenantId) {
      console.log(`\nCatalogo raiz ignorado sem tenantId: ${catalogDoc.id}`);
      continue;
    }
    if (args.tenant && tenantId !== args.tenant) continue;

    const tenantRef = db.collection('tenants').doc(tenantId);
    const [productsById, categoriesById] = await Promise.all([
      loadTenantProducts(tenantRef),
      loadTenantCategories(tenantRef),
    ]);

    const result = await processCatalog({
      args,
      bucket,
      tenantRef,
      tenantId,
      catalogDoc,
      sourcePath: catalogDoc.ref.path,
      mirrorRoot: true,
      productsById,
      categoriesById,
    });
    links.push(result.link);
  }

  return links;
}

async function processTenantCatalogs({ args, db, bucket }) {
  if (args.rootOnly) return [];

  const tenants = await loadTenants(db, args.tenant);

  if (!tenants.length) {
    console.log('Nenhum tenant encontrado para os filtros informados.');
    return [];
  }

  const links = [];
  for (const tenantDoc of tenants) {
    const tenantId = tenantDoc.id;
    const tenantRef = db.collection('tenants').doc(tenantId);
    const catalogDocs = await loadCatalogDocs(tenantRef, args.catalog);
    if (!catalogDocs.length) continue;

    const [productsById, categoriesById] = await Promise.all([
      loadTenantProducts(tenantRef),
      loadTenantCategories(tenantRef),
    ]);

    for (const catalogDoc of catalogDocs) {
      const result = await processCatalog({
        args,
        bucket,
        tenantRef,
        tenantId,
        catalogDoc,
        sourcePath: catalogDoc.ref.path,
        mirrorRoot: false,
        productsById,
        categoriesById,
      });
      links.push(result.link);
    }
  }

  return links;
}

async function main() {
  const args = parseArgs(process.argv);
  initFirebase(args);

  const db = admin.firestore();
  const bucket = admin.storage().bucket(args.bucket);

  console.log(args.apply ? 'Modo escrita: aplicando correcoes.' : 'Modo simulacao: nada sera gravado. Use --apply para publicar.');
  console.log(`Projeto: ${args.project}`);
  console.log(`Bucket: ${args.bucket}`);

  const rootLinks = await processRootCatalogs({ args, db, bucket });
  const tenantLinks = await processTenantCatalogs({ args, db, bucket });
  const links = [...rootLinks, ...tenantLinks];

  console.log(`\nConcluido. Catalogos processados: ${links.length}`);
  if (!args.apply) {
    console.log('Nenhuma alteracao foi gravada porque --apply nao foi usado.');
  }
}

main().catch((error) => {
  console.error('\nFalha ao publicar catalogos:', error);
  process.exitCode = 1;
});

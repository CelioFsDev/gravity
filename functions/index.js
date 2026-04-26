const admin = require('firebase-admin');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { auth: authFunctions, logger } = require('firebase-functions');

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();
const SUPER_ADMIN_EMAILS = new Set([
  'ti.vitoriana@gmail.com',
  'celiofs.dev@gmail.com',
  'celio@gmail.com',
  'celioferreira.dev@gmail.com',
]);
const VALID_ROLES = new Set(['admin', 'operator', 'seller', 'viewer']);

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function escapeHtml(value) {
  return String(value || '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function normalizePreviewImage(rawImage, origin) {
  const fallback = `${origin}/icons/Icon-512.png`;
  const image = String(rawImage || '').trim();
  if (!image) return fallback;

  try {
    const parsed = new URL(image, origin);
    if (parsed.protocol === 'http:' || parsed.protocol === 'https:') {
      return parsed.toString();
    }
  } catch (error) {
    logger.warn('Imagem de preview invalida recebida no share', { image, error });
  }

  return fallback;
}

exports.catalogSharePreview = onRequest(
  {
    cors: true,
    maxInstances: 10,
  },
  async (req, res) => {
    const origin = `${req.protocol}://${req.get('host')}`;
    const pathSegments = String(req.path || '')
      .split('/')
      .filter(Boolean);
    const shareCode = decodeURIComponent(pathSegments[pathSegments.length - 1] || '')
      .trim()
      .toLowerCase();

    if (!shareCode) {
      res.status(400).send('Catalog share code is required.');
      return;
    }

    const title = escapeHtml(req.query.title || 'CatalogoJa');
    const description = escapeHtml(
      req.query.description || 'Confira nosso catalogo digital.',
    );
    const imageUrl = escapeHtml(normalizePreviewImage(req.query.image, origin));
    const canonicalUrl = `${origin}/c/${encodeURIComponent(shareCode)}`;
    const escapedCanonicalUrl = escapeHtml(canonicalUrl);
    const appTitle = title || 'CatalogoJa';

    res.set('Cache-Control', 'public, max-age=300, s-maxage=300');
    res.set('Content-Type', 'text/html; charset=utf-8');
    res.status(200).send(`<!DOCTYPE html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8">
    <title>${appTitle}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="${description}">
    <meta property="og:type" content="website">
    <meta property="og:title" content="${appTitle}">
    <meta property="og:description" content="${description}">
    <meta property="og:image" content="${imageUrl}">
    <meta property="og:url" content="${escapedCanonicalUrl}">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="${appTitle}">
    <meta name="twitter:description" content="${description}">
    <meta name="twitter:image" content="${imageUrl}">
    <link rel="canonical" href="${escapedCanonicalUrl}">
    <meta http-equiv="refresh" content="0;url=${escapedCanonicalUrl}">
    <script>
      window.location.replace(${JSON.stringify(canonicalUrl)});
    </script>
  </head>
  <body>
    <p>Abrindo catalogo...</p>
  </body>
</html>`);
  },
);

async function ensureAdmin(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Login obrigatorio.');
  }

  const requesterEmail = normalizeEmail(request.auth.token.email);
  if (!requesterEmail) {
    throw new HttpsError('unauthenticated', 'Email do usuario nao encontrado no token.');
  }

  let isAuthorized = SUPER_ADMIN_EMAILS.has(requesterEmail);
  
  if (!isAuthorized) {
    logger.warn('Acesso negado ao Gerenciamento de Usuarios para ' + requesterEmail);
    throw new HttpsError(
      'permission-denied',
      'Apenas administradores gerais (Super Admin) podem gerenciar usuarios.',
    );
  }

  return requesterEmail;
}

function roleForAccess(data, tenantId, storeId) {
  const rolesByStore = data.rolesByStore || {};
  const tenantStores = rolesByStore[tenantId] || {};
  if (storeId && tenantStores[storeId]) return tenantStores[storeId];

  const rolesByTenant = data.rolesByTenant || {};
  if (tenantId && rolesByTenant[tenantId]) return rolesByTenant[tenantId];

  return data.role || 'viewer';
}

async function ensureTenantAdmin(request, tenantId, storeId) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Login obrigatorio.');
  }

  const requesterEmail = normalizeEmail(request.auth.token.email);
  if (!requesterEmail) {
    throw new HttpsError('unauthenticated', 'Email do usuario nao encontrado no token.');
  }

  if (SUPER_ADMIN_EMAILS.has(requesterEmail)) return requesterEmail;

  if (!tenantId) {
    throw new HttpsError('invalid-argument', 'Empresa obrigatoria para gerenciar usuarios.');
  }

  const requesterDoc = await db.collection('users').doc(requesterEmail).get();
  const requesterData = requesterDoc.data() || {};
  const requesterRole = roleForAccess(requesterData, tenantId, storeId);
  const tenantDoc = await db.collection('tenants').doc(tenantId).get();
  const tenantData = tenantDoc.data() || {};
  const ownerEmail = normalizeEmail(tenantData?.metadata?.ownerEmail);

  if (requesterRole === 'admin' || requesterEmail === ownerEmail) {
    return requesterEmail;
  }

  logger.warn('Acesso negado ao gerenciamento de usuarios do tenant', {
    requesterEmail,
    tenantId,
    storeId,
    requesterRole,
  });
  throw new HttpsError(
    'permission-denied',
    'Apenas administradores desta empresa podem gerenciar usuarios.',
  );
}

exports.syncAuthUsers = onCall(
  {
    cors: true,
    maxInstances: 5,
  },
  async (request) => {
    const requesterEmail = await ensureAdmin(request);

    let nextPageToken;
    let processed = 0;
    let created = 0;
    let updated = 0;
    let skipped = 0;

    do {
      const page = await auth.listUsers(1000, nextPageToken);

      for (const userRecord of page.users) {
        const email = normalizeEmail(userRecord.email);
        if (!email) {
          skipped += 1;
          continue;
        }

        const docRef = db.collection('users').doc(email);
        const snapshot = await docRef.get();
        const existingData = snapshot.data() || {};
        const role =
          typeof existingData.role === 'string' && existingData.role
            ? existingData.role
            : SUPER_ADMIN_EMAILS.has(email)
              ? 'admin'
              : 'viewer';

        const payload = {
          authUid: userRecord.uid,
          disabled: !!userRecord.disabled,
          email,
          displayName: userRecord.displayName || '',
          photoURL: userRecord.photoURL || '',
          lastRefreshAt: admin.firestore.FieldValue.serverTimestamp(),
          providerIds: (userRecord.providerData || [])
            .map((provider) => provider.providerId)
            .filter(Boolean),
          role,
        };

        if (userRecord.metadata.lastSignInTime) {
          payload.lastSignInAt = admin.firestore.Timestamp.fromDate(
            new Date(userRecord.metadata.lastSignInTime),
          );
        }

        if (userRecord.metadata.creationTime) {
          payload.createdAt = snapshot.exists && existingData.createdAt
            ? existingData.createdAt
            : admin.firestore.Timestamp.fromDate(
              new Date(userRecord.metadata.creationTime),
            );
        }

        await docRef.set(payload, { merge: true });

        if (snapshot.exists) {
          updated += 1;
        } else {
          created += 1;
        }
        processed += 1;
      }

      nextPageToken = page.pageToken;
    } while (nextPageToken);

    logger.info('Usuarios sincronizados com sucesso', {
      created,
      processed,
      requesterEmail,
      skipped,
      updated,
    });

    return {
      created,
      processed,
      skipped,
      updated,
    };
  },
);

exports.createEmailPasswordUser = onCall(
  {
    cors: true,
    maxInstances: 5,
  },
  async (request) => {
    const email = normalizeEmail(request.data?.email);
    const password = String(request.data?.password || '').trim();
    const requestedRole = String(request.data?.role || 'viewer').trim();
    const role = VALID_ROLES.has(requestedRole) ? requestedRole : 'viewer';
    const tenantId = String(request.data?.tenantId || '').trim();
    const storeId = String(request.data?.storeId || '').trim();
    const requesterEmail = await ensureTenantAdmin(request, tenantId, storeId);

    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'Email invalido.');
    }

    if (password.length < 6) {
      throw new HttpsError(
        'invalid-argument',
        'A senha deve ter pelo menos 6 caracteres.',
      );
    }

    let userRecord;
    try {
      userRecord = await auth.getUserByEmail(email);
      throw new HttpsError(
        'already-exists',
        'Ja existe um usuario autenticavel com esse email.',
      );
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      if (error?.code !== 'auth/user-not-found') {
        throw new HttpsError('internal', 'Falha ao verificar usuario.');
      }
    }

    try {
      userRecord = await auth.createUser({
        email,
        emailVerified: false,
        password,
      });
    } catch (error) {
      logger.error('Falha ao criar usuario com email e senha', error);
      throw new HttpsError('internal', 'Falha ao criar usuario no Auth.');
    }

    await db.collection('users').doc(email).set(
      {
        authUid: userRecord.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: requesterEmail,
        disabled: false,
        email,
        displayName: '',
        photoURL: '',
        lastRefreshAt: admin.firestore.FieldValue.serverTimestamp(),
        providerIds: ['password'],
        role,
        ...(tenantId ? {
          tenantId,
          tenantIds: admin.firestore.FieldValue.arrayUnion(tenantId),
          [`rolesByTenant.${tenantId}`]: storeId ? 'seller' : role,
        } : {}),
        ...(tenantId && storeId ? {
          currentStoreId: storeId,
          [`rolesByStore.${tenantId}.${storeId}`]: role,
        } : {}),
      },
      { merge: true },
    );

    logger.info('Usuario criado com email e senha', {
      createdBy: requesterEmail,
      email,
      role,
      uid: userRecord.uid,
    });

    return {
      email,
      role,
      uid: userRecord.uid,
    };
  },
);

exports.updateUserAccess = onCall(
  {
    cors: true,
    maxInstances: 5,
  },
  async (request) => {
    const email = normalizeEmail(request.data?.email);
    const requestedRole = String(request.data?.role || 'viewer').trim();
    const role = VALID_ROLES.has(requestedRole) ? requestedRole : 'viewer';
    const disabled = !!request.data?.disabled;
    const displayName = String(request.data?.displayName || '').trim();
    const tenantId = String(request.data?.tenantId || '').trim();
    const storeId = String(request.data?.storeId || '').trim();
    const requesterEmail = await ensureTenantAdmin(request, tenantId, storeId);

    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'Email invalido.');
    }

    if (SUPER_ADMIN_EMAILS.has(email) && role !== 'admin') {
      throw new HttpsError(
        'failed-precondition',
        'Nao e permitido rebaixar um super administrador.',
      );
    }

    if (tenantId && !SUPER_ADMIN_EMAILS.has(requesterEmail)) {
      const targetDoc = await db.collection('users').doc(email).get();
      const targetData = targetDoc.data() || {};
      const tenantIds = targetData.tenantIds || [];
      if (targetData.tenantId !== tenantId && !tenantIds.includes(tenantId)) {
        throw new HttpsError(
          'permission-denied',
          'Usuario nao pertence a esta empresa.',
        );
      }
      if (storeId && targetData.currentStoreId !== storeId) {
        throw new HttpsError(
          'permission-denied',
          'Usuario nao pertence a esta loja.',
        );
      }
    }

    let userRecord;
    try {
      userRecord = await auth.getUserByEmail(email);
    } catch (error) {
      if (error?.code === 'auth/user-not-found') {
        throw new HttpsError('not-found', 'Usuario nao encontrado no Auth.');
      }
      throw new HttpsError('internal', 'Falha ao localizar usuario no Auth.');
    }

    await auth.updateUser(userRecord.uid, {
      disabled,
      displayName: displayName || undefined,
    });

    await db.collection('users').doc(email).set(
      {
        authUid: userRecord.uid,
        disabled,
        displayName,
        email,
        lastRefreshAt: admin.firestore.FieldValue.serverTimestamp(),
        providerIds: (userRecord.providerData || [])
          .map((provider) => provider.providerId)
          .filter(Boolean),
        role,
        ...(tenantId ? {
          tenantId,
          tenantIds: admin.firestore.FieldValue.arrayUnion(tenantId),
          [`rolesByTenant.${tenantId}`]: storeId ? 'seller' : role,
        } : {}),
        ...(tenantId && storeId ? {
          currentStoreId: storeId,
          [`rolesByStore.${tenantId}.${storeId}`]: role,
        } : {}),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: requesterEmail,
      },
      { merge: true },
    );

    logger.info('Usuario atualizado', {
      email,
      disabled,
      role,
      updatedBy: requesterEmail,
    });

    return { email, role, disabled };
  },
);

exports.deleteUserAccount = onCall(
  {
    cors: true,
    maxInstances: 5,
  },
  async (request) => {
    const tenantId = String(request.data?.tenantId || '').trim();
    const storeId = String(request.data?.storeId || '').trim();
    const requesterEmail = await ensureTenantAdmin(request, tenantId, storeId);
    const email = normalizeEmail(request.data?.email);

    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'Email invalido.');
    }

    if (email === requesterEmail) {
      throw new HttpsError(
        'failed-precondition',
        'Nao e permitido excluir o proprio usuario.',
      );
    }

    if (SUPER_ADMIN_EMAILS.has(email)) {
      throw new HttpsError(
        'failed-precondition',
        'Nao e permitido excluir um super administrador.',
      );
    }

    if (tenantId && !SUPER_ADMIN_EMAILS.has(requesterEmail)) {
      const targetDoc = await db.collection('users').doc(email).get();
      const targetData = targetDoc.data() || {};
      const tenantIds = targetData.tenantIds || [];
      if (targetData.tenantId !== tenantId && !tenantIds.includes(tenantId)) {
        throw new HttpsError(
          'permission-denied',
          'Usuario nao pertence a esta empresa.',
        );
      }
    }

    try {
      const userRecord = await auth.getUserByEmail(email);
      await auth.deleteUser(userRecord.uid);
    } catch (error) {
      if (error?.code !== 'auth/user-not-found') {
        throw new HttpsError('internal', 'Falha ao excluir usuario no Auth.');
      }
    }

    await db.collection('users').doc(email).delete();

    logger.info('Usuario excluido', {
      email,
      deletedBy: requesterEmail,
    });

    return { email };
  },
);

exports.onUserCreated = authFunctions.user().onCreate(async (user) => {
  const email = normalizeEmail(user.email);
  if (!email) return null;

  const docRef = db.collection('users').doc(email);
  const snapshot = await docRef.get();

  if (snapshot.exists) {
    logger.info('Documento de usuario ja existe no Firestore', { email });
    return null;
  }

  const role = SUPER_ADMIN_EMAILS.has(email) ? 'admin' : 'viewer';

  const payload = {
    authUid: user.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    disabled: !!user.disabled,
    displayName: user.displayName || '',
    email,
    lastRefreshAt: admin.firestore.FieldValue.serverTimestamp(),
    photoURL: user.photoURL || '',
    providerIds: (user.providerData || [])
      .map((provider) => provider.providerId)
      .filter(Boolean),
    role,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    await docRef.set(payload);
    logger.info('Perfil de usuario criado automaticamente via trigger', { email, role });
  } catch (error) {
    logger.error('Erro ao criar perfil de usuario automaticamente', { email, error });
  }

  return null;
});

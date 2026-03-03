const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();
const SUPER_ADMIN_EMAILS = new Set(['ti.vitoriana@gmail.com']);
const VALID_ROLES = new Set(['admin', 'operator', 'seller', 'viewer']);

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

exports.syncAuthUsers = onCall(
  {
    cors: true,
    maxInstances: 5,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login obrigatorio.');
    }

    const requesterEmail = normalizeEmail(request.auth.token.email);
    if (!SUPER_ADMIN_EMAILS.has(requesterEmail)) {
      throw new HttpsError(
        'permission-denied',
        'Apenas o administrador geral pode sincronizar usuarios.',
      );
    }

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
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Login obrigatorio.');
    }

    const requesterEmail = normalizeEmail(request.auth.token.email);
    if (!SUPER_ADMIN_EMAILS.has(requesterEmail)) {
      throw new HttpsError(
        'permission-denied',
        'Apenas o administrador geral pode cadastrar usuarios.',
      );
    }

    const email = normalizeEmail(request.data?.email);
    const password = String(request.data?.password || '').trim();
    const requestedRole = String(request.data?.role || 'viewer').trim();
    const role = VALID_ROLES.has(requestedRole) ? requestedRole : 'viewer';

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
        lastRefreshAt: admin.firestore.FieldValue.serverTimestamp(),
        providerIds: ['password'],
        role,
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

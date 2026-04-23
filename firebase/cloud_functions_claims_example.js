// Este é um exemplo de Backend (Cloud Functions Node.js) que você deverá implementar
// para injetar o "tenantId" e "role" de forma infalsificável no token JWT do Firebase Auth.

const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * Função executada ao criar um Tenant ou adicionar um membro.
 * Somente um Admin ou um serviço Backend confiável pode chamar esta função.
 */
exports.setTenantClaims = functions.https.onCall(async (data, context) => {
  // 1. Verificações de segurança no Backend (Quem está chamando tem permissão?)
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Acesso negado");
  }

  // Obter e validar dados (Ex: o e-mail do funcionário convidado e o tenant atual)
  const targetUserEmail = data.email;
  const tenantId = data.tenantId; // Idealmente pegamos do request.auth.token.tenantId
  const role = data.role || 'seller'; // 'admin' ou 'seller'

  try {
    // 2. Busca o usuário no Firebase Auth
    const user = await admin.auth().getUserByEmail(targetUserEmail);

    // 3. INJEÇÃO DO CUSTOM CLAIM (A Máscara de Ferro do Multi-Tenant)
    // A partir de agora, o Firebase Auth embutirá esse JSON dentro do token JWT do usuário.
    await admin.auth().setCustomUserClaims(user.uid, {
      tenantId: tenantId,
      role: role
    });

    return { 
        success: true, 
        message: `Claims definidos com sucesso para ${targetUserEmail}. O usuário precisará fazer relogin.` 
    };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

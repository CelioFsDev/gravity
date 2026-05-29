# ⚖️ Conformidade & Legal - Guia Completo

## 📋 RESUMO

Para publicar nas lojas, você **DEVE** cumprir requisitos legais e de conformidade:
- ✅ Política de Privacidade (URL pública)
- ✅ Termos de Serviço (URL pública)
- ✅ Direito de exclusão de conta
- ✅ GDPR compliance (se aplicável)
- ✅ Política de reembolso
- ✅ Classificação etária apropriada
- ✅ Nenhuma conteúdo ilegal/prejudicial

---

## 🌍 GDPR - Se você tem usuários na EU

### O que é GDPR?
**General Data Protection Regulation** - Lei europeia sobre proteção de dados pessoais.

Se seu app será usado por pessoas na Europa, você **DEVE** cumprir:

### Obrigações GDPR

1. **Consentimento Explícito**
```
Antes de coletar dados, solicitar consentimento.
Seu app coleta:
- Email
- Nome
- Telefone/WhatsApp
- Dados de pedidos
- Histórico de vendas

Você deve ter consentimento do usuário.
```

2. **Direito de Acesso**
```
Usuário pode pedir: "Quais dados você tem sobre mim?"
Você deve fornecer em formato legível (PDF, JSON, etc).
```

3. **Direito de Retificação**
```
Usuário pode pedir: "Corrija meus dados"
Seu app deve permitir editar nome, email, telefone.
```

4. **Direito ao Esquecimento ("Right to be Forgotten")**
```
Usuário pode pedir: "Delete todos meus dados"
Você DEVE deletar:
- Conta de usuário
- Pedidos associados
- Produtos do usuário
- Catálogos do usuário
- Todas as informações pessoais

❌ NÃO deletar: registros legais/financeiros (6 anos)
```

5. **Portabilidade de Dados**
```
Usuário pode pedir: "Quero meus dados em outro app"
Você deve fornecer dados em formato exportável (JSON, CSV).
```

### Implementação em seu App

**Você já tem:** Tela em `/features/legal/legal_documents_screen.dart` com opção de "Exclusão de Conta".

**Você precisa adicionar:**

```dart
// Em sua SettingsScreen ou novo endpoint

// 1. Botão "Download meus dados"
FilledButton(
  onPressed: _downloadMyData,
  label: Text('Baixar Meus Dados (GDPR)'),
)

// 2. Função de export
Future<void> _downloadMyData() async {
  final userData = {
    'email': currentUser.email,
    'name': currentUser.name,
    'createdAt': currentUser.createdAt,
    'products': products.toList(),
    'orders': orders.toList(),
    'catalogs': catalogs.toList(),
  };
  
  // Exportar como JSON
  final json = jsonEncode(userData);
  // Enviar por email ou salvar
}

// 3. Botão "Deletar minha conta e dados"
// (você já tem isto)
```

---

## 🏪 GOOGLE PLAY STORE - Requisitos Específicos

### 1. Política de Privacidade

**Obrigatório:** URL pública HTTPS

```
https://catalogoja.app/privacy

Deve incluir:
- Quais dados são coletados
- Como são usados
- Quanto tempo são armazenados
- Com quem são compartilhados
- Direitos do usuário
```

**Você tem:** Template em `legal_documents_screen.dart`

**Próximo passo:** 
1. Publicar em https://catalogoja.app/privacy
2. Adicionar ao Play Store Console

### 2. Permissões Solicitadas

**Sua app solicita:**
```
✅ INTERNET - Comunicar com Firebase
✅ CAMERA - Adicionar fotos de produtos
✅ READ_EXTERNAL_STORAGE - Carregar imagens
✅ READ_MEDIA_IMAGES - Android 13+
✅ WRITE_EXTERNAL_STORAGE - Salvar PDFs
```

**Validação:** Google Play verifica se todas as permissões são **necessárias e justificadas**.

**Seu caso é OK:** Todas são genuinamente usadas.

### 3. Política de Reembolso

```
Google Play exige que você tenha política clara.

Se você VENDER algo no app:
- Defina prazo de reembolso (ex: 7 dias, 15 dias)
- Explique processo
- Forneça contato para reembolso

Seu app atual:
- NÃO faz pagamento direto (usa WhatsApp/PIX)
- Você pode declarar: "Sem pagamento no app"

Ainda assim, adicione em Privacy Policy:
"Este app não processa pagamentos. Todos os pagamentos 
são feitos via WhatsApp, PIX ou meio de pagamento escolhido 
pela loja. Política de reembolso é responsabilidade da loja."
```

### 4. Content Rating

Você deve responder questionário:

```
Google Play exigirá:

[ ] Conteúdo violento?      → NÃO
[ ] Linguagem explícita?    → NÃO
[ ] Conteúdo sexual?        → NÃO
[ ] Álcool/Drogas?          → NÃO
[ ] Gambling?               → NÃO
[ ] Dados pessoais coletados? → SIM
    (Email, telefone, dados de pedidos)

Rating esperado: 3+ ou 4+
```

---

## 🍎 APP STORE - Requisitos Específicos

### 1. Política de Privacidade (OBRIGATÓRIO)

```
Apple EXIGE que você tenha:
- URL pública de Privacy Policy
- Informações sobre coleta de dados
- Como dados são usados
- Conformidade com GDPR (se aplicável)

URL: https://catalogoja.app/privacy
```

### 2. Termos de Serviço (RECOMENDADO, pode ser OBRIGATÓRIO)

```
Apple frequentemente exige:

URL: https://catalogoja.app/terms

Deve incluir:
- Responsabilidades do usuário
- Limitações de responsabilidade
- Conformidade com leis
- Proibições (spam, conteúdo ilegal, etc)
```

### 3. Direito de Conta de Exclusão

```
❌ NÃO PERMITIR:
- Contas que não podem ser deletadas
- Dados que não podem ser removidos

✅ VOCÊ TEM:
- Tela de exclusão de conta
- Conexão com backend para deletar dados

Apple verifica se funciona. Teste antes de submeter!
```

### 4. App Tracking Transparency (ATT)

```
Se você usar analytics com tracking:
- Mostrar prompt pedindo permissão
- Seu app USA: Firebase Analytics (padrão)

Firebase é considerado "essential analytics" - 
você pode solicitar permissão ou operar sem.

Recomendação: Não pedir ATT (analytics é essencial).
```

---

## 📝 TEMPLATES - DOCUMENTOS QUE VOCÊ PRECISA

### 1. Privacy Policy Template

```markdown
# Política de Privacidade

**CatalogoJa - CATÁLOGO JÁ LTDA**
CNPJ: 59.960.562/0001-20
Última atualização: 28 de maio de 2026

## 1. Informações que Coletamos

Podemos coletar:
- Nome, email, telefone/WhatsApp
- Dados de empresas/lojas
- Informações de produtos
- Histórico de pedidos
- Dados de uso do app

## 2. Como Usamos Seus Dados

Para:
- Criar e manter sua conta
- Gerenciar produtos e pedidos
- Enviar notificações
- Melhorar o serviço
- Cumprir obrigações legais

## 3. Compartilhamento de Dados

Podemos compartilhar com:
- Firebase (armazenamento em nuvem)
- Fornecedores de hosting
- Quando obrigado por lei

## 4. Segurança

Usamos encriptação e medidas de segurança.

## 5. Seus Direitos (GDPR)

Você pode:
- Acessar seus dados
- Corrigir dados
- Deletar sua conta
- Exportar seus dados
- Revogar consentimento

## 6. Contato

Email: celioferreira.dev@gmail.com
WhatsApp: (62) 9 9906-1707
```

### 2. Terms of Service Template

```markdown
# Termos de Serviço

**CatalogoJa**
CNPJ: 59.960.562/0001-20
Data: 28 de maio de 2026

## 1. Aceitação dos Termos

Ao usar este app, você aceita estes termos.

## 2. Licença de Uso

Concedemos licença não-exclusiva para uso pessoal/comercial.

## 3. Responsabilidades do Usuário

Você concorda em:
- Usar o app legalmente
- Não copiar ou vender o app
- Não compartilhar credenciais
- Respeitar direitos de terceiros
- Cumprir leis aplicáveis

## 4. Proibições

Você NÃO pode:
- Usar para spam ou phishing
- Publicar conteúdo ilegal
- Burlar segurança
- Revender dados coletados
- Impersonar outras pessoas

## 5. Limitação de Responsabilidade

O app é fornecido "como está". Não garantimos:
- Funcionamento ininterrupto
- Ausência de erros
- Recuperação de dados perdidos

## 6. Modificações

Podemos modificar estes termos. Continuando a usar,
você aceita as mudanças.

## 7. Rescisão

Podemos encerrar sua conta se violarmos estes termos.

## 8. Lei Aplicável

Estes termos são regidos pela lei brasileira.

## 9. Contato

celioferreira.dev@gmail.com
```

### 3. Data Deletion Request Form

```
Você já tem em:
/features/legal/legal_documents_screen.dart

Mas você também precisa de:
- Email para receber solicitações de deleção
- Processo documentado
- Confirmação de deleção
```

---

## 🚀 CHECKLIST DE CONFORMIDADE

### Documentos & Políticas
- [ ] Privacy Policy criada (URL pública)
- [ ] Terms of Service criada (URL pública)
- [ ] Data Deletion Process documentado
- [ ] Email de contato configurado
- [ ] CNPJ incluído em ambos

### Seu App
- [ ] Tela de Privacy Policy funcionando
- [ ] Tela de Terms of Service funcionando
- [ ] Botão de exclusão de conta funcionando
- [ ] Verificado: exclusão deleta dados do Firebase
- [ ] Sem dados sensíveis em armazenamento local (Hive)

### GDPR (Se aplicável)
- [ ] Consentimento solicitado antes de coletar dados
- [ ] Direito de acesso implementado
- [ ] Direito de retificação implementado
- [ ] Direito de exclusão implementado
- [ ] Direito de portabilidade documentado

### Google Play Store
- [ ] Privacy Policy URL no console
- [ ] Content Rating completado
- [ ] Nenhuma permissão desnecessária
- [ ] Reembolso policy documentada
- [ ] Sem conteúdo proibido

### Apple App Store
- [ ] Privacy Policy URL configurada
- [ ] Terms of Service URL configurada
- [ ] Exclusão de conta testada
- [ ] Nenhuma coleta de dados undisclosed
- [ ] Sem APIs privadas usadas
- [ ] Sem conteúdo ofensivo

---

## ⚠️ ERROS COMUNS QUE CAUSAM REJEIÇÃO

### Google Play Store
```
❌ "Nenhuma Privacy Policy"
   → Adicione URL pública obrigatória

❌ "Permissões não justificadas"
   → Seu app está OK, todas usadas

❌ "Solicita dados bancários sem segurança"
   → Seu app não faz isto, está seguro

❌ "Conteúdo adulto não classificado"
   → Seu app é shopping, classificar como 3+
```

### Apple App Store
```
❌ "Nenhuma Privacy Policy"
   → Rejeição automática

❌ "Exclusão de conta não funciona"
   → Você deve testar antes de submeter

❌ "Tracking sem consentimento"
   → Firebase é OK, não pedir extra

❌ "Não cumpre LGPD/GDPR"
   → Incluir direitos de acesso/deleção
```

---

## 🔗 PRÓXIMOS PASSOS

### Imediatos
1. ✅ Publicar Privacy Policy em https://catalogoja.app/privacy
2. ✅ Publicar Terms of Service em https://catalogoja.app/terms
3. ✅ Testar botão de exclusão de conta
4. ✅ Adicionar URLs ao play store/app store

### Antes de Submeter
5. ✅ Verificar Privacy Policy é acessível
6. ✅ Verificar Terms of Service é acessível
7. ✅ Testar deleção de conta (verifica Firebase)
8. ✅ Completar Content Rating
9. ✅ Descrever coleta de dados

### Deploy
10. ✅ Incluir URLs no app store/play store
11. ✅ Submeter para review
12. ✅ Responder feedback se houver

---

## 📚 REFERÊNCIAS

- GDPR: https://gdpr-info.eu/
- LGPD (lei brasileira): http://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm
- Google Play Policy: https://play.google.com/about/developer-content-policy/
- Apple App Store Policy: https://developer.apple.com/app-store/review/guidelines/
- Privacy by Design: https://ico.org.uk/for-organisations/data-protection-by-design-and-default/

---

## 🎯 CONCLUSÃO

Sua app é um **e-commerce de catálogos**, não um social network ou jogo.

**Conformidade esperada: ALTA** ✅

Você está colhendo dados pessoais (email, telefone, pedidos), então:
1. Privacy policy robusta
2. Segurança de dados rigorosa
3. Direitos do usuário garantidos
4. Transparência total

Com estes documentos em lugar e funcionalidade de deleção testada,
você está **pronto para publicação** nas lojas! 🚀

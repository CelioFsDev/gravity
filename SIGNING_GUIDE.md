# 🔐 Certificados e Assinatura - Guia Completo

## 📋 RESUMO

Para publicar seu app nas lojas, você precisa:
- **Android**: Gerar/ter um Upload Key Certificate (arquivo `.jks`)
- **iOS**: Ter conta de desenvolvedor Apple + Certificados + Provisioning Profiles

---

## 🤖 ANDROID - GOOGLE PLAY STORE

### PASSO 1: Gerar a Chave de Upload (Upload Key)

Se ainda não tem uma chave, execute este comando PowerShell:

```powershell
# Criar keystore para upload
# Execute isso no PowerShell (como administrador)

$keystorePath = "C:\Users\celio\catalogo_ja_upload_key.jks"
$password = "SUA_SENHA_FORTE_AQUI"  # Escolha uma senha forte!
$alias = "upload"
$keyPassword = "SUA_SENHA_FORTE_AQUI"  # Pode ser a mesma

# Comando para gerar:
keytool -genkey -v -keystore $keystorePath `
  -keyalg RSA `
  -keysize 4096 `
  -validity 10950 `
  -alias $alias `
  -keypass $keyPassword `
  -storepass $password `
  -dname "CN=Celio Ferreira, OU=Development, O=Catalogo Ja, L=Goiânia, S=GO, C=BR"
```

**O que cada parâmetro significa:**
- `-keystore`: Caminho onde a chave será salva
- `-keyalg`: Algoritmo (use RSA)
- `-keysize`: Tamanho da chave (4096 é recomendado)
- `-validity`: Dias de validade (10950 = ~30 anos)
- `-alias`: Nome da chave (use "upload")
- `-dname`: Seus dados pessoais (CN=name, O=company, etc)

**Exemplo preenchido:**
```powershell
keytool -genkey -v -keystore "C:\Users\celio\catalogo_ja_upload_key.jks" `
  -keyalg RSA `
  -keysize 4096 `
  -validity 10950 `
  -alias upload `
  -keypass SenhaForteDaChave123! `
  -storepass SenhaForteDaKeystore123! `
  -dname "CN=Celio Ferreira, OU=Development, O=Catalogo Ja LTDA, L=Goianesia, S=GO, C=BR"
```

### PASSO 2: Configurar key.properties

Crie ou atualize `android/key.properties`:

```properties
storePassword=SenhaForteDaKeystore123!
keyPassword=SenhaForteDaChave123!
keyAlias=upload
storeFile=C:\\Users\\celio\\catalogo_ja_upload_key.jks
```

**⚠️ IMPORTANTE:**
- Não commitar este arquivo no Git (já está em `.gitignore`?)
- Usar barras invertidas duplas (`\\`) no Windows
- Guardar a senha em local seguro

### PASSO 3: Verificar a Chave

Para visualizar informações da chave gerada:

```powershell
keytool -list -v -keystore "C:\Users\celio\catalogo_ja_upload_key.jks" -alias upload -storepass SenhaForteDaKeystore123!
```

### PASSO 4: Build para Upload

Quando estiver pronto para enviar:

```powershell
cd f:\gravity

# Gerar AAB (recomendado para Play Store)
flutter build appbundle --release

# Ou gerar APK (alternativa)
flutter build apk --release

# Arquivo gerado estará em:
# build/app/outputs/bundle/release/app-release.aab
# ou
# build/app/outputs/apk/release/app-release.apk
```

### Verificar Assinatura

Para confirmar que o APK foi assinado corretamente:

```powershell
# Listar certificados dentro do APK
jarsigner -verify -verbose -certs "build/app/outputs/apk/release/app-release.apk"
```

---

## 🍎 iOS - APP STORE

### PASSO 1: Preparar Conta Apple Developer

1. Acesse: https://developer.apple.com
2. Faça login com sua conta Apple
3. Vá para **Certificates, Identifiers & Profiles**

### PASSO 2: Criar App ID

1. Em **Identifiers**, clique em **+**
2. Selecione **App IDs**
3. Preencha:
   - **Description**: CatalogoJa
   - **Bundle ID**: com.catalogoja.app (match o do projeto)
4. Ative as capabilities que seu app usa:
   - ✅ Push Notifications (opcional)
   - ✅ Sign in with Apple (se usar)
5. Clique **Register**

### PASSO 3: Criar Certificate

1. Em **Certificates**, clique em **+**
2. Selecione **Apple Distribution** (para App Store)
3. Escolha seu App ID criado acima
4. Siga as instruções para criar um CSR (Certificate Signing Request):
   - No Mac, use **Keychain Access** → **Certificate Assistant** → **Request a Certificate from a Certificate Authority**
   - Salve como `CertificateSigningRequest.certSigningRequest`
5. Upload do CSR e baixe o certificado `.cer`
6. Clique duplo no `.cer` para instalar no Keychain

### PASSO 4: Criar Provisioning Profile

1. Em **Profiles**, clique em **+**
2. Selecione **App Store**
3. Selecione seu **App ID** (com.catalogoja.app)
4. Selecione seu **Certificate** (o criado acima)
5. Nome: `CatalogoJa_AppStore`
6. Download e clique duplo para instalar

### PASSO 5: Configurar no Xcode

1. Abra o projeto iOS:
```powershell
cd f:\gravity
open -a Xcode ios/Runner.xcworkspace
```

2. Em Xcode:
   - Selecione **Runner** (no project navigator)
   - Aba **Build Settings**
   - Procure por **Signing**
   - Verifique:
     - **Team ID**: Sua Team Apple
     - **Bundle Identifier**: com.catalogoja.app
     - **Signing Certificate**: Automatic

3. Configurar Team:
   - Xcode → Preferences → Accounts
   - Add Apple ID
   - Download Manual Profiles

### PASSO 6: Build para App Store

```powershell
cd f:\gravity\ios

# Clean build
flutter clean

# Build para release
flutter build ios --release

# Criar archive
xcodebuild -workspace Runner.xcworkspace `
  -scheme Runner `
  -archivePath Runner.xcarchive `
  -configuration Release `
  -derivedDataPath build `
  archive

# Ou via Xcode UI:
# Product → Archive
```

### PASSO 7: Upload para App Store Connect

**Opção A: Via Xcode (mais fácil)**
1. Xcode → Window → Organizer
2. Selecione seu Archive
3. Clique **Distribute App**
4. Escolha **App Store Connect**
5. Siga as instruções

**Opção B: Via fastlane (recomendado para CI/CD)**
```powershell
# Instalar fastlane
gem install fastlane -NV

# Configurar
cd f:\gravity\ios
fastlane init

# Upload
fastlane upload_to_app_store
```

---

## ✅ CHECKLIST DE CERTIFICADOS

### Android
- [ ] Chave de upload gerada (`.jks`)
- [ ] `key.properties` configurado e preenchido
- [ ] `key.properties` em `.gitignore` (não commitar!)
- [ ] App ID: `com.catalogoja.app` em `build.gradle.kts`
- [ ] Versão aumentada em `pubspec.yaml`
- [ ] Build APK/AAB testado localmente

### iOS
- [ ] Conta Apple Developer ativa
- [ ] App ID criado em Developer Portal (com.catalogoja.app)
- [ ] Distribution Certificate criado
- [ ] App Store Provisioning Profile criado
- [ ] Xcode configurado com Team ID
- [ ] Bundle ID em `ios/Runner/Info.plist`: com.catalogoja.app
- [ ] Build para iOS testado

---

## 🚨 CUIDADOS IMPORTANTES

1. **Nunca compartilhe ou faça commit de:**
   - `android/key.properties`
   - `android/keystore.jks` (arquivo de chave)
   - Certificados ou chaves privadas iOS

2. **Guarde em local seguro:**
   - Senhas dos certificados
   - Arquivos `.jks`
   - Certificados `.cer` e `.p8` do Apple

3. **Validade dos certificados:**
   - Android: Seu certificado de upload deve ter validade de 25+ anos
   - iOS: Certificados Apple duram 1 ano (renovar anualmente)

4. **Diferença Android:**
   - App Signing Key: Usada para assinatura no desenvolvimento
   - Upload Key: Usada para fazer upload na Play Store
   - Use apenas Upload Key para loja!

---

## 🔗 LINKS ÚTEIS

- Android Play Console: https://play.google.com/console
- Apple Developer: https://developer.apple.com
- App Store Connect: https://appstoreconnect.apple.com
- Documentação Flutter Signing: https://flutter.dev/docs/deployment/android#signing-the-app

---

## 📞 PRÓXIMAS ETAPAS

1. ✅ Gerar certificado Android (executar comando keytool)
2. ✅ Preencher `android/key.properties`
3. ✅ Gerar certificados iOS (Apple Developer Portal)
4. ✅ Configurar Xcode
5. ✅ Testar builds localmente
6. ✅ Fazer upload para as lojas

Qualquer dúvida, consulte os links acima! 🚀

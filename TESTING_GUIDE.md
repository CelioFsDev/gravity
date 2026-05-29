# 🧪 Testes e Validação - Guia Completo

## 📋 RESUMO

Antes de enviar para as lojas, você **DEVE** testar:
- ✅ Build APK/AAB (Android)
- ✅ Build IPA (iOS)
- ✅ Permissões (câmera, galeria, storage)
- ✅ Autenticação Firebase
- ✅ Compartilhamento WhatsApp
- ✅ Geração de PDF
- ✅ Sincronização offline
- ✅ Firebase Crashlytics

---

## 🤖 ANDROID - TESTES

### 1️⃣ BUILD E INSTALAÇÃO

```powershell
cd f:\gravity

# Limpar build anterior
flutter clean

# Build APK para teste
flutter build apk --release

# Resultado esperado:
# build/app/outputs/apk/release/app-release.apk

# Instalar em dispositivo conectado
adb install build/app/outputs/apk/release/app-release.apk

# Ou em emulador (se estiver rodando)
flutter install build/app/outputs/apk/release/app-release.apk
```

### 2️⃣ TESTAR PERMISSÕES

**Câmera:**
```
1. Ir para Admin → Produtos
2. Tentar adicionar produto com câmera
3. Aceitar permissão de câmera
4. Tirar foto
5. Verificar se foto aparece no produto
```

**Galeria:**
```
1. Ir para Admin → Produtos
2. Tentar adicionar produto com galeria
3. Aceitar permissão de leitura
4. Selecionar imagem
5. Verificar se aparece
```

**Storage (Android 12/13):**
```
1. Compartilhar PDF
2. Salvar PDF (se houver botão de download)
3. Verificar em Downloads
```

### 3️⃣ TESTAR FIREBASE INTEGRATION

```dart
// No console do app ou usando firebase
1. Login com email/senha
2. Criar novo catálogo
3. Adicionar produtos
4. Verificar se dados sincronizam no Firestore
5. Abrir app offline
6. Verificar se dados locais aparecem
7. Voltar online
8. Validar sincronização
```

**Verificar Crashlytics:**
```powershell
# No Firebase Console:
# 1. Analytics → Dashboard
# 2. Verificar se eventos estão registrando
# 3. Crashlytics → Errors (deve estar vazio se sem crashes)
```

### 4️⃣ TESTAR COMPARTILHAMENTO

```
1. Criar catálogo
2. Clicar em "Compartilhar"
3. Selecionar "WhatsApp"
4. Aceitar compartilhamento
5. Verificar se abre WhatsApp com link
6. Testar link do catálogo (público)
7. Compartilhar PDF
8. Verificar se PDF abre corretamente
```

### 5️⃣ VALIDAÇÃO DE APK

```powershell
# Verificar assinatura
jarsigner -verify -verbose "build/app/outputs/apk/release/app-release.apk"

# Resultado esperado:
# jar verified.
# This jar contains entries whose certificate chain is not validated.
# (isto é normal, apenas confirma que foi assinado)

# Listar permissões no APK
aapt dump permissions build/app/outputs/apk/release/app-release.apk

# Listar permissões solicitadas
aapt dump badging build/app/outputs/apk/release/app-release.apk | grep permission
```

---

## 🍎 iOS - TESTES

### 1️⃣ BUILD E INSTALAÇÃO

```powershell
cd f:\gravity

# Limpar
flutter clean

# Build para iOS
flutter build ios --release

# Resultado esperado:
# build/ios/iphoneos/Runner.app

# Instalar em dispositivo via Xcode
open -a Xcode ios/Runner.xcworkspace

# Em Xcode:
# 1. Selecionar seu device no topo
# 2. Product → Run (Cmd+R)
# 3. Ou Product → Build (Cmd+B) apenas para validar
```

### 2️⃣ TESTAR NO SIMULATOR (Alternativa)

```powershell
# Listar simuladores disponíveis
xcrun simctl list devices

# Exemplo de ID: 
# iPhone 15: 6E6F6F76-7A68-4A6D-8C35-7A7A7A7A7A7A

# Build para simulator
flutter build ios --release --simulator

# Ou executar direto
flutter run -d "iPhone 15"
```

### 3️⃣ TESTAR PERMISSÕES iOS

**Câmera e Galeria:**
```
1. Instalar app no iPhone
2. Ir para Admin → Produtos
3. Tentar adicionar com câmera
4. Permitir acesso quando solicitar
5. Tirar foto
6. Verificar se aparece
```

**Verificar em Settings:**
```
Settings → Privacy → Camera → CatalogoJa (deve estar Allow)
Settings → Privacy → Photos → CatalogoJa (deve estar Allow)
```

### 4️⃣ VALIDAÇÃO DE BUILD

```powershell
# Verificar certificado de assinatura
codesign -v -v build/ios/iphoneos/Runner.app

# Resultado esperado:
# build/ios/iphoneos/Runner.app: valid on disk
# build/ios/iphoneos/Runner.app: satisfies its Designated Requirement
```

---

## 📊 TESTES FUNCIONAIS

### Checklist de Features

```
[ ] Login/Registro
    [ ] Criar conta com email/senha
    [ ] Fazer login
    [ ] Logout
    [ ] Recuperação de senha (se houver)
    [ ] Google Sign-In (se houver)

[ ] Admin - Dashboard
    [ ] KPIs carregam corretamente
    [ ] Mostra vendas do dia
    [ ] Mostra ticket médio

[ ] Admin - Produtos
    [ ] Criar produto
    [ ] Adicionar múltiplas imagens
    [ ] Editar produto
    [ ] Deletar produto
    [ ] Importar CSV
    [ ] Buscar/Filtrar produtos

[ ] Admin - Categorias
    [ ] Criar categoria
    [ ] Reordenar (drag-drop)
    [ ] Editar
    [ ] Deletar
    [ ] Verificar redistribuição automática

[ ] Admin - Catálogos
    [ ] Criar catálogo
    [ ] Adicionar produtos
    [ ] Customizar layout
    [ ] Copiar link
    [ ] Compartilhar PDF
    [ ] Compartilhar WhatsApp

[ ] Admin - Pedidos
    [ ] Receber pedido
    [ ] Ver detalhes
    [ ] Atualizar status
    [ ] Abrir WhatsApp do cliente

[ ] Admin - Vendedoras
    [ ] Adicionar vendedora
    [ ] Ativar/Desativar
    [ ] Deletar

[ ] Admin - Settings
    [ ] Mudar modo escuro
    [ ] Configurar nome da loja
    [ ] Configurar WhatsApp
    [ ] Configurar URL pública

[ ] Public - Catálogos
    [ ] Acessar link público
    [ ] Ver produtos do catálogo
    [ ] Buscar/Filtrar
    [ ] Adicionar ao carrinho
    [ ] Ajustar quantidade

[ ] Public - Checkout
    [ ] Preencher nome
    [ ] Preencher WhatsApp
    [ ] Ver total
    [ ] Enviar pedido
    [ ] Abrir WhatsApp com resumo
    [ ] Salvar pedido localmente

[ ] Offline Mode
    [ ] Desativar internet
    [ ] Navegar pelo app
    [ ] Voltar online
    [ ] Verificar sincronização
    [ ] Testar criação de dados offline
```

---

## 🐛 TESTES DE CRASH E ERRO

### 1️⃣ Firebase Crashlytics

```dart
// Para testar se Crashlytics está funcionando:
// Adicione isto temporariamente em main.dart

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... init Firebase ...
  
  // Enable Crashlytics reporting
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  
  // Teste de crash (remover depois):
  // FirebaseCrashlytics.instance.crash();
}
```

**Para testar:**
```
1. Descomenta a linha do crash()
2. Build e instala
3. Abre o app (vai crashear)
4. Aguarda 1 minuto
5. Verifica Firebase Console → Crashlytics
6. Deve aparecer o erro reportado
7. Remove a linha do crash()
```

### 2️⃣ Validar Logs

```powershell
# Ver logs de crash em tempo real
adb logcat | grep -i "flutter\|crash\|error"

# Ou salvar em arquivo
adb logcat > flutter_logs.txt

# Depois analisa
```

---

## 🌐 TESTES OFFLINE

### Scenario 1: Criar dados offline

```
1. Desativar WiFi e dados
2. Abrir app (se já logado, continua)
3. Criar novo produto offline
4. Reativar internet
5. Verificar se produto sincroniza
6. Verificar em Firebase Console se foi criado
```

### Scenario 2: Editar dados offline

```
1. Criar produto online
2. Desativar internet
3. Editar produto
4. Reativar internet
5. Verificar sincronização
```

### Scenario 3: Receber pedido offline

```
1. Abrir catálogo público em outro dispositivo
2. Desativar internet no app principal
3. Fazer checkout no outro dispositivo
4. Reativar internet
5. Verificar se pedido apareceu
```

---

## 📱 TESTES DE COMPATIBILIDADE

### Android Versions

```
Testar em (mínimo):
[ ] Android 6.0 (API 23) - Emulador
[ ] Android 8.0 (API 26) - Emulador
[ ] Android 12.0 (API 31) - Emulador
[ ] Android 14.0 (API 34) - Dispositivo real
[ ] Android 15.0 (API 35) - Se disponível
```

### iOS Versions

```
Testar em (mínimo):
[ ] iOS 13 (seu mínimo atual)
[ ] iOS 14
[ ] iOS 15+
[ ] iPhone 6s+ (teste tamanhos variados)
```

### Screen Sizes

```
Android:
[ ] Phone pequeno (4.5" - Galaxy S5)
[ ] Phone médio (5.5" - Pixel 4)
[ ] Phone grande (6.7" - Galaxy S23 Ultra)
[ ] Tablet (10" - se suportar)

iOS:
[ ] iPhone SE (pequeno)
[ ] iPhone 14 (médio)
[ ] iPhone 15 Pro Max (grande)
[ ] iPad (se suportar)
```

---

## 📊 TESTES DE PERFORMANCE

### Android

```powershell
# Verificar uso de memória
adb shell dumpsys meminfo com.catalogoja.app

# Verificar battery drain
adb shell dumpsys batterystats --reset

# Usar por 15 minutos
# Depois:
adb shell dumpsys batterystats --help
```

### Requerimentos

```
[ ] App deve iniciar em < 3 segundos
[ ] Scroll deve ser smooth (60 FPS)
[ ] Nenhum lag em operações normais
[ ] PDF generation < 5 segundos
[ ] Image compression < 2 segundos
```

---

## 🔐 TESTES DE SEGURANÇA

### Validar HTTPS

```powershell
# Verificar se URLs estão HTTPS
# Em legal_documents_screen.dart:
# websiteUrl = 'https://catalogoja.app' ✅

# Em firebaseOptions.dart:
# authDomain = 'catalogo-ja-89aae.firebaseapp.com' ✅
```

### Validar Permissões

```
[ ] Android - Verificar AndroidManifest.xml
    [ ] INTERNET ✅
    [ ] CAMERA ✅
    [ ] READ_EXTERNAL_STORAGE ✅
    [ ] WRITE_EXTERNAL_STORAGE ✅
    [ ] READ_MEDIA_IMAGES ✅

[ ] iOS - Verificar Info.plist
    [ ] NSCameraUsageDescription ✅
    [ ] NSPhotoLibraryUsageDescription ✅
```

### Validar Firebase Rules

```
[ ] Firestore Rules - Apenas usuários autenticados
[ ] Storage Rules - Apenas uploads de usuários
[ ] Sem dados sensíveis em cliente
```

---

## ✅ CHECKLIST PRÉ-PUBLICAÇÃO

### Build & Install
- [ ] `flutter clean` executado
- [ ] APK compilado sem erros
- [ ] IPA compilado sem erros
- [ ] APK assinado corretamente
- [ ] Instalação em dispositivo real bem-sucedida

### Funcionalidades
- [ ] Login/Logout funcionando
- [ ] Dashboard mostrando dados
- [ ] Produtos CRUD completo
- [ ] Categorias CRUD completo
- [ ] Catálogos funcionando
- [ ] Pedidos recebendo
- [ ] Compartilhamento WhatsApp
- [ ] PDF geração
- [ ] Modo offline funcionando

### Permissões
- [ ] Câmera solicitando permissão
- [ ] Galeria solicitando permissão
- [ ] Storage solicitando permissão
- [ ] Permissões negadas tratadas com graceful

### Firebase
- [ ] Autenticação funcionando
- [ ] Firestore sincronizando
- [ ] Storage fazendo upload
- [ ] Crashlytics reportando
- [ ] Analytics registrando eventos

### UI/UX
- [ ] Sem crashes em operações normais
- [ ] Sem lag perceptível
- [ ] Responsivo em diferentes telas
- [ ] Tema escuro funcionando
- [ ] Texts legíveis
- [ ] Buttons acessíveis

### Dados & Conformidade
- [ ] Política de Privacidade acessível
- [ ] Termos de Serviço acessíveis
- [ ] Conta deleção funcionando
- [ ] Sem dados sensíveis expostos
- [ ] HTTPS em todos os links

### App Store Requirements
- [ ] versionCode/versionName aumentados
- [ ] Descrição preenchida
- [ ] Screenshots preparados
- [ ] Categoria selecionada
- [ ] Idade mínima definida

---

## 🔗 PRÓXIMOS PASSOS

1. ✅ Build APK em ambiente de release
2. ✅ Testar em dispositivo Android real
3. ✅ Build IPA/testFlight para iOS
4. ✅ Testar em dispositivo iOS real
5. ✅ Validar permissões
6. ✅ Testar offline functionality
7. ✅ Verificar Firebase integration
8. ✅ Testar compartilhamento WhatsApp
9. ✅ Testar geração PDF
10. ✅ Marcar build como pronto para publicação

Qualquer crash encontrado:
1. Anotar stack trace
2. Reproduzir localmente
3. Corrigir bug
4. Reiniciar testes

Boa sorte! 🚀

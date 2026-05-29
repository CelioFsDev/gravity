# 📱 Configurações de SDK - Android e iOS

## 🔍 STATUS ATUAL DO PROJETO

### Flutter
- **Versão**: 3.41.9 ✅
- **Dart**: 3.11.5 ✅

### Android
- **Namespace**: com.catalogoja.app ✅
- **minSdk**: flutter.minSdkVersion (padrão = 21)
- **targetSdk**: flutter.targetSdkVersion (padrão = 34)
- **compileSdk**: flutter.compileSdkVersion (padrão = 34)
- **Java Version**: 17 ✅

### iOS
- **Deployment Target**: 13.0 ✅
- **Xcode**: Compatível ✅

---

## ⚠️ PROBLEMA: targetSdk DESATUALIZADO

### Por que é um problema?

A partir de **agosto de 2025**, o Google Play exige:
- **targetSdk ≥ 35** (Android 15)
- Apps com targetSdk < 35 não podem ser publicadas

Seu app está usando targetSdk **34**, o que é rejeitado.

### Solução

Você tem duas opções:

#### OPÇÃO 1: Atualizar Flutter (RECOMENDADO)
```powershell
# Atualizar para versão mais recente do Flutter
flutter upgrade

# Verificar versão
flutter --version
```

Com Flutter 3.45+ ou 3.50+, os padrões vêm com targetSdk = 35.

#### OPÇÃO 2: Override manual em build.gradle.kts (TEMPORÁRIO)
Se não quiser atualizar Flutter agora, force o valor:

```kotlin
android {
    compileSdk = 35  // Ao invés de flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.catalogoja.app"
        minSdk = 21  // Ao invés de flutter.minSdkVersion
        targetSdk = 35  // Ao invés de flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }
}
```

---

## 📋 TABELA DE COMPATIBILIDADE

### Android Versions

| Version | Code | Release | minSdk | targetSdk | Status |
|---------|------|---------|--------|-----------|--------|
| Android 5.0 | 21 | 2014 | ✅ OK | ❌ Defasado | Mínimo aceitável |
| Android 8.0 | 26 | 2017 | ✅ OK | ⚠️ Antigo | Ainda funciona |
| Android 12 | 31 | 2021 | ✅ OK | ⚠️ Antigo | Funciona |
| Android 13 | 33 | 2022 | ✅ OK | ⚠️ Antigo | Funciona |
| Android 14 | 34 | 2023 | ✅ OK | ❌ REJEITADO | Play Store exigirá upgrade |
| Android 15 | 35 | 2024 | ✅ OK | ✅ OBRIGATÓRIO | EXIGIDO em 2025 |

**Recomendação para 2026**:
- `minSdk = 21` (suporta 99% dos dispositivos)
- `targetSdk = 35` ou superior
- `compileSdk = 35` ou superior

### iOS Versions

| Version | Release | Suportado? | Status |
|---------|---------|-----------|--------|
| iOS 12 | 2018 | ✅ Sim | Mínimo aceitável |
| iOS 13 | 2019 | ✅ Sim | **Seu projeto usa isto** |
| iOS 14 | 2020 | ✅ Sim | Recomendado |
| iOS 15+ | 2021+ | ✅ Sim | Exigido para novos apps |

**Seu projeto está OK no iOS!** iOS 13 ainda é aceitável, mas considere atualizar para 14+ para loja.

---

## 🚀 IMPLEMENTAÇÃO - PASSO A PASSO

### PASSO 1: Atualizar Flutter (Recomendado)

```powershell
cd f:\gravity

# Ver versão atual
flutter --version

# Atualizar para estável mais recente
flutter upgrade

# Verificar novamente
flutter --version
```

**Benefícios:**
- ✅ targetSdk automatically = 35+
- ✅ Segurança melhorada
- ✅ Performance otimizada
- ✅ Novos resources do Flutter

### PASSO 2: Limpar e Rebuild

```powershell
cd f:\gravity

# Limpar artifacts antigos
flutter clean

# Get packages novamente
flutter pub get

# Build para validar
flutter build apk --release
```

### PASSO 3: Verificar Versão no AndroidManifest

Seu `AndroidManifest.xml` não precisa de mudanças (uses `flutter.` variables).

### PASSO 4: iOS - Aumentar Deployment Target (Opcional)

Se quiser suportar iOS mais recente:

1. Abra Xcode:
```powershell
open ios/Runner.xcworkspace
```

2. Em **Build Settings**, procure por **Deployment Target**
3. Mude de 13.0 para 14.0 ou 15.0

Ou editando o arquivo `ios/Podfile`:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'FLUTTER_ROOT=\$(SRCROOT)/Flutter',
      ]
      # Aumentar versão de iOS
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end
```

---

## ✅ CHECKLIST DE VALIDAÇÃO

- [ ] Atualizar Flutter com `flutter upgrade`
- [ ] Executar `flutter clean`
- [ ] Executar `flutter pub get`
- [ ] Compilar APK: `flutter build apk --release`
- [ ] Verificar `android/app/build.gradle.kts` após upgrade
- [ ] Testar em dispositivo real com Android 14+
- [ ] (Opcional) Atualizar iOS Deployment Target para 14.0+
- [ ] Aumentar `versionCode` em pubspec.yaml (ex: 1.0.1+2)

---

## 🔧 COMANDOS ÚTEIS

```powershell
# Ver versão Flutter instalada
flutter --version

# Ver versões de todas as tools
flutter doctor -v

# Ver qual minSdk/targetSdk será usado
cd f:\gravity
flutter pub get
flutter build appbundle --release 2>&1 | grep -i "sdk\|target\|compile"

# Verificar compatibilidade Android
adb shell getprop ro.build.version.sdk

# Verificar compileSdk necessário
grep -r "compileSdk" android/app/build.gradle.kts
```

---

## ⚠️ CUIDADOS IMPORTANTES

1. **Não remova Android 5.0 (minSdk 21) support**
   - Isso deixa 2-3% dos usuários incapazes de baixar
   - Mantenha minSdk = 21

2. **Play Store 2026 Requirements:**
   - targetSdk ≥ 35 (OBRIGATÓRIO)
   - Mudar para targetSdk 34 NÃO será aceito

3. **Testabilidade:**
   - Teste em dispositivo com Android 14 mínimo
   - Valide permissões de runtime (camera, storage, etc)
   - Teste offline functionality

4. **iOS considerations:**
   - iOS 13 ainda é aceitável
   - Considere iOS 14+ para melhor segurança
   - Apple pode exigir iOS 15+ em 2026

---

## 🔗 PRÓXIMOS PASSOS

1. ✅ Executar `flutter upgrade`
2. ✅ Validar novo targetSdk
3. ✅ Testar builds localmente
4. ✅ Aumentar versionCode antes de publicar

Depois de atualizar Flutter, todos os requerimentos de SDK estarão automaticamente atualizados! 🎉

---

## 📚 REFERÊNCIAS

- Flutter Supported Versions: https://flutter.dev/docs/development/tools/sdk/releases
- Android Target API Levels: https://developer.android.com/google/play/requirements/target-api-level
- iOS Deployment Targets: https://developer.apple.com/support/xcode/

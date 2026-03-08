# User Sync Setup

## O que foi implementado

- Cloud Function `syncAuthUsers`
- Chamada Flutter via `cloud_functions`
- Botao no painel `Gerenciar Usuarios` para verificar novos emails cadastrados

## Como funciona

1. O super admin faz login com `ti.vitoriana@gmail.com`
2. Abre `Configuracoes > Gerenciar Usuarios`
3. Clica em `Verificar novos emails cadastrados`
4. A Cloud Function lista os usuarios do Firebase Auth
5. Cada usuario com email eh salvo em `users/{email}`
6. O campo `role` existente no Firestore eh preservado
7. Usuarios novos entram como `viewer`, exceto o super admin, que entra como `admin`

## Arquivos principais

- `functions/index.js`
- `lib/data/repositories/user_sync_repository.dart`
- `lib/features/admin/users/user_management_screen.dart`
- `firestore.rules`

## Preparacao local

```bash
flutter pub get
cd functions
npm install
```

## Deploy

```bash
firebase deploy --only functions,firestore:rules
```

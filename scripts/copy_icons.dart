import 'dart:io';

void main() async {
  const artifactDir = r'C:\Users\celio\.gemini\antigravity\brain\2deeaad9-7f7c-4aac-87a0-a27f42e2dd72';
  const targetDir = r'f:\gravity\assets\icon';

  final mappings = {
    'icon_dashboard_1776986360080.png': 'dashboard.png',
    'icon_products_1776986376474.png': 'products.png',
    'icon_collections_1776986392137.png': 'collections.png',
    'icon_categories_1776986465893.png': 'categories.png',
    'icon_settings_profile_1776986480717.png': 'settings_profile.png',
    'catalogo_ja_login_background_premium_1776986500878.png': 'login_bg.png',
  };

  final dir = Directory(targetDir);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  for (var entry in mappings.entries) {
    final sourceFile = File('$artifactDir\\${entry.key}');
    final targetFile = File('$targetDir\\${entry.value}');

    if (await sourceFile.exists()) {
      await sourceFile.copy(targetFile.path);
      print('Copiado: ${entry.key} -> ${entry.value}');
    } else {
      print('Erro: Fonte não encontrada -> ${entry.key}');
    }
  }
  
  print('\nPronto! Agora você pode usar os novos ícones no app.');
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/settings_viewmodel.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _storeNameController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _remotePhotoUrlController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsViewModelProvider);
    _storeNameController = TextEditingController(text: settings.storeName);
    _whatsappController = TextEditingController(text: settings.whatsappNumber);
    _baseUrlController = TextEditingController(text: settings.publicBaseUrl);
    _remotePhotoUrlController = TextEditingController(
      text: settings.remoteImageBaseUrl,
    );
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _whatsappController.dispose();
    _baseUrlController.dispose();
    _remotePhotoUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(settingsViewModelProvider.notifier)
        .updateSettings(
          storeName: _storeNameController.text,
          whatsappNumber: _whatsappController.text,
          publicBaseUrl: _baseUrlController.text,
          remoteImageBaseUrl: _remotePhotoUrlController.text,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura\u00e7\u00f5es salvas com sucesso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Configura\u00e7\u00f5es',
      subtitle: 'Personalize sua loja e cat\u00e1logo',
      maxWidth: 800,
      actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          children: [
            SectionCard(
              title: 'Perfil da Loja',
              child: Column(
                children: [
                  _buildField(
                    controller: _storeNameController,
                    label: 'Nome da Loja',
                    hint: 'Ex: Minha Loja Fashion',
                    icon: Icons.storefront_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _whatsappController,
                    label: 'WhatsApp de Vendas',
                    hint: '5511999999999',
                    icon: Icons.phone_outlined,
                    helper: 'Apenas n\u00fameros, com DDI (ex: 55)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionCard(
              title: 'Integra\u00e7\u00e3o e Links',
              child: Column(
                children: [
                  _buildField(
                    controller: _baseUrlController,
                    label: 'URL Base do Cat\u00e1logo',
                    hint: 'https://seusite.com',
                    icon: Icons.language_outlined,
                    helper: 'Usado para gerar links de compartilhamento',
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _remotePhotoUrlController,
                    label: 'URL Base para Fotos (Nuvem)',
                    hint: 'https://seusite.com/fotos',
                    icon: Icons.cloud_download_outlined,
                    helper:
                        'As fotos devem seguir o padr\u00e3o da refer\u00eancia (ex.: REFERENCIA_principal, REFERENCIA_cor_preto) com extens\u00e3o de imagem.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Vers\u00e3o do App: 1.0.0',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            prefixIcon: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

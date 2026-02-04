import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/viewmodels/settings_viewmodel.dart';
import 'package:gravity/ui/theme/app_tokens.dart';
import 'package:gravity/ui/widgets/app_scaffold.dart';
import 'package:gravity/ui/widgets/section_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _storeNameController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _baseUrlController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsViewModelProvider);
    _storeNameController = TextEditingController(text: settings.storeName);
    _whatsappController = TextEditingController(text: settings.whatsappNumber);
    _baseUrlController = TextEditingController(text: settings.publicBaseUrl);
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _whatsappController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(settingsViewModelProvider.notifier)
        .updateSettings(
          storeName: _storeNameController.text,
          whatsappNumber: _whatsappController.text,
          publicBaseUrl: _baseUrlController.text,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações salvas com sucesso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Configurações',
      subtitle: 'Personalize sua loja e catálogo',
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
                    helper: 'Apenas números, com DDI (ex: 55)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionCard(
              title: 'Integração e Links',
              child: Column(
                children: [
                  _buildField(
                    controller: _baseUrlController,
                    label: 'URL Base do Catálogo',
                    hint: 'https://seusite.com',
                    icon: Icons.language_outlined,
                    helper: 'Usado para gerar links de compartilhamento',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Versão do App: 1.0.0',
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

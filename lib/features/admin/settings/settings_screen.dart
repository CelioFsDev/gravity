import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/features/theme/theme_providers.dart';
import 'package:gravity/viewmodels/settings_viewmodel.dart';
import 'package:gravity/models/app_settings.dart';
import 'package:gravity/core/widgets/responsive_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMode = ref.watch(themeModeProvider);
    final isDarkMode = activeMode == ThemeMode.dark;
    final settingsAsync = ref.watch(settingsViewModelProvider);

    return ResponsiveScaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Configurações',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Text('Aparência', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            value: isDarkMode,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).state = value
                  ? ThemeMode.dark
                  : ThemeMode.light;
            },
            title: const Text('Modo escuro'),
            subtitle: const Text('Ativa o visual escuro em todo o app'),
          ),
          const Divider(height: 32),
          Text('Loja', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          settingsAsync.when(
            data: (settings) => _StoreSettingsForm(settings: settings),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Text('Erro ao carregar configurações: $e'),
          ),
        ],
      ),
    );
  }
}

class _StoreSettingsForm extends ConsumerStatefulWidget {
  final AppSettings settings;

  const _StoreSettingsForm({required this.settings});

  @override
  ConsumerState<_StoreSettingsForm> createState() => _StoreSettingsFormState();
}

class _StoreSettingsFormState extends ConsumerState<_StoreSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _baseUrlCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.settings.storeName);
    _whatsappCtrl = TextEditingController(
      text: widget.settings.defaultWhatsapp,
    );
    _baseUrlCtrl = TextEditingController(
      text: widget.settings.publicBaseUrl ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _whatsappCtrl.dispose();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(settingsViewModelProvider.notifier)
        .updateSettings(
          storeName: _nameCtrl.text,
          defaultWhatsapp: _whatsappCtrl.text,
          publicBaseUrl: _baseUrlCtrl.text.isEmpty ? null : _baseUrlCtrl.text,
        );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configurações salvas!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome da Loja',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.store),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _whatsappCtrl,
            decoration: const InputDecoration(
              labelText: 'WhatsApp Padrão (Receber Pedidos)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
              helperText: 'Ex: 5511999999999 (apenas números)',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _baseUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'URL Base Pública (Opcional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
              helperText: 'Para compartilhar links (ex: https://loja.com)',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Salvar Alterações'),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/viewmodels/settings_viewmodel.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

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
        const SnackBar(
          content: Text('Configura\u00e7\u00f5es salvas com sucesso!'),
        ),
      );
    }
  }

  Future<void> _testPublicLink(String baseUrl) async {
    final catalogs = ref.read(catalogsViewModelProvider).value ?? [];
    String shareCode = 'TEST-CODE';

    try {
      final publicCatalog = catalogs.firstWhere(
        (c) => c.isPublic && c.shareCode.isNotEmpty,
      );
      shareCode = publicCatalog.shareCode;
    } catch (_) {
      // No public catalog found, using fake
    }

    // Clean base URL for testing
    var finalBaseUrl = baseUrl.trim();
    if (finalBaseUrl.endsWith('/')) {
      finalBaseUrl = finalBaseUrl.substring(0, finalBaseUrl.length - 1);
    }
    if (!finalBaseUrl.startsWith('http')) {
      finalBaseUrl = 'https://$finalBaseUrl';
    }

    final fullUrl = '$finalBaseUrl/c/$shareCode';
    final uri = Uri.parse(fullUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'N\u00e3o foi poss\u00edvel abrir a URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir link: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
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
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder(
                    valueListenable: _baseUrlController,
                    builder: (context, value, _) {
                      final url = value.text.trim();
                      if (url.isEmpty) return const SizedBox.shrink();

                      var displayUrl = url;
                      if (displayUrl.endsWith('/')) {
                        displayUrl = displayUrl.substring(
                          0,
                          displayUrl.length - 1,
                        );
                      }
                      if (!displayUrl.startsWith('http')) {
                        displayUrl = 'https://$displayUrl';
                      }

                      return Container(
                        padding: const EdgeInsets.all(AppTokens.space12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(40),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Pr\u00e9via do link p\u00fablico:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$displayUrl/c/XYZ123',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: const Text('Testar link p\u00fablico'),
                                onPressed: () => _testPublicLink(displayUrl),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              SectionCard(
                title: '🧪 Depura\u00e7\u00e3o: Simular Perfil',
                child: Column(
                  children: UserRole.values.map((role) {
                    final current = ref.watch(currentRoleProvider);
                    return RadioListTile<UserRole>(
                      title: Text(role.label),
                      value: role,
                      groupValue: current,
                      onChanged: (value) {
                        if (value != null) {
                          ref.read(currentRoleProvider.notifier).setRole(value);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
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
    void Function(String)? onChanged,
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
          onChanged: onChanged,
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

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_scaffold.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
import 'package:catalogo_ja/viewmodels/settings_viewmodel.dart';
import 'package:catalogo_ja/viewmodels/catalogs_viewmodel.dart';
import 'package:catalogo_ja/data/repositories/user_repository.dart';
import 'package:catalogo_ja/core/auth/user_role.dart';
import 'package:catalogo_ja/viewmodels/tenant_viewmodel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class StoreContactShareScreen extends ConsumerStatefulWidget {
  const StoreContactShareScreen({super.key});

  @override
  ConsumerState<StoreContactShareScreen> createState() =>
      _StoreContactShareScreenState();
}

class _StoreContactShareScreenState
    extends ConsumerState<StoreContactShareScreen> {
  late final TextEditingController _messageController;
  String _lastGeneratedMessage = '';
  bool _isSyncingMessage = false;
  bool _hasEditedMessage = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _messageController.addListener(_handleMessageChanged);
  }

  @override
  void dispose() {
    _messageController
      ..removeListener(_handleMessageChanged)
      ..dispose();
    super.dispose();
  }

  void _handleMessageChanged() {
    if (_isSyncingMessage) return;
    _hasEditedMessage = _messageController.text != _lastGeneratedMessage;
  }

  void _syncGeneratedMessage(String generatedMessage) {
    if (_lastGeneratedMessage == generatedMessage) return;

    _lastGeneratedMessage = generatedMessage;
    if (_hasEditedMessage) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _hasEditedMessage ||
          _messageController.text == _lastGeneratedMessage) {
        return;
      }

      _isSyncingMessage = true;
      _messageController.value = TextEditingValue(
        text: _lastGeneratedMessage,
        selection: TextSelection.collapsed(offset: _lastGeneratedMessage.length),
      );
      _isSyncingMessage = false;
      setState(() {});
    });
  }

  void _resetMessageToGenerated() {
    _hasEditedMessage = false;
    _isSyncingMessage = true;
    _messageController.value = TextEditingValue(
      text: _lastGeneratedMessage,
      selection: TextSelection.collapsed(offset: _lastGeneratedMessage.length),
    );
    _isSyncingMessage = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsViewModelProvider);
    final catalogs = ref.watch(catalogsViewModelProvider).valueOrNull ?? [];

    // Find a default catalog (prefer public ones)
    final defaultCatalog = catalogs.isNotEmpty
        ? (catalogs.where((c) => c.isPublic).firstOrNull ?? catalogs.first)
        : null;

    final catalogUrl =
        defaultCatalog != null && defaultCatalog.shareCode.isNotEmpty
            ? '${settings.publicBaseUrl}/c/${defaultCatalog.shareCode}'
            : null;

    final currentTenantId =
        ref.watch(currentTenantProvider).valueOrNull?.id ?? '';
    final currentStoreId =
        ref.watch(currentStoreIdProvider).valueOrNull ?? '';

    final usersStream = ref
        .watch(userRepositoryProvider)
        .getUsersForTenantAndStoreStream(
          tenantId: currentTenantId,
          storeId: currentStoreId,
        );

    return AppScaffold(
      title: 'Divulgação da Loja',
      subtitle: 'Dados de contato e link para clientes',
      maxWidth: 700,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: usersStream,
        builder: (context, snapshot) {
          // Only show users with the seller role (not admin)
          final sellers = snapshot.data
                  ?.where(
                    (u) =>
                        effectiveUserRoleName(
                          u,
                          tenantId: currentTenantId,
                          storeId: currentStoreId,
                        ) ==
                            UserRole.seller.name &&
                        (u['disabled'] as bool? ?? false) == false,
                  )
                  .toList() ??
              [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMessagePreview(context, settings, catalogUrl, sellers),
                const SizedBox(height: AppTokens.space24),
                SectionCard(
                  title: 'Informações da Loja',
                  child: Column(
                    children: [
                      _buildInfoTile(
                        Icons.storefront_outlined,
                        'Loja',
                        settings.storeName,
                      ),
                      _buildInfoTile(
                        Icons.phone_outlined,
                        'WhatsApp Principal',
                        settings.whatsappNumber,
                        onTap: settings.whatsappNumber.isNotEmpty
                            ? () => _launchWhatsApp(settings.whatsappNumber)
                            : null,
                      ),
                      _buildInfoTile(
                        Icons.camera_alt_outlined,
                        'Instagram da Loja',
                        settings.instagramUrl,
                        onTap: settings.instagramUrl.isNotEmpty
                            ? () => _launchUrl(settings.instagramUrl)
                            : null,
                      ),
                      _buildInfoTile(
                        Icons.business_outlined,
                        'Instagram da Empresa',
                        settings.companyInstagramUrl,
                        onTap: settings.companyInstagramUrl.isNotEmpty
                            ? () => _launchUrl(settings.companyInstagramUrl)
                            : null,
                      ),
                      if (catalogUrl != null)
                        _buildInfoTile(
                          Icons.menu_book_outlined,
                          'Catálogo Padrão',
                          catalogUrl,
                          onTap: () => _launchUrl(catalogUrl),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space24),
                if (sellers.isNotEmpty)
                  SectionCard(
                    title: 'Vendedores',
                    child: Column(
                      children: sellers.map((s) {
                        final name =
                            s['displayName'] as String? ?? 'Vendedor';
                        final whatsapp =
                            s['whatsappNumber'] as String? ?? '';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                AppTokens.accentBlue.withOpacity(0.1),
                            child: const Icon(
                              Icons.person,
                              color: AppTokens.accentBlue,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            whatsapp.isEmpty ? 'Sem WhatsApp' : whatsapp,
                          ),
                          trailing: whatsapp.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.message_outlined,
                                    color: Colors.green,
                                  ),
                                  onPressed: () => _launchWhatsApp(whatsapp),
                                )
                              : null,
                        );
                      }).toList(),
                    ),
                  )
                else if (snapshot.connectionState == ConnectionState.active &&
                    sellers.isEmpty)
                  SectionCard(
                    title: 'Vendedores',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppTokens.textMuted, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nenhum vendedor cadastrado nesta loja.',
                              style: TextStyle(
                                color: AppTokens.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: AppTokens.space48),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessagePreview(
    BuildContext context,
    dynamic settings,
    String? catalogUrl,
    List<Map<String, dynamic>> sellers,
  ) {
    final generatedMessage = _generateMessage(settings, catalogUrl, sellers);
    _syncGeneratedMessage(generatedMessage);

    return SectionCard(
      title: 'Prévia da Mensagem',
      trailing: TextButton.icon(
        onPressed: _hasEditedMessage ? _resetMessageToGenerated : null,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('REGERAR'),
      ),
      child: Column(
        children: [
          TextField(
            controller: _messageController,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(fontSize: 13, height: 1.6),
            decoration: InputDecoration(
              hintText: 'Edite a mensagem antes de copiar ou compartilhar',
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade100,
              contentPadding: const EdgeInsets.all(AppTokens.space16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTokens.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (_) {
              setState(() {});
            },
          ),
          if (_hasEditedMessage) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Usando a mensagem editada para copiar e compartilhar.',
                style: TextStyle(
                  color: AppTokens.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final copyButton = SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _copyToClipboard(context, _messageController.text),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('COPIAR'),
                ),
              );
              final shareButton = AppPrimaryButton(
                onPressed: _messageController.text.trim().isEmpty
                    ? null
                    : () => _handleShare(context, _messageController.text),
                icon: Icons.share_rounded,
                label: 'COMPARTILHAR',
              );

              if (constraints.maxWidth < 430) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copyButton,
                    const SizedBox(height: 12),
                    shareButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: copyButton),
                  const SizedBox(width: 12),
                  Expanded(child: shareButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _generateMessage(
    dynamic settings,
    String? catalogUrl,
    List<Map<String, dynamic>> sellers,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('🛍️ *${settings.storeName}*');
    buffer.writeln('Olá! Confira nossos contatos e catálogo:');
    buffer.writeln();

    if (catalogUrl != null) {
      buffer.writeln('📖 *Nosso Catálogo:*');
      buffer.writeln(catalogUrl);
      buffer.writeln();
    }

    if ((settings.whatsappNumber as String).isNotEmpty) {
      buffer.writeln(
          '📞 *WhatsApp:* https://wa.me/${settings.whatsappNumber}');
    }

    if ((settings.instagramUrl as String).isNotEmpty) {
      buffer.writeln('📸 *Instagram:* ${settings.instagramUrl}');
    }

    if ((settings.companyInstagramUrl as String).isNotEmpty) {
      buffer.writeln('🏢 *Empresa:* ${settings.companyInstagramUrl}');
    }

    if (sellers.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('👥 *Fale com nossos vendedores:*');
      for (final s in sellers) {
        final name = s['displayName'] as String? ?? 'Vendedor';
        final whatsapp = s['whatsappNumber'] as String? ?? '';
        if (whatsapp.isNotEmpty) {
          buffer.writeln('• $name: https://wa.me/$whatsapp');
        } else {
          buffer.writeln('• $name');
        }
      }
    }

    buffer.writeln();
    buffer.writeln('Aguardamos seu contato! ✨');

    return buffer.toString().trim();
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final isEmpty = value.isEmpty;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: AppTokens.textMuted),
      title: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppTokens.textMuted),
      ),
      subtitle: Text(
        isEmpty ? 'Não informado' : value,
        style: TextStyle(
          fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
          fontSize: 14,
          color: isEmpty ? AppTokens.textMuted : null,
        ),
      ),
      trailing: !isEmpty && onTap != null
          ? const Icon(Icons.open_in_new, size: 16, color: AppTokens.textMuted)
          : null,
      onTap: onTap,
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copiado para a área de transferência!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleShare(BuildContext context, String message) async {
    final text = message.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escreva uma mensagem antes de compartilhar.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_canUseNativeShare) {
      try {
        final result = await SharePlus.instance.share(ShareParams(text: text));
        if (result.status != ShareResultStatus.unavailable) {
          return;
        }
      } catch (_) {
        // Fall through to the WhatsApp/copy fallback below.
      }
    }

    if (context.mounted) {
      _copyToClipboard(context, text);
      await Future.delayed(const Duration(milliseconds: 300));
      if (context.mounted) {
        _showDesktopShareDialog(context, text);
      }
    }
  }

  bool get _canUseNativeShare {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _showDesktopShareDialog(BuildContext context, String message) {
    // Build WhatsApp web URL with encoded message
    final encoded = Uri.encodeComponent(message);
    final waUrl = 'https://wa.me/?text=$encoded';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.share_rounded, size: 20),
            SizedBox(width: 8),
            Text('Mensagem Copiada!'),
          ],
        ),
        content: const Text(
          'A mensagem foi copiada.\nDeseja abrir o WhatsApp Web para colar e enviar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('FECHAR'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(waUrl);
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Nao foi possivel abrir o WhatsApp. A mensagem ja foi copiada.',
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('ABRIR WHATSAPP WEB'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsApp(String phone) async {
    // Remove any non-digit characters
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchUrl(String rawUrl) async {
    var url = rawUrl.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

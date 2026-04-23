import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class StoreQrCodePage extends ConsumerStatefulWidget {
  const StoreQrCodePage({super.key});

  @override
  ConsumerState<StoreQrCodePage> createState() => _StoreQrCodePageState();
}

class _StoreQrCodePageState extends ConsumerState<StoreQrCodePage> {
  bool _isEditing = false;
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _saveUrl(WidgetRef ref, String currentStoreName) async {
    final newUrl = _urlController.text.trim();
    final repo = ref.read(settingsRepositoryProvider);
    final settings = repo.getSettings();
    
    await repo.saveSettings(settings.copyWith(qrTargetUrl: newUrl));
    
    setState(() {
      _isEditing = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL do QR Code atualizada!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuta as configurações da loja em tempo real
    final settings = ref.watch(settingsRepositoryProvider).getSettings();
    final qrUrl = settings.qrTargetUrl;
    final storeName = settings.storeName;

    // Estado Vazio ou Modo Edição
    if (qrUrl.isEmpty || _isEditing) {
      if (qrUrl.isNotEmpty && _urlController.text.isEmpty) {
        _urlController.text = qrUrl;
      }
      
      return Scaffold(
        appBar: AppBar(title: const Text('Configurar QR Code')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.qr_code_scanner, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                qrUrl.isEmpty 
                  ? 'Configure o destino do seu QR Code' 
                  : 'Editar URL do QR Code',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cole o link da sua vitrine, Linktree, Instagram ou WhatsApp para que os clientes te achem.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL de Destino',
                  hintText: 'https://linktr.ee/minhaloja',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _saveUrl(ref, storeName),
                icon: const Icon(Icons.save),
                label: const Text('Salvar URL e Gerar QR'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
              if (_isEditing && qrUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: const Text('Cancelar'),
                )
              ]
            ],
          ),
        ),
      );
    }

    // Estado com QR Code Preenchido
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code da Loja'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar URL',
            onPressed: () => setState(() => _isEditing = true),
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                storeName,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text('Escaneie para acessar', style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 40),
              
              // Renderização do QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2),
                  ],
                ),
                child: QrImageView(
                  data: qrUrl,
                  version: QrVersions.auto,
                  size: 250.0,
                  backgroundColor: Colors.white,
                ),
              ),
              
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  qrUrl,
                  style: const TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Ações Rápidas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.copy,
                    label: 'Copiar Link',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: qrUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copiado para a área de transferência!')),
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.share,
                    label: 'Compartilhar',
                    onTap: () {
                      Share.share('Confira nossos produtos aqui: $qrUrl');
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.download,
                    label: 'Salvar Imagem',
                    onTap: () {
                      // TODO: Implementar salvamento de Widget em Imagem (usando screenshot ou RepaintBoundary)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Em breve: Salvar QR como imagem na galeria.')),
                      );
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.shade50,
              child: Icon(icon, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity/models/seller.dart';
import 'package:gravity/viewmodels/sellers_viewmodel.dart';
import 'package:intl/intl.dart';

class SellersScreen extends ConsumerWidget {
  const SellersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellersState = ref.watch(sellersViewModelProvider);

    return Scaffold(
      body: sellersState.when(
        data: (sellers) => _buildContent(context, ref, sellers),
        error: (e, s) => Center(child: Text('Erro: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<Seller> sellers) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Vendedoras',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                   Text(
                    'Gerencie seu time de vendas',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showSellerDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Nova Vendedora'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (sellers.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Nenhuma vendedora cadastrada.'),
              ),
            )
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sellers.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final seller = sellers[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: seller.isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      child: Text(
                        seller.name.substring(0, 1).toUpperCase(),
                         style: TextStyle(
                            color: seller.isActive ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(seller.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(seller.whatsapp),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Status Toggle
                        Switch(
                          value: seller.isActive,
                          onChanged: (val) {
                             ref.read(sellersViewModelProvider.notifier).toggleActive(seller.id);
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showSellerDialog(context, ref, seller: seller),
                          tooltip: 'Editar',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteSeller(context, ref, seller),
                          tooltip: 'Excluir',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteSeller(BuildContext context, WidgetRef ref, Seller seller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir vendedora'),
        content: Text('Tem certeza que deseja excluir ${seller.name}? Histórico de vendas será mantido, mas ela não aparecerá mais nesta lista.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(sellersViewModelProvider.notifier).deleteSeller(seller.id);
    }
  }

  void _showSellerDialog(BuildContext context, WidgetRef ref, {Seller? seller}) {
    showDialog(
      context: context,
      builder: (c) => SellerFormDialog(seller: seller),
    );
  }
}

class SellerFormDialog extends ConsumerStatefulWidget {
  final Seller? seller;

  const SellerFormDialog({super.key, this.seller});

  @override
  ConsumerState<SellerFormDialog> createState() => _SellerFormDialogState();
}

class _SellerFormDialogState extends ConsumerState<SellerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _whatsappCtrl;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.seller?.name ?? '');
    _whatsappCtrl = TextEditingController(text: widget.seller?.whatsapp ?? '');
    _isActive = widget.seller?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.seller != null;
    return AlertDialog(
      title: Text(isEditing ? 'Editar Vendedora' : 'Nova Vendedora'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Nome obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _whatsappCtrl,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp *',
                  border: OutlineInputBorder(),
                  helperText: 'Apenas números (ex: 5511999999999)',
                ),
                validator: (v) => v == null || v.isEmpty ? 'WhatsApp obrigatório' : null,
              ),
              const SizedBox(height: 16),
              if (isEditing) 
                SwitchListTile(
                  title: const Text('Ativa'),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEditing ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (widget.seller != null) {
        await ref.read(sellersViewModelProvider.notifier).updateSeller(
              id: widget.seller!.id,
              name: _nameCtrl.text,
              whatsapp: _whatsappCtrl.text,
              isActive: _isActive,
            );
      } else {
        await ref.read(sellersViewModelProvider.notifier).createSeller(
              name: _nameCtrl.text,
              whatsapp: _whatsappCtrl.text,
              isActive: _isActive,
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    }
  }
}

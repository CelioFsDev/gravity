import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:catalogo_ja/viewmodels/categories_viewmodel.dart';
import 'package:catalogo_ja/models/category_type.dart';

class CategoryCreateModal extends ConsumerStatefulWidget {
  const CategoryCreateModal({super.key});

  @override
  ConsumerState<CategoryCreateModal> createState() =>
      _CategoryCreateModalState();
}

class _CategoryCreateModalState extends ConsumerState<CategoryCreateModal> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(categoriesViewModelProvider.notifier);
      final newId = const Uuid().v4();

      final error = await notifier.addCategory(
        name,
        CategoryType.productType,
        id: newId,
      );

      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Categoria salva localmente! Sincronize para subir à nuvem.'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.blue,
            ),
          );
          context.pop(newId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova Categoria'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Nome da Categoria',
          hintText: 'Ex: Camisetas, Cal\u00e7as...',
          filled: true,
        ),
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Criar'),
        ),
      ],
    );
  }
}

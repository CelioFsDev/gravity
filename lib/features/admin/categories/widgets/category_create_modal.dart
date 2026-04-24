import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/app_primary_button.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? AppTokens.surfaceDark : Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'Nova Categoria',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 20,
          color: isDark ? Colors.white : Colors.black87,
          letterSpacing: -0.5,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'Nome da Categoria',
              labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              hintText: 'Ex: Camisetas, Calças...',
              hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
              filled: true,
              fillColor: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTokens.electricBlue, width: 2),
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(
            'CANCELAR',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        SizedBox(
          width: 100,
          height: 44,
          child: AppPrimaryButton(
            label: 'CRIAR',
            onPressed: _isLoading ? null : _save,
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }
}

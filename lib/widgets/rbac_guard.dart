import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/core/security/rbac/permissions.dart';
import 'package:catalogo_ja/core/security/rbac/rbac_service.dart';

/// Um Widget que condicionalmente renderiza seu conteúdo com base nas permissões.
/// 
/// Uso:
/// RbacGuard(
///   require: AppPermission.editProduct,
///   child: ElevatedButton(onPressed: () {}, child: Text('Salvar Produto')),
///   fallback: SizedBox.shrink(), // O que mostrar se não tiver permissão
/// )
class RbacGuard extends ConsumerWidget {
  final AppPermission require;
  final Widget child;
  final Widget fallback;

  const RbacGuard({
    super.key,
    required this.require,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rbacService = ref.watch(rbacServiceProvider);

    if (rbacService.hasPermission(require)) {
      return child;
    }

    return fallback;
  }
}

/// Extensão útil para facilitar a checagem no código sem usar o Widget.
/// Ex: if (ref.hasPermission(AppPermission.editProduct)) { ... }
extension RbacWidgetRefX on WidgetRef {
  bool hasPermission(AppPermission permission) {
    return read(rbacServiceProvider).hasPermission(permission);
  }
}

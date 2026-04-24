import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/core/error/app_failure.dart';
import 'package:catalogo_ja/ui/widgets/app_empty_state.dart';

class AppErrorView extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  const AppErrorView({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final failure = error is AppFailure
        ? error as AppFailure
        : AppFailure.fromError(error);

    return Center(
      child: AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Ops! Algo deu errado',
        subtitle: failure.message,
        actionLabel: onRetry != null ? 'Tentar novamente' : null,
        onAction: onRetry,
        message: '',
      ),
    );
  }
}

extension AsyncValueUI on AsyncValue {
  Widget whenStandard({
    required Widget Function(dynamic data) data,
    Widget Function()? loading,
    VoidCallback? onRetry,
  }) {
    return when(
      data: data,
      error: (err, stack) =>
          AppErrorView(error: err, stackTrace: stack, onRetry: onRetry),
      loading:
          loading ?? () => const Center(child: CircularProgressIndicator()),
    );
  }

  void showSnackbarOnError(BuildContext context) {
    if (hasError && !isLoading) {
      final failure = error is AppFailure
          ? (error as AppFailure)
          : AppFailure.fromError(error!);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Clear current snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Detalhes',
              textColor: Colors.white,
              onPressed: () {
                showGeneralDialog(
                  context: context,
                  pageBuilder: (context, _, _) => AlertDialog(
                    title: const Text('Detalhes do Erro'),
                    content: SingleChildScrollView(
                      child: Text(failure.details ?? failure.toString()),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fechar'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      });
    }
  }
}

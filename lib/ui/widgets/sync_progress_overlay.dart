import 'package:flutter/material.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';

class SyncProgressOverlay extends StatelessWidget {
  final double progress;
  final String message;
  final VoidCallback? onCompleted;

  const SyncProgressOverlay({
    super.key,
    required this.progress,
    required this.message,
    this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_download_outlined,
              size: 64,
              color: AppTokens.accentBlue,
            ),
            const SizedBox(height: AppTokens.space24),
            Text(
              'Sincronização Inicial',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              'Preparando seu catálogo para uso offline...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.space40),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusFull),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTokens.accentBlue),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTokens.accentBlue,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.space40),
            const Text(
              'Não feche o app durante este processo.',
              style: TextStyle(
                color: Colors.white30,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (progress >= 1.0 && onCompleted != null) ...[
              const SizedBox(height: AppTokens.space24),
              ElevatedButton(
                onPressed: onCompleted,
                child: const Text('Começar a usar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

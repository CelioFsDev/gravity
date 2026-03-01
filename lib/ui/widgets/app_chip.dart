import 'package:flutter/material.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';

class AppChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onPressed;

  const AppChip({
    super.key,
    required this.label,
    required this.isActive,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTokens.accentBlue : AppTokens.border;
    final bg = isActive ? AppTokens.accentBlue.withOpacity(0.1) : Colors.white;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: bg,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space12,
          vertical: AppTokens.space8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? AppTokens.accentBlue : AppTokens.textMuted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gravity/ui/theme/app_tokens.dart';

class AppBadgePill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLarge;

  const AppBadgePill({
    super.key,
    required this.label,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? AppTokens.space12 : AppTokens.space8,
        vertical: isLarge ? AppTokens.space4 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: isLarge ? 12 : 10,
        ),
      ),
    );
  }
}

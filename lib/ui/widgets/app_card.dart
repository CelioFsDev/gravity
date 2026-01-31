import 'package:flutter/material.dart';
import 'package:gravity/ui/theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(AppTokens.space16),
      child: child,
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        boxShadow: const [AppTokens.shadowSm],
        border: Border.all(color: AppTokens.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

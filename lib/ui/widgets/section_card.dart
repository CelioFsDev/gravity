import 'package:flutter/material.dart';
import 'package:catalogo_ja/ui/motion/app_motion.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart' hide AppMotion;

class SectionCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool showBorder;

  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || trailing != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space4,
              vertical: AppTokens.space8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
        ],
        AppEntrance(
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.enterCurve,
            width: double.infinity,
            padding: padding ?? const EdgeInsets.all(AppTokens.space16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: showBorder
                  ? Border.all(color: Theme.of(context).dividerColor)
                  : null,
              boxShadow: const [AppTokens.shadowSm],
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

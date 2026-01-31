import 'package:flutter/material.dart';
import 'package:gravity/ui/theme/app_tokens.dart';

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: AppTokens.space4),
                Text(subtitle!, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty)
          Wrap(
            spacing: AppTokens.space8,
            runSpacing: AppTokens.space8,
            alignment: WrapAlignment.end,
            children: actions,
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class SectionHeaderAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const SectionHeaderAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final SectionHeaderAction? primaryAction;
  final List<SectionHeaderAction> secondaryActions;
  final bool useMenuForSecondary;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.primaryAction,
    this.secondaryActions = const [],
    this.useMenuForSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];

    if (primaryAction != null) {
      actions.add(
        FilledButton.icon(
          onPressed: primaryAction!.onPressed,
          icon: Icon(primaryAction!.icon),
          label: Text(primaryAction!.label),
        ),
      );
    }

    if (secondaryActions.isNotEmpty) {
      if (useMenuForSecondary) {
        actions.add(
          PopupMenuButton<SectionHeaderAction>(
            tooltip: 'Mais acoes',
            onSelected: (action) => action.onPressed(),
            itemBuilder: (context) => secondaryActions
                .map(
                  (action) => PopupMenuItem(
                    value: action,
                    child: Row(
                      children: [
                        Icon(action.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(action.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        );
      } else {
        actions.addAll(
          secondaryActions.map(
            (action) => OutlinedButton.icon(
              onPressed: action.onPressed,
              icon: Icon(action.icon),
              label: Text(action.label),
            ),
          ),
        );
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
      ],
    );
  }
}


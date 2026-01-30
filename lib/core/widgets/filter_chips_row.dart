import 'package:flutter/material.dart';

class FilterChipsRow extends StatelessWidget {
  final List<Widget> chips;
  final VoidCallback? onClear;

  const FilterChipsRow({
    super.key,
    required this.chips,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._withSpacing(chips, const SizedBox(width: 8)),
          if (onClear != null) ...[
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Limpar'),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> items, Widget spacer) {
    if (items.isEmpty) return [];
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) widgets.add(spacer);
      widgets.add(items[i]);
    }
    return widgets;
  }
}


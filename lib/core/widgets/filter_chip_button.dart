import 'package:flutter/material.dart';

class FilterChipButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const FilterChipButton({
    super.key,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final background = isActive
        ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
        : Colors.grey.shade100;
    final border = isActive
        ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
        : Colors.grey.shade300;
    final textColor = isActive
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade800;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

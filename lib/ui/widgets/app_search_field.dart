import 'package:flutter/material.dart';

class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: baseColor.withOpacity(isDark ? 0.05 : 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: baseColor.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: baseColor.withOpacity(0.3)),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: baseColor.withOpacity(0.5),
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: baseColor.withOpacity(0.5)),
                  onPressed: () {
                    controller.clear();
                    onClear?.call();
                    onChanged?.call('');
                  },
                )
              : null,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

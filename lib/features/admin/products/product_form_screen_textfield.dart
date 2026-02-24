import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:path/path.dart';

Widget _buildTextField(
  TextEditingController controller,
  String label, {
  String? Function(String?)? validator,
  bool isPrice = false,
  bool isNumber = false,
  int maxLines = 1,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Theme.of(context as BuildContext).colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Digite aqui...',
          prefixText: isPrice ? 'R\$ ' : null,
          prefixStyle: TextStyle(
            color: Theme.of(context as BuildContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          filled: true,
          fillColor: Theme.of(
            context as BuildContext,
          ).colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            borderSide: BorderSide(
              color: Theme.of(context as BuildContext).colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            borderSide: BorderSide(
              color: Theme.of(context as BuildContext).colorScheme.error,
              width: 1,
            ),
          ),
        ),
        style: const TextStyle(fontSize: 15),
        validator: validator,
        keyboardType: isPrice || isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : maxLines > 1
            ? TextInputType.multiline
            : TextInputType.text,
        maxLines: maxLines,
        inputFormatters: isPrice || isNumber
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
            : null,
      ),
    ],
  );
}

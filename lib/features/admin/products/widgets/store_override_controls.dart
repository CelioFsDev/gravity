import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/ui/widgets/section_card.dart';

class StoreOverrideControls extends ConsumerWidget {
  final String storeId;
  final bool isIndividual;
  final ValueChanged<bool> onToggleIndividual;
  final List<String> allSizes;
  final List<String> allColors;
  final List<String> unavailableSizes;
  final List<String> unavailableColors;
  final Function(String size, bool unavailable) onToggleSize;
  final Function(String color, bool unavailable) onToggleColor;

  const StoreOverrideControls({
    super.key,
    required this.storeId,
    required this.isIndividual,
    required this.onToggleIndividual,
    required this.allSizes,
    required this.allColors,
    required this.unavailableSizes,
    required this.unavailableColors,
    required this.onToggleSize,
    required this.onToggleColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Unidade Selecionada: $storeId',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            title: const Text(
              'Configurações Individuais',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Preço e estoque exclusivos para esta unidade'),
            value: isIndividual,
            activeColor: AppTokens.accentBlue,
            onChanged: onToggleIndividual,
          ),
          if (isIndividual) ...[
            const Divider(height: 32),
            const Text(
              'Disponibilidade de Variações',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Desmarque os itens que NÃO estão disponíveis nesta unidade.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (allSizes.isNotEmpty) ...[
              const Text('Tamanhos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: allSizes.map((size) {
                  final isUnavailable = unavailableSizes.contains(size);
                  return FilterChip(
                    label: Text(size),
                    selected: !isUnavailable,
                    selectedColor: AppTokens.accentBlue.withOpacity(0.2),
                    checkmarkColor: AppTokens.accentBlue,
                    onSelected: (available) => onToggleSize(size, !available),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (allColors.isNotEmpty) ...[
              const Text('Cores', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: allColors.map((color) {
                  final isUnavailable = unavailableColors.contains(color);
                  return FilterChip(
                    label: Text(color),
                    selected: !isUnavailable,
                    selectedColor: AppTokens.accentBlue.withOpacity(0.2),
                    checkmarkColor: AppTokens.accentBlue,
                    onSelected: (available) => onToggleColor(color, !available),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Dica: Os preços definidos nos campos de "Preços e Estoque" acima serão aplicados APENAS a esta unidade enquanto este switch estiver ligado.',
              style: TextStyle(fontSize: 11, color: AppTokens.accentOrange, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

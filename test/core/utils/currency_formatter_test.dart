import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catalogo_ja/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyInputFormatter', () {
    late CurrencyInputFormatter formatter;

    setUp(() {
      formatter = CurrencyInputFormatter();
    });

    test('should format single digit correctly', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(
          text: '1',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      
      // Some environments output "R$ 0,01", others "R$ 0,01" (with non-breaking space).
      // We check for the numeric part and prefix.
      expect(result.text.replaceAll(' ', ' '), 'R\$ 0,01');
    });

    test('should format multiple digits correctly', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(
          text: '123456',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      
      expect(result.text.replaceAll(' ', ' '), 'R\$ 1.234,56');
    });

    test('should ignore non-digit characters', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(
          text: 'a1b2c3',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      
      expect(result.text.replaceAll(' ', ' '), 'R\$ 1,23');
    });

    test('should handle empty input', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
      
      expect(result.text, '');
    });
  });
}

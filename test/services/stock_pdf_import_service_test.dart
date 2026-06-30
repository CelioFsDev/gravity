import 'package:flutter_test/flutter_test.dart';

// Copia das Regex do servico para testar isoladamente sem carregar syncfusion
final RegExp codeRegex = RegExp(r'^(\d{6})\.?(\d{4})\.([A-Z0-9]+)');
final RegExp fullLineRegex = RegExp(r'^(\d{6}\.?\d{4}\.[A-Z0-9]+)\s+(.+?)\s+UN\s+(\d+)$');

void main() {
  group('StockPdfImport Regex Tests', () {
    test('Formato A: 106898.1001.G', () {
      final match = codeRegex.firstMatch('106898.1001.G');
      expect(match, isNotNull);
      expect(match!.group(1), '106898');
      expect(match.group(2), '1001');
      expect(match.group(3), 'G');
    });

    test('Formato B: 1069041040.P', () {
      final match = codeRegex.firstMatch('1069041040.P');
      expect(match, isNotNull);
      expect(match!.group(1), '106904');
      expect(match.group(2), '1040');
      expect(match.group(3), 'P');
    });

    test('Formato C: 1069371020.38', () {
      final match = codeRegex.firstMatch('1069371020.38');
      expect(match, isNotNull);
      expect(match!.group(1), '106937');
      expect(match.group(2), '1020');
      expect(match.group(3), '38');
    });

    test('Formato D: 106887.1122.EGG', () {
      final match = codeRegex.firstMatch('106887.1122.EGG');
      expect(match, isNotNull);
      expect(match!.group(1), '106887');
      expect(match.group(2), '1122');
      expect(match.group(3), 'EGG');
    });

    test('Full Line Parse A', () {
      final line = '106898.1001.G VESTIDO ALÇA CANELADO LISTRAS PRETO G UN 2';
      final match = fullLineRegex.firstMatch(line);
      expect(match, isNotNull);
      expect(match!.group(1), '106898.1001.G');
      expect(match.group(2), 'VESTIDO ALÇA CANELADO LISTRAS PRETO G');
      expect(match.group(3), '2');
    });

    test('Full Line Parse B (Quebrada e Juntada)', () {
      final line = '106887.1122.EGG CAMISA MICRO LISTRAS MANGA CURTA AZUL ESCURO EXTRA GG UN 1';
      final match = fullLineRegex.firstMatch(line);
      expect(match, isNotNull);
      expect(match!.group(1), '106887.1122.EGG');
      expect(match.group(2), 'CAMISA MICRO LISTRAS MANGA CURTA AZUL ESCURO EXTRA GG');
      expect(match.group(3), '1');
    });
  });
}

double parseMoney(String value) {
  var cleaned = value
      .replaceAll('R\$', '')
      .replaceAll('\u00A0', '')
      .replaceAll(' ', '')
      .trim();

  if (cleaned.isEmpty) return 0.0;
  cleaned = cleaned.replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (cleaned.isEmpty) return 0.0;

  final lastComma = cleaned.lastIndexOf(',');
  final lastDot = cleaned.lastIndexOf('.');

  if (lastComma != -1 && lastDot != -1) {
    final decimalSeparator = lastComma > lastDot ? ',' : '.';
    final thousandSeparator = decimalSeparator == ',' ? '.' : ',';
    cleaned = cleaned.replaceAll(thousandSeparator, '');
    if (decimalSeparator == ',') {
      cleaned = cleaned.replaceAll(',', '.');
    }
    return double.tryParse(cleaned) ?? 0.0;
  }

  if (lastComma != -1 || lastDot != -1) {
    final separator = lastComma != -1 ? ',' : '.';
    final parts = cleaned.split(separator);

    if (parts.length > 2) {
      final fractional = parts.last;
      if (fractional.length <= 2) {
        cleaned =
            '${parts.sublist(0, parts.length - 1).join()}.$fractional';
      } else {
        cleaned = parts.join();
      }
    } else {
      final fractional = parts.length == 2 ? parts[1] : '';
      if (fractional.length == 2) {
        cleaned = parts.join('.');
      } else if (fractional.length == 3) {
        cleaned = parts.join();
      } else {
        cleaned = parts.join('.');
      }
    }
  }

  return double.tryParse(cleaned) ?? 0.0;
}

int parseIntSafe(String value) {
  return int.tryParse(value.trim()) ?? 0;
}

List<String> splitCsvList(String value) {
  return value
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

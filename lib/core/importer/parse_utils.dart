double parseMoney(String value) {
  final cleaned = value
      .replaceAll('R\$', '')
      .replaceAll(' ', '')
      .replaceAll('.', '')
      .replaceAll(',', '.')
      .trim();
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

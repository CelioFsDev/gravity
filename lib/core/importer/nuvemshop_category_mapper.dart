import 'package:catalogo_ja/core/importer/parse_utils.dart';

String? detectCollectionName(List<String> tags) {
  for (final raw in tags) {
    final tag = raw.trim().toLowerCase();
    if (tag.contains('col.') ||
        tag.contains('colecao') ||
        tag.contains('cole\u00e7\u00e3o')) {
      return _normalizeCollection(raw);
    }
  }
  return null;
}

List<String> parseCategoryNames(String csvCategories) {
  return splitCsvList(
    csvCategories,
  ).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

String _normalizeCollection(String raw) {
  var value = raw.trim();
  value = value.replaceAll(
    RegExp(r'colec[a\u00e3]o', caseSensitive: false),
    'Colecao',
  );
  value = value.replaceAll(RegExp(r'col\.', caseSensitive: false), 'Colecao');
  value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (!value.toLowerCase().startsWith('colecao')) {
    value = 'Colecao $value';
  }
  return value;
}

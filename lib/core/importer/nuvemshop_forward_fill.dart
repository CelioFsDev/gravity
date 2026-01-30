List<Map<String, String>> forwardFill(
  List<Map<String, String>> rows,
  List<String> columns,
) {
  final lastValues = <String, String>{};
  final result = <Map<String, String>>[];

  for (final row in rows) {
    final updated = Map<String, String>.from(row);
    for (final column in columns) {
      final value = (row[column] ?? '').trim();
      if (value.isEmpty) {
        if (lastValues.containsKey(column)) {
          updated[column] = lastValues[column]!;
        }
      } else {
        lastValues[column] = value;
      }
    }
    result.add(updated);
  }

  return result;
}

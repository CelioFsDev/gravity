import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class ImportTable {
  final List<String> headers;
  final List<Map<String, String>> rows;

  ImportTable({required this.headers, required this.rows});
}

class NuvemshopCsvReader {
  static Future<ImportTable> readFromFile(File file) async {
    final bytes = await file.readAsBytes();
    return _readFromBytes(bytes);
  }

  static Future<ImportTable> readFromPlatformFile(PlatformFile file) async {
    if (file.bytes != null) {
      return _readFromBytes(file.bytes!);
    }
    if (file.path != null) {
      return readFromFile(File(file.path!));
    }
    throw Exception('Arquivo CSV sem path/bytes');
  }

  static ImportTable _readFromBytes(List<int> bytes) {
    final content = latin1.decode(bytes);
    final delimiter = _detectDelimiter(content);
    final rows = CsvToListConverter(
      fieldDelimiter: delimiter,
    ).convert(content).where((row) => row.isNotEmpty).toList();

    if (rows.isEmpty) {
      throw Exception('CSV vazio');
    }

    final headers = rows.first
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final dataRows = <Map<String, String>>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final map = <String, String>{};
      for (var j = 0; j < headers.length; j++) {
        final value = j < row.length ? row[j].toString() : '';
        map[headers[j]] = value.trim();
      }
      dataRows.add(map);
    }

    return ImportTable(headers: headers, rows: dataRows);
  }

  static String _detectDelimiter(String content) {
    final firstLine = content.split(RegExp(r'\r?\n')).firstOrNull ?? '';
    final commas = ','.allMatches(firstLine).length;
    final semicolons = ';'.allMatches(firstLine).length;
    return semicolons > commas ? ';' : ',';
  }
}

extension _FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isNotEmpty ? first : null;
}

import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

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
    String content;
    try {
      content = utf8.decode(bytes);
      if (content.startsWith('\uFEFF')) {
        content = content.substring(1);
      }
    } catch (_) {
      content = latin1.decode(bytes);
    }

    final allLines = content.split(RegExp(r'\r?\n'));

    // Find the real header line - some exports can vary in language/encoding.
    int headerIndex = -1;
    var bestDelimiterScore = -1;
    for (var i = 0; i < allLines.length; i++) {
      final raw = allLines[i].trim();
      if (raw.isEmpty) continue;
      final line = _normalize(raw);
      final semicolons = ';'.allMatches(raw).length;
      final commas = ','.allMatches(raw).length;
      final delimiterScore = semicolons + commas;

      final hasSlugLike =
          line.contains('identificador') ||
          line.contains('handle') ||
          line.contains('url');
      final hasNameLike =
          line.contains('nome') ||
          line.contains('nombre') ||
          line.contains('name') ||
          line.contains('titulo') ||
          line.contains('title');
      final hasSkuLike = line.contains('sku');

      if ((hasSlugLike && hasNameLike) ||
          (hasSkuLike && hasNameLike && delimiterScore >= 5)) {
        headerIndex = i;
        break;
      }

      // Fallback candidate: first line that looks tabular.
      if (headerIndex == -1 && delimiterScore > bestDelimiterScore) {
        bestDelimiterScore = delimiterScore;
        headerIndex = i;
      }
    }

    if (headerIndex == -1) {
      // Fallback to first non-empty line if no header-like line found
      headerIndex = allLines.indexWhere((l) => l.trim().isNotEmpty);
    }

    if (headerIndex == -1) throw Exception('CSV sem conte\u00fado leg\u00edvel');

    final headerLine = allLines[headerIndex];
    debugPrint(
      'Linha de cabe\u00e7alho detectada (index $headerIndex): "$headerLine"',
    );

    final delimiter = _detectDelimiterForLine(headerLine);
    debugPrint('Delimitador detectado: "$delimiter"');

    // Re-join from header onwards to ensure multi-line fields (quotes) are handled correctly
    final contentFromHeader = allLines.sublist(headerIndex).join('\n');

    final rows = CsvDecoder(
      fieldDelimiter: delimiter,
      dynamicTyping: false,
    ).convert(contentFromHeader).where((row) => row.isNotEmpty).toList();

    if (rows.isEmpty) {
      throw Exception('CSV vazio ap\u00f3s processamento');
    }

    // Clean headers - don't filter out empty ones to keep indices consistent
    final headers = rows.first.map((e) => _cleanHeader(e.toString())).toList();

    debugPrint(
      'Colunas processadas (${headers.length}): ${headers.join(', ')}',
    );

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

  static String _detectDelimiterForLine(String line) {
    final commas = ','.allMatches(line).length;
    final semicolons = ';'.allMatches(line).length;
    return semicolons > commas ? ';' : ',';
  }

  static String _cleanHeader(String raw) {
    // Remove non-printable characters and trim
    return raw.replaceAll(RegExp(r'[^\x20-\x7E\s\u00C0-\u00FF]'), '').trim();
  }

  static String _normalize(String value) {
    var normalized = value.toLowerCase().trim();
    const replacements = {
      '\u00e1': 'a',
      '\u00e0': 'a',
      '\u00e2': 'a',
      '\u00e3': 'a',
      '\u00e4': 'a',
      '\u00e9': 'e',
      '\u00e8': 'e',
      '\u00ea': 'e',
      '\u00eb': 'e',
      '\u00ed': 'i',
      '\u00ec': 'i',
      '\u00ee': 'i',
      '\u00ef': 'i',
      '\u00f3': 'o',
      '\u00f2': 'o',
      '\u00f4': 'o',
      '\u00f5': 'o',
      '\u00f6': 'o',
      '\u00fa': 'u',
      '\u00f9': 'u',
      '\u00fb': 'u',
      '\u00fc': 'u',
      '\u00e7': 'c',
      '\u00f1': 'n',
    };
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    return normalized;
  }
}

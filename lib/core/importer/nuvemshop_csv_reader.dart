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

    if (headerIndex == -1) throw Exception('CSV sem conteúdo legível');

    final headerLine = allLines[headerIndex];
    debugPrint(
      'Linha de cabeçalho detectada (index $headerIndex): "$headerLine"',
    );

    final delimiter = _detectDelimiterForLine(headerLine);
    debugPrint('Delimitador detectado: "$delimiter"');

    // Re-join from header onwards to ensure multi-line fields (quotes) are handled correctly
    final contentFromHeader = allLines.sublist(headerIndex).join('\n');

    final rows = CsvToListConverter(
      fieldDelimiter: delimiter,
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(contentFromHeader).where((row) => row.isNotEmpty).toList();

    if (rows.isEmpty) {
      throw Exception('CSV vazio após processamento');
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
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
    };
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    return normalized;
  }
}

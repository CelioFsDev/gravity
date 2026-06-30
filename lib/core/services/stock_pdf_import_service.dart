import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:catalogo_ja/models/stock_pdf_row.dart';

class StockPdfImportResult {
  final StockPdfMetadata metadata;
  final List<StockPdfRow> rows;
  final List<String> unparsedLines;
  final int totalPdfQuantity;

  StockPdfImportResult({
    required this.metadata,
    required this.rows,
    required this.unparsedLines,
    required this.totalPdfQuantity,
  });
}

class StockPdfImportService {
  // Regex para código de produto
  // A: 106898.1001.G
  // B: 1069041040.P
  // C: 1069371020.38
  // D: 106887.1122.EGG
  // Grupo 1: Referência (sempre 6 dígitos)
  // Grupo 2: Código da cor (geralmente 4 dígitos)
  // Grupo 3: Tamanho (P, M, G, GG, EGG, 38, etc)
  static final RegExp _codeRegex = RegExp(r'^(\d{6})\.?(\d{4})\.([A-Z0-9]+)');
  
  // Regex final de linha completa:
  // Começa com código, tem descrição, termina com UN \d+
  static final RegExp _fullLineRegex = RegExp(r'^(\d{6}\.?\d{4}\.[A-Z0-9]+)\s+(.+?)\s+UN\s+(\d+)$');

  static final Map<String, String> _defaultColorMap = {
    '1001': 'PRETO',
    '1020': 'VERMELHO',
    '1040': 'AMARELO',
    '1050': 'ROSA',
    '1055': 'ROSE',
    '1060': 'BEGE',
    '1062': 'BEGE ESCURO',
    '1065': 'OFF WHITE',
    '1070': 'MARRON',
    '1071': 'MARRON CLARO',
    '1120': 'AZUL',
    '1122': 'AZUL ESCURO',
    '1140': 'LARANJA',
    '9990': 'L10',
    '9995': 'L20',
    '9998': 'L30',
  };

  static final List<String> _validSizes = [
    'P', 'M', 'G', 'GG', 'EGG', 'PP', 'XP', 'XG',
    '38', '40', '42', '44', '46', '48', '50', '52'
  ];

  Future<StockPdfImportResult> parsePdf(Uint8List pdfBytes) async {
    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    
    final List<StockPdfRow> rows = [];
    final List<String> unparsed = [];
    
    String? companyCode;
    String? companyName;
    DateTime? generationDate;
    DateTime? stockDate;
    String? stockType;
    String? purpose;
    String? status;
    int totalQuantity = 0;

    String currentPendingLine = '';
    
    for (int i = 0; i < document.pages.count; i++) {
      final String text = extractor.extractText(startPageIndex: i, endPageIndex: i);
      final List<String> lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

      for (String line in lines) {
        // Ignorar lixo
        if (_isIgnoredLine(line)) {
          continue;
        }

        // Metadados
        if (line.startsWith('Empresa:') && companyCode == null) {
          final parts = line.split(' ');
          if (parts.length > 1) companyCode = parts[1];
          continue;
        }
        if (line.contains('Empresa: ') && line.contains(' - ')) {
           companyName = line; // Pode conter "0178.0023 - BELADUE - TRINDADE"
           continue;
        }
        if (line.startsWith('Data de geração:')) {
           final dateStr = line.replaceAll('Data de geração:', '').trim();
           generationDate = _parseDate(dateStr);
           continue;
        }
        if (line.startsWith('Saldo em ')) {
           final dateStr = line.replaceAll('Saldo em ', '').trim();
           stockDate = _parseDate(dateStr);
           continue;
        }
        if (line.contains('UN ') && line.trim().startsWith('UN ') && line.length < 10 && currentPendingLine.isEmpty) {
           // Provável totalizador
           final parts = line.split(' ');
           if (parts.length == 2) {
             totalQuantity = int.tryParse(parts[1]) ?? totalQuantity;
           }
           continue;
        }

        // Lógica de Linha Quebrada e Parse
        if (_codeRegex.hasMatch(line) && currentPendingLine.isEmpty) {
          if (_fullLineRegex.hasMatch(line)) {
            // Linha única perfeita
            final row = _parseRow(line, i + 1);
            if (row != null) rows.add(row);
          } else {
            // Linha começou com código mas está quebrada
            currentPendingLine = line;
          }
        } else if (currentPendingLine.isNotEmpty) {
          // Juntar com linha anterior
          currentPendingLine += ' $line';
          if (currentPendingLine.contains(RegExp(r'UN\s+\d+$'))) {
            // Completou a linha
            final row = _parseRow(currentPendingLine, i + 1);
            if (row != null) {
              rows.add(row);
            } else {
              unparsed.add(currentPendingLine);
            }
            currentPendingLine = '';
          }
        } else {
          // Não é código, nem metadata, nem linha quebrada
          if (line.length > 10) unparsed.add(line);
        }
      }
    }
    
    document.dispose();

    final metadata = StockPdfMetadata(
      companyCode: companyCode,
      companyName: companyName,
      generationDate: generationDate,
      stockDate: stockDate,
      stockType: stockType,
      purpose: purpose,
      status: status,
      totalQuantity: totalQuantity,
    );

    return StockPdfImportResult(
      metadata: metadata,
      rows: rows,
      unparsedLines: unparsed,
      totalPdfQuantity: totalQuantity,
    );
  }

  bool _isIgnoredLine(String line) {
    final lower = line.toLowerCase();
    if (lower.startsWith('consulta geral de estoque')) return true;
    if (lower.startsWith('código descrição')) return true;
    if (lower.startsWith('cnpj:')) return true;
    if (lower.startsWith('página ')) return true;
    if (lower.startsWith('filtro:')) return true;
    if (lower.startsWith('usuário:')) return true;
    return false;
  }

  StockPdfRow? _parseRow(String line, int pageIndex) {
    final match = _fullLineRegex.firstMatch(line);
    if (match == null) return null;

    final rawCode = match.group(1)!;
    final descriptionWithPossibleColors = match.group(2)!.trim();
    final quantityStr = match.group(3)!;

    final codeMatch = _codeRegex.firstMatch(rawCode);
    if (codeMatch == null) return null;

    final reference = codeMatch.group(1)!;
    final colorCode = codeMatch.group(2)!;
    final size = codeMatch.group(3)!;
    final quantity = int.tryParse(quantityStr) ?? 0;

    String colorName = _defaultColorMap[colorCode] ?? '';
    StockPdfRowStatus status = StockPdfRowStatus.ok;
    
    if (colorName.isEmpty) {
       // Tentar extrair cor da descrição ex: SAIA CURTA .VERMELHO
       final splitDot = descriptionWithPossibleColors.split('.');
       if (splitDot.length > 1) {
         colorName = splitDot.last.trim();
       } else {
         status = StockPdfRowStatus.colorNotFound;
         colorName = 'Desconhecida ($colorCode)';
       }
    }

    if (!_validSizes.contains(size)) {
       status = StockPdfRowStatus.sizeNotFound;
    }

    return StockPdfRow(
      rawCode: rawCode,
      reference: reference,
      colorCode: colorCode,
      colorName: colorName,
      size: size,
      description: descriptionWithPossibleColors,
      unit: 'UN',
      quantity: quantity,
      page: pageIndex,
      rawText: line,
      status: status,
    );
  }

  DateTime? _parseDate(String dateStr) {
    try {
      if (dateStr.length == 10) {
        return DateFormat('dd/MM/yyyy').parse(dateStr);
      }
      return DateFormat('dd/MM/yyyy HH:mm:ss').parse(dateStr);
    } catch (e) {
      return null;
    }
  }
}

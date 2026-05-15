import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

class OrderPdfParserService {
  List<String> extractReferencesFromText(String text) {
    final regex = RegExp(r'\b\d{5,6}\b');

    final references = regex
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toSet()
        .toList();

    references.sort((a, b) {
      final numericCompare = int.parse(a).compareTo(int.parse(b));
      if (numericCompare != 0) return numericCompare;
      return a.compareTo(b);
    });

    return references;
  }
}

class OrderPdfTextExtractorService {
  String extractTextFromBytes(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }
}

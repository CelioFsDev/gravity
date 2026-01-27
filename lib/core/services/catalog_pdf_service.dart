import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:gravity/models/product.dart';
import 'package:intl/intl.dart';

class CatalogPdfService {
  static Future<Uint8List> generateCatalogPdf({
    required String catalogName,
    required List<Product> products,
  }) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  catalogName,
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  DateFormat('dd/MM/yyyy').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Wrap(
            spacing: 20,
            runSpacing: 20,
            children: products.map((product) {
              return pw.Container(
                width: (PdfPageFormat.a4.width - 64 - 20) / 2, // 2 items per row
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (product.images.isNotEmpty)
                      pw.Center(
                        child: _buildProductImage(
                          product.images[product.mainImageIndex],
                        ),
                      )
                    else
                      pw.Container(
                        height: 150,
                        width: 150,
                        color: PdfColors.grey100,
                        child: pw.Center(
                          child: pw.Text(
                            'Sem Foto',
                            style: const pw.TextStyle(color: PdfColors.grey),
                          ),
                        ),
                      ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      product.name,
                      maxLines: 2,
                      overflow: pw.TextOverflow.clip,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'REF: ${product.reference}',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          currencyFormat.format(product.retailPrice),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: PdfColors.blue800,
                          ),
                        ),
                      ],
                    ),
                    if (product.sizes.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Tamanhos: ${product.sizes.join(", ")}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildProductImage(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final image = pw.MemoryImage(file.readAsBytesSync());
        return pw.Container(
          height: 140,
          width: 140,
          child: pw.Image(image, fit: pw.BoxFit.contain),
        );
      }
    } catch (e) {
      // Ignora erro de imagem
    }
    return pw.SizedBox(height: 140);
  }
}

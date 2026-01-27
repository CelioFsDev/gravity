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
    int columnsCount = 1,
  }) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');

    // CADA PRODUTO = 1 PÁGINA COMPLETA
    for (final product in products) {
      final pixPrice = product.retailPrice * 0.95; // 5% desconto
      final installment = product.retailPrice / 2;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (context) => pw.Column(
            children: [
              // IMAGEM DO PRODUTO (60% da página)
              pw.Container(
                height: PdfPageFormat.a4.height * 0.6,
                width: double.infinity,
                child: product.images.isNotEmpty
                    ? pw.ClipRRect(
                        horizontalRadius: 12,
                        verticalRadius: 12,
                        child: _buildProductImage(
                          product.images[product.mainImageIndex],
                          width: double.infinity,
                          height: double.infinity,
                          fit: pw.BoxFit.cover,
                        ),
                      )
                    : pw.Container(
                        color: PdfColors.grey100,
                        child: pw.Center(
                          child: pw.Text(
                            'Sem Foto',
                            style: pw.TextStyle(
                              color: PdfColors.grey400,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
              ),

              // CONTEÚDO (40% da página)
              pw.Expanded(
                child: pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 32,
                  ),
                  color: PdfColors.white,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Selo promocional
                      if (product.isOnSale)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.green600,
                            borderRadius: pw.BorderRadius.circular(20),
                          ),
                          child: pw.Text(
                            '${product.saleDiscountPercent}% OFF NO CARRINHO',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                      if (product.isOnSale && product.saleDiscountPercent > 0)
                        pw.SizedBox(height: 12),

                      // NOME DO PRODUTO
                      pw.Text(
                        product.name.toUpperCase(),
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 28,
                          letterSpacing: 1.5,
                          color: PdfColors.grey900,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),

                      pw.SizedBox(height: 20),

                      // PREÇO PRINCIPAL
                      pw.Text(
                        currencyFormat.format(product.retailPrice),
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 48,
                          color: PdfColors.grey900,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),

                      pw.SizedBox(height: 8),

                      // Parcelamento
                      pw.Text(
                        '2x de ${currencyFormat.format(installment)} sem juros',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey600,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),

                      pw.SizedBox(height: 12),

                      // Preço Pix
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          '${currencyFormat.format(pixPrice)} com Pix (5% OFF)',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                      ),

                      pw.Spacer(),

                      // INFORMAÇÕES TÉCNICAS
                      pw.Container(
                        padding: const pw.EdgeInsets.all(16),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey50,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          children: [
                            // REF
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text(
                                  'REF: ',
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    color: PdfColors.grey600,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  product.reference,
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    color: PdfColors.grey900,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            // TAMANHOS
                            if (product.sizes.isNotEmpty) ...[
                              pw.SizedBox(height: 8),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    'TAMANHOS: ',
                                    style: pw.TextStyle(
                                      fontSize: 14,
                                      color: PdfColors.grey600,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.Text(
                                    product.sizes.join(' | '),
                                    style: pw.TextStyle(
                                      fontSize: 14,
                                      color: PdfColors.grey900,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // CORES
                            if (product.colors.isNotEmpty) ...[
                              pw.SizedBox(height: 8),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    'CORES: ',
                                    style: pw.TextStyle(
                                      fontSize: 14,
                                      color: PdfColors.grey600,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.Text(
                                    product.colors.join(' | '),
                                    style: pw.TextStyle(
                                      fontSize: 14,
                                      color: PdfColors.grey900,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 16),

                      // FOOTER - Nome do catálogo
                      pw.Text(
                        'Pedidos via WhatsApp | $catalogName',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey500,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildProductImage(
    String path, {
    double? height,
    double? width,
    pw.BoxFit fit = pw.BoxFit.contain,
  }) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final image = pw.MemoryImage(file.readAsBytesSync());
        return pw.Container(
          height: height,
          width: width,
          child: pw.Image(image, fit: fit),
        );
      }
    } catch (e) {
      // Ignora erro de imagem
    }
    return pw.SizedBox(height: height ?? 140, width: width ?? 140);
  }
}

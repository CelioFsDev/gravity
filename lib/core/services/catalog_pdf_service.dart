import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:gravity/models/catalog.dart';
import 'package:gravity/models/product.dart';
import 'package:intl/intl.dart';

class CatalogPdfService {
  static Future<Uint8List> generateCatalogPdf({
    required String catalogName,
    required List<Product> products,
    int columnsCount = 1,
    required CatalogMode mode,
    String? bannerImagePath,
  }) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');

    for (final product in products) {
      final displayPrice = product.priceForMode(mode.name);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  mode.label,
                  style: const pw.TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              if (bannerImagePath != null) ...[
                _buildBannerImage(bannerImagePath),
                pw.SizedBox(height: 18),
              ],
              _buildProductHero(product),
              pw.SizedBox(height: 18),
              _buildProductDetails(product, currencyFormat, displayPrice),
              if (product.images.length > 1) ...[
                pw.SizedBox(height: 12),
                _buildAdditionalImages(product),
              ],
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Text(
                'Pedidos via WhatsApp | $catalogName',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Nova coleção cápsula ${DateTime.now().year}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey500,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildBannerImage(String path) {
    return pw.ClipRRect(
      horizontalRadius: 16,
      verticalRadius: 16,
      child: pw.Container(
        height: 120,
        color: PdfColors.grey100,
        child: _buildProductImage(
          path,
          fit: pw.BoxFit.cover,
          height: 120,
          width: double.infinity,
        ),
      ),
    );
  }

  static pw.Widget _buildProductHero(Product product) {
    final imagePath = product.images.isNotEmpty
        ? product.images[product.mainImageIndex.clamp(
            0,
            product.images.length - 1,
          )]
        : null;
    return pw.ClipRRect(
      horizontalRadius: 20,
      verticalRadius: 20,
      child: pw.Container(
        height: PdfPageFormat.a4.height * 0.40,
        color: PdfColors.grey100,
        child: imagePath != null
            ? _buildProductImage(
                imagePath,
                fit: pw.BoxFit.cover,
                height: PdfPageFormat.a4.height * 0.40,
                width: double.infinity,
              )
            : pw.Center(
                child: pw.Text(
                  'Sem Foto',
                  style: pw.TextStyle(fontSize: 24, color: PdfColors.grey400),
                ),
              ),
      ),
    );
  }

  static pw.Widget _buildProductDetails(
    Product product,
    NumberFormat currencyFormat,
    double displayPrice,
  ) {
    final sizes = product.sizes.isNotEmpty
        ? product.sizes.map((s) => s.toUpperCase()).join(' / ')
        : 'Único';
    final colorDots = product.colors.isNotEmpty
        ? _buildColorDots(product.colors)
        : <pw.Widget>[];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                product.name.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2,
                  color: PdfColors.grey900,
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'REF: ${product.reference}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              currencyFormat.format(displayPrice),
              style: pw.TextStyle(
                fontSize: 40,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
            pw.Spacer(),
            if (colorDots.isNotEmpty)
              pw.Row(children: colorDots)
            else
              pw.Text(
                'sem cores',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Text(
              'Tamanhos:',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Text(
              sizes,
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey900),
            ),
          ],
        ),
      ],
    );
  }

  static List<pw.Widget> _buildColorDots(List<String> colors) {
    return colors.take(4).map((color) {
      final normalized = color.trim().toLowerCase();
      return pw.Container(
        width: 14,
        height: 14,
        margin: const pw.EdgeInsets.only(left: 6),
        decoration: pw.BoxDecoration(
          color: _colorFromName(normalized),
          borderRadius: pw.BorderRadius.circular(7),
          border: pw.Border.all(color: PdfColors.grey400),
        ),
      );
    }).toList();
  }

  static PdfColor _colorFromName(String name) {
    if (name.contains('azul')) return PdfColors.blue700;
    if (name.contains('rosa')) return PdfColors.pink400;
    if (name.contains('vermelho')) return PdfColors.red400;
    if (name.contains('marrom')) return PdfColors.brown500;
    if (name.contains('preto')) return PdfColors.black;
    if (name.contains('branco')) return PdfColors.grey200;
    if (name.contains('verde')) return PdfColors.green600;
    if (name.contains('amarelo')) return PdfColors.yellow600;
    if (name.contains('cinza')) return PdfColors.grey500;
    if (name.contains('bege')) return PdfColors.brown200;
    if (name.contains('lilas') || name.contains('lilá')) {
      return PdfColors.purple300;
    }
    return PdfColors.grey400;
  }

  static pw.Widget _buildAdditionalImages(Product product) {
    final thumbnails = product.images
        .asMap()
        .entries
        .where((entry) => entry.key != product.mainImageIndex)
        .take(2)
        .toList();

    if (thumbnails.isEmpty) return pw.SizedBox();

    return pw.Row(
      children: List.generate(thumbnails.length, (index) {
        final entry = thumbnails[index];
        final isLast = index == thumbnails.length - 1;
        return pw.Expanded(
          child: pw.ClipRRect(
            horizontalRadius: 12,
            verticalRadius: 12,
            child: pw.Container(
              margin: pw.EdgeInsets.only(right: isLast ? 0 : 8),
              height: 80,
              color: PdfColors.grey100,
              child: _buildProductImage(
                entry.value,
                fit: pw.BoxFit.cover,
                height: 80,
              ),
            ),
          ),
        );
      }),
    );
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
    } catch (_) {
      // Ignora erro de imagem
    }
    return pw.SizedBox(height: height ?? 140, width: width ?? 140);
  }
}

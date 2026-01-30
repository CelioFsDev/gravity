import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:gravity/models/catalog.dart';
import 'package:gravity/models/category.dart';
import 'package:gravity/models/product.dart';
import 'package:intl/intl.dart';

class CatalogPdfService {
  static const PdfColor _colorTextPrimary = PdfColors.black;
  static const PdfColor _colorPriceGreen = PdfColor(0.12, 0.42, 0.29);
  static const PdfColor _colorMuted = PdfColor(0.45, 0.45, 0.45);
  static const PdfColor _colorImageBg = PdfColor(0.953, 0.953, 0.953);
  static const PdfColor _colorSizePillBg = PdfColor(0.929, 0.929, 0.929);
  static const PdfPageFormat _defaultMobileFormat = PdfPageFormat(360, 640);
  static Future<Uint8List> generateCatalogPdf({
    required String catalogName,
    required List<Product> products,
    int columnsCount = 1,
    required CatalogMode mode,
    String? bannerImagePath,
    PdfPageFormat pageFormat = _defaultMobileFormat,
    CollectionCover? collectionCover,
    String? collectionName,
    String defaultSubtitle = 'SELE\u00c7\u00c3O DE PRODUTOS',
  }) async {
    // Parameters kept for API compatibility.
    final _ = catalogName;
    final __ = columnsCount;
    final ___ = bannerImagePath;

    final pdf = pw.Document();
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');

    _addCoverPage(
      pdf,
      pageFormat,
      collectionCover,
      collectionName: collectionName,
      defaultSubtitle: defaultSubtitle,
    );

    for (final product in products) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          build: (context) => _buildProductPage(
            product,
            mode,
            currencyFormat,
            pageFormat,
            collectionName: collectionName,
            defaultSubtitle: defaultSubtitle,
          ),
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildProductPage(
    Product product,
    CatalogMode mode,
    NumberFormat currencyFormat,
    PdfPageFormat pageFormat, {
    String? collectionName,
    String defaultSubtitle = 'SELEÇÃO DE PRODUTOS',
  }) {
    final displayPrice = product.priceForMode(mode.name);
    final heroPath = product.images.isNotEmpty
        ? product.images[product.mainImageIndex.clamp(
            0,
            product.images.length - 1,
          )]
        : null;
    final thumb1 = product.images.length > 1 ? product.images[1] : null;
    final thumb2 = product.images.length > 2 ? product.images[2] : null;

    final colors = _extractColorNames(product);
    final sizesText = _extractSizesText(product);
    final footerText =
        (collectionName != null && collectionName.trim().isNotEmpty)
            ? collectionName.trim()
            : defaultSubtitle;
    final availableWidth = pageFormat.width - 36;
    final mainPhotoHeight =
        _calcMainPhotoHeight(availableWidth, pageFormat.height);
    final refStyle = pw.TextStyle(
      fontSize: 12,
      color: _colorMuted,
      fontWeight: pw.FontWeight.normal,
    );

    final formattedPrice = currencyFormat.format(displayPrice);
    final originalPrice =
        (product.promoEnabled && product.promoPercent > 0)
            ? (mode == CatalogMode.atacado
                ? product.priceWholesale
                : product.priceRetail)
            : null;
    final showPromo = originalPrice != null && originalPrice > displayPrice;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            mode.label,
            style: pw.TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              color: _colorMuted,
            ),
          ),
        ),
        pw.SizedBox(height: 12),
        if (heroPath != null)
          _buildMainPhotoBox(
            heroPath,
            width: availableWidth,
            height: mainPhotoHeight,
            radius: 20,
          )
        else
          _buildImagePlaceholder(
            height: mainPhotoHeight,
            width: availableWidth,
            radius: 20,
          ),
        pw.SizedBox(height: 14),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                product.name.toUpperCase(),
                maxLines: 2,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.1,
                  color: _colorTextPrimary,
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'REF: ${product.reference}',
              style: refStyle,
              textAlign: pw.TextAlign.right,
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (showPromo)
                  pw.Text(
                    currencyFormat.format(originalPrice),
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: _colorMuted,
                      decoration: pw.TextDecoration.lineThrough,
                    ),
                  ),
                pw.Text(
                  formattedPrice,
                  style: pw.TextStyle(
                    fontSize: 21,
                    fontWeight: pw.FontWeight.normal,
                    color: _colorPriceGreen,
                  ),
                ),
              ],
            ),
            pw.Spacer(),
            if (colors.isNotEmpty)
              pw.Row(children: _buildColorDots(colors))
            else
              pw.Text(
                'sem cores',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: _colorMuted,
                ),
              ),
            pw.SizedBox(width: 10),
            _buildSizePill(sizesText),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            pw.Expanded(
              child: thumb1 != null
                  ? _buildImageBox(
                      thumb1,
                      height: pageFormat.height * 0.22,
                      radius: 12,
                    )
                  : _buildImagePlaceholder(
                      height: pageFormat.height * 0.22,
                      radius: 12,
                    ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: thumb2 != null
                  ? _buildImageBox(
                      thumb2,
                      height: pageFormat.height * 0.22,
                      radius: 12,
                    )
                  : (heroPath != null
                      ? _buildImageBox(
                          heroPath,
                          height: pageFormat.height * 0.22,
                          radius: 12,
                        )
                      : _buildImagePlaceholder(
                          height: pageFormat.height * 0.22,
                          radius: 12,
                        )),
            ),
          ],
        ),
        pw.Spacer(),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 6),
        pw.Text(
          footerText.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 11,
            letterSpacing: 1.4,
            color: _colorMuted,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  static List<pw.Widget> _buildColorDots(List<String> colors) {
    return colors.take(5).map((color) {
      final normalized = color.trim().toLowerCase();
        return pw.Container(
          width: 16,
          height: 16,
          margin: const pw.EdgeInsets.only(left: 6),
          decoration: pw.BoxDecoration(
            color: _colorFromName(normalized),
            borderRadius: pw.BorderRadius.circular(8),
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

  static String _extractSizesText(Product product) {
    final sizes = <String>{};
    for (final variant in product.variants) {
      for (final entry in variant.attributes.entries) {
        final key = entry.key.toLowerCase();
        if (key == 'tam' || key == 'size') {
          final val = entry.value.trim();
          if (val.isNotEmpty) sizes.add(val.toUpperCase());
        }
      }
    }
    if (sizes.isEmpty) {
      sizes.addAll(product.sizes.map((s) => s.toUpperCase()));
    }
    if (sizes.isEmpty) return 'ÚNICO';
    return sizes.join('/');
  }

  static List<String> _extractColorNames(Product product) {
    final colors = <String>{};
    for (final variant in product.variants) {
      for (final entry in variant.attributes.entries) {
        final key = entry.key.toLowerCase();
        if (key == 'cor' || key == 'color') {
          final val = entry.value.trim();
          if (val.isNotEmpty) colors.add(val);
        }
      }
    }
    if (colors.isEmpty) {
      colors.addAll(product.colors.map((c) => c.trim()));
    }
    return colors.toList();
  }

  static pw.Widget _buildImageBox(
    String path, {
    required double height,
    double? width,
    double radius = 0,
  }) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final image = pw.MemoryImage(file.readAsBytesSync());
        return pw.Container(
          height: height,
          width: width,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: _colorImageBg,
            borderRadius: pw.BorderRadius.circular(radius),
          ),
          child: pw.ClipRRect(
            horizontalRadius: radius,
            verticalRadius: radius,
            child: pw.FittedBox(
              fit: pw.BoxFit.contain,
              child: pw.Image(image),
            ),
          ),
        );
      }
    } catch (_) {
      // Ignora erro de imagem
    }
    return _buildImagePlaceholder(height: height, width: width, radius: radius);
  }

  static pw.Widget _buildMainPhotoBox(
    String path, {
    required double width,
    required double height,
    double radius = 0,
  }) {
    return _buildImageBox(
      path,
      height: height,
      width: width,
      radius: radius,
    );
  }

  static pw.Widget _buildImagePlaceholder({
    required double height,
    double? width,
    double radius = 0,
  }) {
    return pw.Container(
      height: height,
      width: width,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: _colorImageBg,
        borderRadius: pw.BorderRadius.circular(radius),
      ),
      child: pw.Text('Sem Foto', style: pw.TextStyle(color: _colorMuted)),
    );
  }

  static void _addCoverPage(
    pw.Document pdf,
    PdfPageFormat pageFormat,
    CollectionCover? cover, {
    String? collectionName,
    String defaultSubtitle = 'SELE\u00c7\u00c3O DE PRODUTOS',
  }) {
    final resolved = cover ??
        CollectionCover(
          mode: CollectionCoverMode.template,
          title: CollectionCover.defaultTitle,
          brand: CollectionCover.defaultBrand,
          subtitle: collectionName ?? defaultSubtitle,
        );

    final title = (resolved.title ?? '').trim().isNotEmpty
        ? resolved.title!.trim()
        : CollectionCover.defaultTitle;
    final brand = (resolved.brand ?? '').trim().isNotEmpty
        ? resolved.brand!.trim()
        : CollectionCover.defaultBrand;
    final subtitle = (resolved.subtitle ?? '').trim().isNotEmpty
        ? resolved.subtitle!.trim()
        : (collectionName ?? defaultSubtitle);

    if (resolved.mode == CollectionCoverMode.image &&
        (resolved.coverImagePath != null ||
            resolved.bannerImagePath != null ||
            resolved.heroImagePath != null)) {
      final bannerPath = resolved.bannerImagePath ?? resolved.coverImagePath;
      final heroPath = resolved.heroImagePath;
      final bannerHeight = pageFormat.height * 0.18;
      final footerHeight = pageFormat.height * 0.12;
      final heroHeight = pageFormat.height - bannerHeight - footerHeight - 36;
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (bannerPath != null)
                _buildImageBox(
                  bannerPath,
                  height: bannerHeight,
                  width: pageFormat.width - 36,
                  radius: 12,
                )
              else
                pw.SizedBox(height: bannerHeight),
              pw.SizedBox(height: 12),
              if (heroPath != null)
                _buildImageBox(
                  heroPath,
                  height: heroHeight,
                  width: pageFormat.width - 36,
                  radius: 18,
                )
              else
                pw.SizedBox(height: heroHeight),
              pw.Spacer(),
              pw.Text(
                subtitle.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.6,
                  color: _colorMuted,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
            ],
          ),
        ),
      );
      return;
    }

    final background =
        _pdfColorFromInt(resolved.backgroundColor) ?? PdfColors.grey900;
    final overlayOpacity = resolved.overlayOpacity ?? 0.0;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Container(
          color: background,
          child: pw.Stack(
            children: [
              if (overlayOpacity > 0)
                pw.Container(
                  color: PdfColor(0, 0, 0, overlayOpacity),
                ),
              pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      title.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 44,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2,
                        color: PdfColors.white,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      brand.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 20,
                        letterSpacing: 4,
                        color: PdfColors.white,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 16),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.white),
                      ),
                      child: pw.Text(
                        subtitle.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 14,
                          letterSpacing: 2,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static PdfColor? _pdfColorFromInt(int? colorValue) {
    if (colorValue == null) return null;
    final a = ((colorValue >> 24) & 0xFF) / 255.0;
    final r = ((colorValue >> 16) & 0xFF) / 255.0;
    final g = ((colorValue >> 8) & 0xFF) / 255.0;
    final b = (colorValue & 0xFF) / 255.0;
    return PdfColor(r, g, b, a);
  }

  static pw.Widget _buildSizePill(String sizesText) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _colorSizePillBg,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(
        sizesText,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: _colorMuted,
        ),
      ),
    );
  }

  static double _calcMainPhotoHeight(double width, double pageHeight) {
    final ratioHeight = width * 4 / 3;
    final maxHeight = pageHeight * 0.5;
    return ratioHeight > maxHeight ? maxHeight : ratioHeight;
  }
}



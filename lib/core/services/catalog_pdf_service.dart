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
    bool includeCover = true,
  }) async {
    // Parameters kept for API compatibility.
    final _ = catalogName;
    final __ = columnsCount;
    final ___ = bannerImagePath;

    final pdf = pw.Document();
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');

    if (includeCover) {
      _addCoverPage(
        pdf,
        pageFormat,
        collectionCover,
        collectionName: collectionName,
        defaultSubtitle: defaultSubtitle,
        catalogBannerPath: bannerImagePath,
      );
    }

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
    final primaryPhoto = _selectPrimaryPhoto(product.photos);
    final heroPath = primaryPhoto?.path;
    final activeColor = _selectActiveColor(product.photos, primaryPhoto);
    final miniPhotos = _selectMiniPhotos(
      product.photos,
      activeColor,
      primaryPhoto,
    );

    final colors = _extractColorNames(product);
    final sizesText = _extractSizesText(product);
    final footerText =
        (collectionName != null && collectionName.trim().isNotEmpty)
        ? collectionName.trim()
        : defaultSubtitle;
    final availableWidth = pageFormat.width - 36;
    final mainPhotoHeight = _calcMainPhotoHeight(
      availableWidth,
      pageFormat.height,
    );
    final refStyle = pw.TextStyle(
      fontSize: 12,
      color: _colorMuted,
      fontWeight: pw.FontWeight.normal,
    );

    final formattedPrice = currencyFormat.format(displayPrice);
    final originalPrice = (product.promoEnabled && product.promoPercent > 0)
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
        pw.Stack(
          children: [
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
            if (product.promoEnabled && product.promoPercent > 0)
              pw.Positioned(
                top: 12,
                right: 12,
                child: _buildPromoBadge(product.promoPercent),
              ),
          ],
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
              pw.Row(children: _buildColorDots(colors, activeColor))
            else
              pw.Text(
                'sem cores',
                style: pw.TextStyle(fontSize: 12, color: _colorMuted),
              ),
            pw.SizedBox(width: 10),
            _buildSizePill(sizesText),
          ],
        ),
        pw.SizedBox(height: 14),
        if (miniPhotos.isNotEmpty)
          _buildMiniPhotosRow(
            miniPhotos,
            height: pageFormat.height * 0.22,
            width: availableWidth,
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

  static List<pw.Widget> _buildColorDots(
    List<String> colors,
    String? activeColor,
  ) {
    return colors.take(5).map((color) {
      final normalized = color.trim().toLowerCase();
      final isActive =
          activeColor != null && normalized == activeColor.trim().toLowerCase();
      return pw.Container(
        width: 16,
        height: 16,
        margin: const pw.EdgeInsets.only(left: 6),
        decoration: pw.BoxDecoration(
          color: _colorFromName(normalized),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(
            color: isActive ? PdfColors.black : PdfColors.grey400,
            width: isActive ? 1.4 : 1,
          ),
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
    for (final photo in product.photos) {
      final key = photo.colorKey?.trim();
      if (key != null && key.isNotEmpty) {
        colors.add(key);
      }
    }
    if (colors.isNotEmpty) return colors.toList();

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

  static ProductPhoto? _selectPrimaryPhoto(List<ProductPhoto> photos) {
    if (photos.isEmpty) return null;
    for (final photo in photos) {
      if (photo.isPrimary) return photo;
    }
    for (final photo in photos) {
      final key = photo.colorKey?.trim();
      if (key != null && key.isNotEmpty) return photo;
    }
    return photos.first;
  }

  static String? _selectActiveColor(
    List<ProductPhoto> photos,
    ProductPhoto? primary,
  ) {
    if (photos.isEmpty) return null;
    final primaryColor = primary?.colorKey?.trim();
    if (primaryColor != null && primaryColor.isNotEmpty) {
      return primaryColor;
    }
    for (final photo in photos) {
      final key = photo.colorKey?.trim();
      if (key != null && key.isNotEmpty) return key;
    }
    return null;
  }

  static List<ProductPhoto> _selectMiniPhotos(
    List<ProductPhoto> photos,
    String? activeColor,
    ProductPhoto? primary,
  ) {
    if (photos.isEmpty) return const [];
    final normalizedActive = activeColor?.toLowerCase();
    final primaryPath = primary?.path;

    List<ProductPhoto> pick(Iterable<ProductPhoto> source) {
      final filtered = source
          .where((p) => p.path.isNotEmpty && p.path != primaryPath)
          .toList();
      filtered.sort((a, b) {
        final aScore = a.isPrimary ? 1 : 0;
        final bScore = b.isPrimary ? 1 : 0;
        return bScore.compareTo(aScore);
      });
      return filtered;
    }

    final ordered = <ProductPhoto>[];
    if (normalizedActive != null) {
      ordered.addAll(
        pick(
          photos.where((p) => p.colorKey?.toLowerCase() == normalizedActive),
        ),
      );
    }
    if (ordered.length < 3) {
      ordered.addAll(
        pick(photos.where((p) => p.colorKey == null || p.colorKey!.isEmpty)),
      );
    }
    if (ordered.length < 3) {
      ordered.addAll(pick(photos));
    }

    final unique = <String>{};
    final result = <ProductPhoto>[];
    for (final photo in ordered) {
      if (unique.add(photo.path)) {
        result.add(photo);
      }
      if (result.length == 3) break;
    }
    return result;
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
            child: pw.FittedBox(fit: pw.BoxFit.contain, child: pw.Image(image)),
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
    return _buildImageBox(path, height: height, width: width, radius: radius);
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
    String? catalogBannerPath,
  }) {
    final resolved =
        cover ??
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

    final coverOnlyPath = resolved.coverImagePath?.trim();
    if (coverOnlyPath != null && coverOnlyPath.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Container(
            color: PdfColors.white,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            child: pw.Center(
              child: _buildImageBox(
                coverOnlyPath,
                height: pageFormat.height - 36,
                width: pageFormat.width - 36,
                radius: 18,
              ),
            ),
          ),
        ),
      );
      return;
    }

    if (resolved.mode == CollectionCoverMode.image) {
      final headerPath =
          resolved.coverHeaderImagePath ??
          resolved.bannerImagePath ??
          catalogBannerPath;
      final mainPath =
          resolved.coverMainImagePath ??
          resolved.heroImagePath ??
          resolved.coverImagePath;

      if (headerPath != null || mainPath != null) {
        final availableHeight = pageFormat.height - 36;
        final headerHeight = headerPath != null ? availableHeight * 0.16 : 0.0;
        final mainHeight = mainPath != null
            ? (headerPath != null ? availableHeight * 0.76 : availableHeight)
            : 0.0;

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Container(
              color: PdfColors.white,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  if (headerPath != null) ...[
                    _buildImageBox(
                      headerPath,
                      height: headerHeight,
                      width: pageFormat.width - 36,
                      radius: 12,
                    ),
                    pw.SizedBox(height: 12),
                  ],
                  if (mainPath != null) ...[
                    pw.Spacer(),
                    _buildImageBox(
                      mainPath,
                      height: mainHeight,
                      width: pageFormat.width - 36,
                      radius: 18,
                    ),
                    pw.Spacer(),
                  ],
                  if (mainPath == null && headerPath == null)
                    pw.Center(child: pw.Text('Sem imagens de capa')),
                ],
              ),
            ),
          ),
        );
        return;
      }
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
                pw.Container(color: PdfColor(0, 0, 0, overlayOpacity)),
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

  static pw.Widget _buildPromoBadge(double percent) {
    final value = percent.round().clamp(1, 100);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.green600,
        borderRadius: pw.BorderRadius.circular(20),
        boxShadow: [
          pw.BoxShadow(
            blurRadius: 6,
            color: PdfColors.orange,
            offset: const PdfPoint(0, 2),
          ),
        ],
      ),
      child: pw.Text(
        '-$value%',
        style: pw.TextStyle(
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static pw.Widget _buildMiniPhotosRow(
    List<ProductPhoto> photos, {
    required double height,
    required double width,
  }) {
    final count = photos.length >= 3 ? 3 : photos.length;
    if (count <= 0) return pw.SizedBox.shrink();
    final gap = 10.0;
    final totalGap = gap * (count - 1);
    final itemWidth = (width - totalGap) / count;

    return pw.Row(
      children: List.generate(count, (index) {
        final photo = photos[index];
        final widget = _buildImageBox(
          photo.path,
          height: height,
          width: itemWidth,
          radius: 12,
        );
        if (index == count - 1) return widget;
        return pw.Row(
          children: [
            widget,
            pw.SizedBox(width: gap),
          ],
        );
      }),
    );
  }
}

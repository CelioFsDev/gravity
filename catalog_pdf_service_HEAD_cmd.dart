import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

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
    Map<String, Category>? collectionsMap,
    String? mainCoverCollectionId,
    bool showPrice = true,
  }) async {
    // Parameters kept for API compatibility.
    final _ = catalogName;
    final _ = columnsCount;
    final _ = bannerImagePath;

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

    String? currentCollectionId;

    for (final product in products) {
      // Check for collection change
      if (collectionsMap != null) {
        String? prodCollectionId;
        for (final catId in product.categoryIds) {
          if (collectionsMap.containsKey(catId)) {
            prodCollectionId = catId;
            break;
          }
        }

        if (prodCollectionId != null &&
            prodCollectionId != currentCollectionId) {
          final isDuplicateCover =
              includeCover &&
              mainCoverCollectionId != null &&
              prodCollectionId == mainCoverCollectionId &&
              currentCollectionId == null;

          if (!isDuplicateCover) {
            final collection = collectionsMap[prodCollectionId]!;
            _addCollectionOpeningPage(pdf, pageFormat, collection);
          }
          currentCollectionId = prodCollectionId;
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          build: (context) => _buildProductPage(
            product,
            mode,
            currencyFormat,
            pageFormat,
            collectionName: collectionName, // This might be stale if mixed?
            // If mixed collections, maybe we shouldn't pass collectionName to footer?
            // Or pass the current collection name?
            // For now keeping original behavior or passing current name if available
            defaultSubtitle: defaultSubtitle,
            showPrice: showPrice,
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
    bool showPrice = true,
  }) {
    final displayPrice = product.priceForMode(mode.name);
    final primaryPhoto = _selectPrimaryPhoto(product.photos);
    final heroPath = primaryPhoto?.path;

    // Filter unique photos per color for the variants section
    final colorVariants = <String, String>{};
    for (final photo in product.photos) {
      final color = photo.colorKey?.trim();
      if (color != null &&
          color.isNotEmpty &&
          !colorVariants.containsKey(color)) {
        if (photo.path != heroPath) {
          colorVariants[color] = photo.path;
        }
      }
    }

    final hasVariants = colorVariants.isNotEmpty;
    final sizesText = _extractSizesText(product);
    final topHeaderText =
        (collectionName != null && collectionName.trim().isNotEmpty)
        ? collectionName.trim()
        : defaultSubtitle;

    final availableWidth = pageFormat.width - 36;

    // Dynamic height: expand photo if no variants are present
    final mainPhotoHeight = hasVariants
        ? pageFormat.height * 0.72
        : pageFormat.height * 0.82;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Top Header
        pw.Container(
          height: 30,
          alignment: pw.Alignment.center, // Centered like screenshot
          child: pw.Text(
            topHeaderText.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: pw.FontWeight.normal,
              color: PdfColors.black,
            ),
          ),
        ),
        // Main Photo
        if (heroPath != null)
          _buildMainPhotoBox(
            heroPath,
            width: availableWidth,
            height: mainPhotoHeight,
            radius: 0, // Screenshot shows sharp edges for main photo
          )
        else
          _buildImagePlaceholder(
            height: mainPhotoHeight,
            width: availableWidth,
            radius: 0,
          ),
        pw.SizedBox(height: 18),
        // Bottom Content
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left Side: Name, Sizes, Ref
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    product.name.toUpperCase(),
                    maxLines: 2,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5,
                      lineSpacing: 1.2,
                      color: _colorTextPrimary,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      _buildSizePill(sizesText),
                      pw.SizedBox(width: 15),
                      pw.Text(
                        'REF: ${product.reference}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.black,
                          fontWeight: pw.FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  if (showPrice) ...[
                    pw.SizedBox(height: 10),
                    pw.Text(
                      currencyFormat.format(displayPrice),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _colorPriceGreen,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasVariants) ...[
              pw.SizedBox(width: 12),
              // Right Side: Variant Thumbnails
              pw.Wrap(
                spacing: 8,
                children: colorVariants.entries.take(3).map((entry) {
                  return pw.Column(
                    children: [
                      _buildImageBox(
                        entry.value,
                        width: 48,
                        height: 60,
                        radius: 6,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        entry.key.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ],
    );
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

  static pw.Widget _buildImageBox(
    String path, {
    required double height,
    double? width,
    double radius = 0,
  }) {
    try {
      if (path.startsWith('data:')) {
        final commaIndex = path.indexOf(',');
        if (commaIndex != -1) {
          final base64Data = path.substring(commaIndex + 1);
          final bytes = base64Decode(base64Data);
          final image = pw.MemoryImage(bytes);
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
      }
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
      final miniPath = resolved.coverMiniPath ?? resolved.coverImagePath;
      final pagePath = resolved.coverPagePath;

      if (miniPath != null) {
        final availableWidth = pageFormat.width - 36;
        final miniHeight = availableWidth / (1365 / 420);

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Container(
              color: PdfColors.white,
              padding: const pw.EdgeInsets.all(18),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildImageBox(
                    miniPath,
                    height: miniHeight,
                    width: availableWidth,
                    radius: 12,
                  ),
                  if (pagePath != null) ...[
                    pw.SizedBox(height: 12),
                    pw.Expanded(
                      child: _buildImageBox(
                        pagePath,
                        height: pageFormat.height, // Fits in Expanded
                        width: availableWidth,
                        radius: 18,
                      ),
                    ),
                  ],
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

  static void _addCollectionOpeningPage(
    pw.Document pdf,
    PdfPageFormat pageFormat,
    Category collection,
  ) {
    // Priority: Images
    final cover = collection.cover;
    if (cover == null) return;

    final miniPath = cover.coverMiniPath ?? cover.coverImagePath;
    final pagePath = cover.coverPagePath;

    if (miniPath == null || miniPath.isEmpty) return;

    final availableWidth = pageFormat.width - 36;
    final miniHeight = availableWidth / (1365 / 420);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Container(
          color: PdfColors.white,
          padding: const pw.EdgeInsets.all(18),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildImageBox(
                miniPath,
                height: miniHeight,
                width: availableWidth,
                radius: 12,
              ),
              if (pagePath != null && pagePath.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Expanded(
                  child: _buildImageBox(
                    pagePath,
                    height: pageFormat.height,
                    width: availableWidth,
                    radius: 18,
                  ),
                ),
              ] else ...[
                // If no editorial image, maybe show collection name centered?
                pw.Spacer(),
                pw.Center(
                  child: pw.Text(
                    collection.safeName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 24,
                      color: _colorMuted,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                pw.Spacer(),
              ],
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: _colorSizePillBg,
        borderRadius: pw.BorderRadius.circular(
          2,
        ), // Rectangular with slight radius
      ),
      child: pw.Text(
        sizesText,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
    );
  }
}

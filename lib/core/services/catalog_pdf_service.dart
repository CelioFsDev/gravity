import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:intl/intl.dart';

class CatalogPdfService {
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
          margin: const pw.EdgeInsets.symmetric(
            vertical: 18,
          ), // No horizontal margin for full-bleed
          build: (context) => _buildProductPage(
            product,
            mode,
            currencyFormat,
            pageFormat,
            collectionName: collectionName,
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
    String defaultSubtitle = 'SELE\u00c7\u00c3O DE PRODUTOS',
    bool showPrice = true,
  }) {
    final displayPrice = product.priceForMode(mode.name);
    final primaryPhoto = _selectPrimaryPhoto(product.photos);
    final heroPath = primaryPhoto?.path;
    final normalizedHeroPath = heroPath?.replaceAll('\\', '/');

    // Filter unique photos for the variants section (max 4)
    final colorVariants = <String, String>{};

    // 1. Collect photos that have specific colors assigned
    for (final photo in product.photos) {
      final normPath = photo.path.replaceAll('\\', '/');
      if (normPath == normalizedHeroPath) continue;
      final color = photo.colorKey?.trim().toUpperCase();
      if (color != null &&
          color.isNotEmpty &&
          !colorVariants.containsKey(color)) {
        colorVariants[color] = photo.path;
      }
      if (colorVariants.length >= 4) break;
    }

    // 2. Fallback: If less than 4, add other photos linked as Cor
    if (colorVariants.length < 4) {
      int detailCounter = 1;
      for (final photo in product.photos) {
        final normPath = photo.path.replaceAll('\\', '/');
        if (normPath == normalizedHeroPath) continue;
        if (colorVariants.values.any(
          (v) => v.replaceAll('\\', '/') == normPath,
        )) {
          continue;
        }

        String label = (photo.colorKey?.trim().isNotEmpty == true)
            ? photo.colorKey!.trim().toUpperCase()
            : 'COR $detailCounter';
        colorVariants[label] = photo.path;
        detailCounter++;
        if (colorVariants.length >= 4) break;
      }
    }

    final sizesText = _extractSizesText(product);
    final topHeaderText =
        (collectionName != null && collectionName.trim().isNotEmpty)
        ? collectionName.trim()
        : defaultSubtitle;

    final availableWidth = pageFormat.width - 36;
    final availableHeight = pageFormat.height - 36;

    // Proporções para garantir que a foto principal domine a parte superior
    final bottomContentHeight = 175.0; // Altura fixa para a área de informações
    final topHeaderHeight = 35.0; // Espaço para o nome da coleção no topo
    final spacing = 15.0; // Respiro entre foto e texto
    final mainPhotoHeight =
        availableHeight - topHeaderHeight - bottomContentHeight - spacing;

    final variantEntries = colorVariants.entries.toList();
    final hasSpecial4Layout = variantEntries.length == 4;
    final topVariants = hasSpecial4Layout
        ? variantEntries.sublist(0, 2)
        : <MapEntry<String, String>>[];
    final bottomVariants = hasSpecial4Layout
        ? variantEntries.sublist(2)
        : variantEntries;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header
          pw.Container(
            height: topHeaderHeight,
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              topHeaderText.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 11,
                letterSpacing: 3,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          // 2. Main Photo Section
          if (hasSpecial4Layout)
            pw.Container(
              height: mainPhotoHeight,
              width: availableWidth,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Expanded(
                    child: heroPath != null
                        ? _buildMainPhotoBox(
                            heroPath,
                            height: mainPhotoHeight,
                            radius: 0,
                          )
                        : _buildImagePlaceholder(
                            height: mainPhotoHeight,
                            width: availableWidth,
                            radius: 0,
                          ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Container(
                    width: 85, // Enforced width for side thumbs
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: topVariants
                          .map(
                            (v) => pw.Expanded(
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: _buildSwatchThumb(
                                  v.key,
                                  v.value,
                                  width: 85,
                                  expand: true,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            )
          else
            // Original Main Photo
            pw.Container(
              height: mainPhotoHeight,
              width: availableWidth,
              child: heroPath != null
                  ? _buildMainPhotoBox(
                      heroPath,
                      width: availableWidth,
                      height: mainPhotoHeight,
                      radius: 0,
                    )
                  : _buildImagePlaceholder(
                      height: mainPhotoHeight,
                      width: availableWidth,
                      radius: 0,
                    ),
            ),
          pw.SizedBox(height: spacing),
          // 3. Bottom Content
          pw.Container(
            height: bottomContentHeight,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Coluna da Esquerda: BLOCO INFO (Hierarquia vertical rigorosa)
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        product.name.toUpperCase(),
                        maxLines: 2,
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                          lineSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      _buildSizePill(sizesText),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        'REF: ${product.reference}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.normal,
                          color: PdfColors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (showPrice) ...[
                        pw.SizedBox(
                          height: 15,
                        ), // Empurra o preço para a base do bloco
                        pw.Text(
                          currencyFormat.format(displayPrice),
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: _colorPriceGreen,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Coluna da Direita: BLOCO THUMBS (Ocupa o espaço restante)
                if (bottomVariants.isNotEmpty)
                  pw.Expanded(
                    flex: 6, // Maior flex para fotos grandes
                    child: pw.Container(
                      alignment: pw.Alignment.topRight,
                      child: _buildVariantThumbsLayout(bottomVariants),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the variant thumb layout based on quantity rules
  static pw.Widget _buildVariantThumbsLayout(
    List<MapEntry<String, String>> variants,
  ) {
    final count = variants.length;

    if (count == 4) {
      // Caso 4: Grade 2x2 (Dividir o espaço)
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              _buildSwatchThumb(variants[0].key, variants[0].value, width: 44),
              pw.SizedBox(width: 6),
              _buildSwatchThumb(variants[1].key, variants[1].value, width: 44),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              _buildSwatchThumb(variants[2].key, variants[2].value, width: 44),
              pw.SizedBox(width: 6),
              _buildSwatchThumb(variants[3].key, variants[3].value, width: 44),
            ],
          ),
        ],
      );
    } else if (count == 2) {
      // Caso 2: Duas fotos grandes ocupando o espaço lateral
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          _buildSwatchThumb(variants[0].key, variants[0].value, width: 85),
          pw.SizedBox(width: 10),
          _buildSwatchThumb(variants[1].key, variants[1].value, width: 85),
        ],
      );
    } else {
      // Casos 1 ou 3
      final thumbWidth = (count == 3) ? 42.0 : 85.0;
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        mainAxisSize: pw.MainAxisSize.min,
        children: variants.asMap().entries.map((entry) {
          return pw.Padding(
            padding: pw.EdgeInsets.only(left: entry.key == 0 ? 0 : 8),
            child: _buildSwatchThumb(
              entry.value.key,
              entry.value.value,
              width: thumbWidth,
            ),
          );
        }).toList(),
      );
    }
  }

  /// Helper for a single variant swatch thumb
  static pw.Widget _buildSwatchThumb(
    String label,
    String path, {
    double? width,
    bool small = false,
    bool expand = false,
  }) {
    final thumbWidth = width ?? (small ? 42.0 : 56.0);
    final thumbHeight = expand ? null : (thumbWidth * 1.3);

    final imageContainer = pw.Container(
      width: thumbWidth,
      height: thumbHeight,
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 10,
        verticalRadius: 10,
        child: _buildImageBox(
          path,
          height: thumbHeight ?? 200, // Large fallback for fit
          width: thumbWidth,
          radius: 10,
        ),
      ),
    );

    return pw.Column(
      mainAxisSize: expand ? pw.MainAxisSize.max : pw.MainAxisSize.min,
      children: [
        expand ? pw.Expanded(child: imageContainer) : imageContainer,
        pw.SizedBox(height: 2),
        pw.Container(
          width: thumbWidth + 10,
          child: pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: small ? 7 : 8,
              letterSpacing: 0.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
            textAlign: pw.TextAlign.center,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
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

    final sorted = _sortSizes(sizes);
    return sorted.join('/');
  }

  static List<String> _sortSizes(Iterable<String> sizes) {
    const order = [
      'RN',
      'PP',
      'P',
      'M',
      'G',
      'GG',
      'XG',
      'G1',
      'G2',
      'G3',
      'G4',
    ];
    final list = sizes.toList();
    list.sort((a, b) {
      final numA = double.tryParse(a.replaceAll(',', '.'));
      final numB = double.tryParse(b.replaceAll(',', '.'));

      if (numA != null && numB != null) return numA.compareTo(numB);
      if (numA != null) return -1;
      if (numB != null) return 1;

      final idxA = order.indexOf(a.toUpperCase());
      final idxB = order.indexOf(b.toUpperCase());

      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;

      return a.compareTo(b);
    });
    return list;
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
            alignment: pw.Alignment.centerLeft,
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
    double? width,
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

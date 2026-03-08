import 'dart:io';

void main() {
  final file = File(
    r'd:\REPOSITORIO GIT\gravity\lib\core\services\catalog_pdf_service.dart',
  );
  var content = file.readAsStringSync();

  final startStr = '  static pw.Widget _buildProductPage(';
  final endStr =
      '  /// Builds the variant thumb layout based on quantity rules';

  final startIndex = content.indexOf(startStr);
  final endIndex = content.indexOf(endStr);

  if (startIndex == -1 || endIndex == -1) {
    print('Indices not found!');
    return;
  }

  final newLogic = r'''
  static pw.Widget _buildProductPage(
    Product product,
    CatalogMode mode,
    NumberFormat currencyFormat,
    PdfPageFormat pageFormat, {
    String? collectionName,
    String defaultSubtitle = 'SELEÇÃO DE PRODUTOS',
    bool showPrice = true,
    bool useLoosePhotos = false,
    String? forcedHeroPath,
    CatalogPdfStyle style = CatalogPdfStyle.classic,
  }) {
    final displayPrice = product.priceForMode(mode.name);
    ProductImage? photoP;
    List<MapEntry<String, ProductImage>> detailVariants;
    List<MapEntry<String, ProductImage>> colorVariants;

    if (forcedHeroPath != null && forcedHeroPath.trim().isNotEmpty) {
      photoP = ProductImage.local(path: forcedHeroPath);
      detailVariants = const [];
      colorVariants = const [];
    } else {
      photoP = product.mainImage;
      detailVariants = product.detailImages
          .take(2)
          .map((img) => MapEntry('', img))
          .toList();
      colorVariants = product.colorImages.take(4).map((img) {
        final rawLabel = img.colorTag ?? _resolveColorLabelLegacy(img.uri);
        final label = _stripColorPrefix(rawLabel);
        return MapEntry(label, img);
      }).toList();
    }

    final sizesText = _extractSizesText(product);
    final topHeaderText =
        (collectionName != null && collectionName.trim().isNotEmpty)
        ? collectionName.trim()
        : defaultSubtitle;

    final availableWidth = pageFormat.width - 36;
    final availableHeight = pageFormat.height - 36;
    
    switch (style) {
      case CatalogPdfStyle.editorial:
        return _buildEditorialLayout(product, showPrice, displayPrice, photoP, detailVariants, colorVariants, sizesText, topHeaderText, pageFormat, currencyFormat);
      case CatalogPdfStyle.minimal:
        return _buildMinimalLayout(product, showPrice, displayPrice, photoP, detailVariants, colorVariants, sizesText, topHeaderText, availableWidth, availableHeight, currencyFormat);
      case CatalogPdfStyle.compact:
        return _buildCompactLayout(product, showPrice, displayPrice, photoP, detailVariants, colorVariants, sizesText, topHeaderText, availableWidth, availableHeight, currencyFormat);
      case CatalogPdfStyle.clean:
        return _buildCleanLayout(product, showPrice, displayPrice, photoP, detailVariants, colorVariants, sizesText, topHeaderText, availableWidth, availableHeight, currencyFormat);
      case CatalogPdfStyle.classic:
      default:
        return _buildClassicLayout(product, showPrice, displayPrice, photoP, detailVariants, colorVariants, sizesText, topHeaderText, availableWidth, availableHeight, currencyFormat);
    }
  }

  static pw.Widget _buildEditorialLayout(Product product, bool showPrice, double displayPrice, ProductImage? photoP, List<MapEntry<String, ProductImage>> detailVariants, List<MapEntry<String, ProductImage>> colorVariants, String sizesText, String topHeaderText, PdfPageFormat pageFormat, NumberFormat currencyFormat) {
    return pw.Container(
      width: pageFormat.width,
      height: pageFormat.height,
      color: PdfColors.white,
      child: pw.Stack(
        children: [
          // Full bleed image
          pw.Positioned.fill(
            child: photoP != null
                ? _buildImageWidget(photoP, height: pageFormat.height, radius: 0)
                : _buildImagePlaceholder(height: pageFormat.height, width: pageFormat.width, radius: 0),
          ),
          // Gradient or solid overlay at bottom
          pw.Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: pw.Container(
              height: 240,
              decoration: const pw.BoxDecoration(
                 gradient: pw.LinearGradient(
                   begin: pw.Alignment.topCenter,
                   end: pw.Alignment.bottomCenter,
                   colors: [PdfColor(0,0,0,0.0), PdfColor(0,0,0,0.9)],
                 ),
              ),
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      product.name.toUpperCase(),
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
                    ),
                    pw.SizedBox(height: 8),
                    if (showPrice)
                      pw.Text(
                        currencyFormat.format(displayPrice),
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 32, fontWeight: pw.FontWeight.bold),
                      ),
                    pw.SizedBox(height: 14),
                    pw.Text(
                      'REF: ${product.reference}   •   $sizesText',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 13, letterSpacing: 2),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      )
    );
  }

  static pw.Widget _buildMinimalLayout(Product product, bool showPrice, double displayPrice, ProductImage? photoP, List<MapEntry<String, ProductImage>> detailVariants, List<MapEntry<String, ProductImage>> colorVariants, String sizesText, String topHeaderText, double availableWidth, double availableHeight, NumberFormat currencyFormat) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(36),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Expanded(
            child: photoP != null
              ? _buildImageWidget(photoP, height: availableHeight * 0.75, width: availableWidth - 36, radius: 12)
              : _buildImagePlaceholder(height: availableHeight * 0.75, width: availableWidth - 36, radius: 12),
          ),
          pw.SizedBox(height: 32),
          pw.Text(
            product.name,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 18, color: PdfColors.grey800, letterSpacing: 2),
          ),
          pw.SizedBox(height: 16),
          if (showPrice)
            pw.Text(
              currencyFormat.format(displayPrice),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 22, color: PdfColors.black, fontWeight: pw.FontWeight.bold),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildCompactLayout(Product product, bool showPrice, double displayPrice, ProductImage? photoP, List<MapEntry<String, ProductImage>> detailVariants, List<MapEntry<String, ProductImage>> colorVariants, String sizesText, String topHeaderText, double availableWidth, double availableHeight, NumberFormat currencyFormat) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 24,
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              topHeaderText.toUpperCase(),
              style: pw.TextStyle(fontSize: 9, letterSpacing: 2, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
            ),
          ),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 6,
                  child: photoP != null ? _buildImageWidget(photoP, height: availableHeight - 40, radius: 4) : _buildImagePlaceholder(height: availableHeight - 40, width: availableWidth, radius: 4),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(product.name.toUpperCase(), maxLines: 2, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                      pw.SizedBox(height: 8),
                      _buildSizePill(sizesText),
                      pw.SizedBox(height: 8),
                      pw.Text('REF: ${product.reference}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (showPrice) ...[
                        pw.SizedBox(height: 16),
                        pw.Text(currencyFormat.format(displayPrice), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _colorPriceGreen)),
                      ],
                      pw.SizedBox(height: 24),
                      if (detailVariants.isNotEmpty) ...[
                        pw.Text('DETALHES', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, letterSpacing: 1)),
                        pw.SizedBox(height: 8),
                        // Just stack them vertically
                        ...detailVariants.map((v) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 8), child: _buildSwatchThumb(v.key, v.value, width: 80))),
                        pw.SizedBox(height: 8),
                      ],
                      if (colorVariants.isNotEmpty) ...[
                        pw.Text('CORES', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, letterSpacing: 1)),
                        pw.SizedBox(height: 8),
                        pw.Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: colorVariants.map((v) => _buildSwatchThumb(v.key, v.value, width: 36)).toList(),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            )
          ),
        ],
      )
    );
  }

  static pw.Widget _buildCleanLayout(Product product, bool showPrice, double displayPrice, ProductImage? photoP, List<MapEntry<String, ProductImage>> detailVariants, List<MapEntry<String, ProductImage>> colorVariants, String sizesText, String topHeaderText, double availableWidth, double availableHeight, NumberFormat currencyFormat) {
    return _buildClassicLayout(product, showPrice, displayPrice, photoP, detailVariants, colorVariants, sizesText, topHeaderText, availableWidth, availableHeight, currencyFormat, isClean: true);
  }

  static pw.Widget _buildClassicLayout(Product product, bool showPrice, double displayPrice, ProductImage? photoP, List<MapEntry<String, ProductImage>> detailVariants, List<MapEntry<String, ProductImage>> colorVariants, String sizesText, String topHeaderText, double availableWidth, double availableHeight, NumberFormat currencyFormat, {bool isClean = false}) {
    final mainPhotoHeight = availableHeight - 35 - 175 - 15;
    final radius = isClean ? 12.0 : 0.0;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 35,
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              topHeaderText.toUpperCase(),
              style: pw.TextStyle(fontSize: 11, letterSpacing: 3, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
          ),
          pw.Container(
            height: mainPhotoHeight,
            width: availableWidth,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  child: photoP != null ? _buildImageWidget(photoP, height: mainPhotoHeight, radius: radius) : _buildImagePlaceholder(height: mainPhotoHeight, width: availableWidth, radius: radius),
                ),
                if (detailVariants.isNotEmpty) ...[
                  pw.SizedBox(width: 10),
                  pw.Container(
                    width: 85,
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: detailVariants.map((v) => pw.Expanded(child: _buildSwatchThumb(v.key, v.value, width: 85, expand: true))).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Container(
            height: 175,
            padding: isClean ? const pw.EdgeInsets.all(16) : pw.EdgeInsets.zero,
            decoration: isClean ? pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(12)) : null,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(product.name.toUpperCase(), maxLines: 2, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                      pw.SizedBox(height: 12),
                      _buildSizePill(sizesText),
                      pw.SizedBox(height: 12),
                      pw.Text('REF: ${product.reference}', style: pw.TextStyle(fontSize: 11, color: PdfColors.black, letterSpacing: 0.5)),
                      if (showPrice) ...[
                        pw.SizedBox(height: 15),
                        pw.Text(currencyFormat.format(displayPrice), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _colorPriceGreen)),
                      ],
                    ],
                  ),
                ),
                if (colorVariants.isNotEmpty)
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      alignment: pw.Alignment.topRight,
                      child: _buildVariantThumbsLayout(colorVariants),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

''';

  final result =
      content.substring(0, startIndex) + newLogic + content.substring(endIndex);
  file.writeAsStringSync(result);
}

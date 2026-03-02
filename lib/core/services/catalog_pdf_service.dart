import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:intl/intl.dart';

enum CatalogPdfStyle { classic, clean, compact, editorial, minimal }

class CatalogPdfService {
  static const PdfColor _colorPriceGreen = PdfColor(0.12, 0.42, 0.29);
  static const PdfColor _colorMuted = PdfColor(0.45, 0.45, 0.45);
  static const PdfColor _colorImageBg = PdfColor(0.953, 0.953, 0.953);
  static const PdfColor _colorSizePillBg = PdfColor(0.929, 0.929, 0.929);
  static const PdfPageFormat _defaultMobileFormat = PdfPageFormat(360, 640);

  // Cache unificado de imagens (rede + local + memória) durante a geração
  static final Map<String, Uint8List> _imageCache = {};

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
    bool useLoosePhotos = false,
    CatalogPdfStyle style = CatalogPdfStyle.classic,
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

    // Pré-carregar TODAS as imagens dos produtos (rede + local + memória) em paralelo
    await _preloadImages(products);

    // Pré-carregar imagens da capa e do banner (arquivos locais)
    final coverPaths = <String>{
      if (bannerImagePath != null && bannerImagePath.isNotEmpty)
        bannerImagePath,
      if (collectionCover?.coverImagePath?.isNotEmpty == true)
        collectionCover!.coverImagePath!,
      if (collectionCover?.coverMiniPath?.isNotEmpty == true)
        collectionCover!.coverMiniPath!,
      if (collectionCover?.coverPagePath?.isNotEmpty == true)
        collectionCover!.coverPagePath!,
    };
    await Future.wait(
      coverPaths.where((p) => !_imageCache.containsKey(p)).map((p) async {
        try {
          final file = File(p);
          if (await file.exists()) {
            _imageCache[p] = await file.readAsBytes();
          }
        } catch (e) {
          print('Erro ao pré-carregar imagem da capa: $p - $e');
        }
      }),
    );

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

      if (useLoosePhotos) {
        final loosePhotos = _extractLoosePhotos(product);
        if (loosePhotos.isEmpty) {
          pdf.addPage(
            pw.Page(
              pageFormat: pageFormat,
              margin: const pw.EdgeInsets.symmetric(vertical: 18),
              build: (context) => _buildProductPage(
                product,
                mode,
                currencyFormat,
                pageFormat,
                collectionName: collectionName,
                defaultSubtitle: defaultSubtitle,
                showPrice: showPrice,
                useLoosePhotos: true,
                style: style,
              ),
            ),
          );
        } else {
          for (final photo in loosePhotos) {
            pdf.addPage(
              pw.Page(
                pageFormat: pageFormat,
                margin: const pw.EdgeInsets.symmetric(vertical: 18),
                build: (context) => _buildProductPage(
                  product,
                  mode,
                  currencyFormat,
                  pageFormat,
                  collectionName: collectionName,
                  defaultSubtitle: defaultSubtitle,
                  showPrice: showPrice,
                  useLoosePhotos: true,
                  forcedHeroPath: photo.uri,
                  style: style,
                ),
              ),
            );
          }
        }
      } else {
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
              useLoosePhotos: false,
              style: style,
            ),
          ),
        );
      }
    }

    final result = await pdf.save();
    // Limpar cache após salvar para liberar memória
    _imageCache.clear();
    return result;
  }

  static Future<void> _preloadImages(List<Product> products) async {
    // Coletar todas as imagens únicas por tipo
    final networkUrls = <String>{};
    final localPaths = <String>{};
    final memoryUris = <String>{};

    for (final product in products) {
      for (final img in product.images) {
        final uri = img.uri.trim();
        if (uri.isEmpty) continue;
        switch (img.sourceType) {
          case ProductImageSource.networkUrl:
            if (!_imageCache.containsKey(uri)) networkUrls.add(uri);
          case ProductImageSource.localPath:
            if (!_imageCache.containsKey(uri)) localPaths.add(uri);
          case ProductImageSource.memory:
            if (!_imageCache.containsKey(uri)) memoryUris.add(uri);
          default:
            break;
        }
      }
    }

    // Pré-carregar imagens locais em paralelo
    if (localPaths.isNotEmpty) {
      await Future.wait(
        localPaths.map((path) async {
          try {
            final file = File(path);
            if (await file.exists()) {
              _imageCache[path] = await file.readAsBytes();
            }
          } catch (e) {
            print('Erro ao ler imagem local para PDF: $path - $e');
          }
        }),
      );
    }

    // Decodificar imagens de memória (base64) em paralelo
    if (memoryUris.isNotEmpty) {
      await Future.wait(
        memoryUris.map((uri) async {
          try {
            if (uri.startsWith('data:')) {
              final commaIndex = uri.indexOf(',');
              if (commaIndex != -1) {
                _imageCache[uri] = base64Decode(uri.substring(commaIndex + 1));
              }
            }
          } catch (e) {
            print('Erro ao decodificar imagem em memória para PDF: $e');
          }
        }),
      );
    }

    // Baixar imagens de rede em paralelo (máx. 8 simultâneas)
    if (networkUrls.isNotEmpty) {
      const maxConcurrent = 8;
      final urls = networkUrls.toList();
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);

      try {
        for (var i = 0; i < urls.length; i += maxConcurrent) {
          final batch = urls.skip(i).take(maxConcurrent);
          await Future.wait(
            batch.map((url) async {
              try {
                final request = await client
                    .getUrl(Uri.parse(url))
                    .timeout(const Duration(seconds: 10));
                final response = await request.close().timeout(
                  const Duration(seconds: 10),
                );
                if (response.statusCode == 200) {
                  final builder = BytesBuilder();
                  await for (final chunk in response) {
                    builder.add(chunk);
                  }
                  _imageCache[url] = builder.takeBytes();
                }
              } catch (e) {
                print('Erro ao baixar imagem para PDF: $url - $e');
              }
            }),
          );
        }
      } finally {
        client.close();
      }
    }
  }

  static pw.Widget _buildProductPage(
    Product product,
    CatalogMode mode,
    NumberFormat currencyFormat,
    PdfPageFormat pageFormat, {
    String? collectionName,
    String defaultSubtitle = 'SELE\u00c7\u00c3O DE PRODUTOS',
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

    final bottomContentHeight = switch (style) {
      CatalogPdfStyle.classic => 175.0,
      CatalogPdfStyle.clean => 165.0,
      CatalogPdfStyle.compact => 145.0,
      CatalogPdfStyle.editorial => 190.0,
      CatalogPdfStyle.minimal => 135.0,
    };
    final topHeaderHeight = switch (style) {
      CatalogPdfStyle.classic => 35.0,
      CatalogPdfStyle.clean => 28.0,
      CatalogPdfStyle.compact => 24.0,
      CatalogPdfStyle.editorial => 46.0,
      CatalogPdfStyle.minimal => 0.0,
    };
    final spacing = switch (style) {
      CatalogPdfStyle.classic => 15.0,
      CatalogPdfStyle.clean => 12.0,
      CatalogPdfStyle.compact => 8.0,
      CatalogPdfStyle.editorial => 18.0,
      CatalogPdfStyle.minimal => 10.0,
    };
    final mainRadius = switch (style) {
      CatalogPdfStyle.classic => 0.0,
      CatalogPdfStyle.clean => 8.0,
      CatalogPdfStyle.compact => 6.0,
      CatalogPdfStyle.editorial => 0.0,
      CatalogPdfStyle.minimal => 12.0,
    };
    final productNameSize = switch (style) {
      CatalogPdfStyle.classic => 15.0,
      CatalogPdfStyle.clean => 14.0,
      CatalogPdfStyle.compact => 13.0,
      CatalogPdfStyle.editorial => 17.0,
      CatalogPdfStyle.minimal => 14.0,
    };
    final priceSize = switch (style) {
      CatalogPdfStyle.classic => 22.0,
      CatalogPdfStyle.clean => 21.0,
      CatalogPdfStyle.compact => 18.0,
      CatalogPdfStyle.editorial => 24.0,
      CatalogPdfStyle.minimal => 20.0,
    };
    final detailColumnWidth = switch (style) {
      CatalogPdfStyle.classic => 85.0,
      CatalogPdfStyle.clean => 82.0,
      CatalogPdfStyle.compact => 72.0,
      CatalogPdfStyle.editorial => 92.0,
      CatalogPdfStyle.minimal => 78.0,
    };
    final showHeader = style != CatalogPdfStyle.minimal;
    final infoFlex = switch (style) {
      CatalogPdfStyle.classic => 4,
      CatalogPdfStyle.clean => 5,
      CatalogPdfStyle.compact => 6,
      CatalogPdfStyle.editorial => 5,
      CatalogPdfStyle.minimal => 6,
    };
    final colorFlex = switch (style) {
      CatalogPdfStyle.classic => 6,
      CatalogPdfStyle.clean => 5,
      CatalogPdfStyle.compact => 4,
      CatalogPdfStyle.editorial => 5,
      CatalogPdfStyle.minimal => 4,
    };
    final nameMaxLines = style == CatalogPdfStyle.compact ? 1 : 2;
    final mainPhotoHeight =
        availableHeight - topHeaderHeight - bottomContentHeight - spacing;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header
          if (showHeader)
            pw.Container(
              height: topHeaderHeight,
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                topHeaderText.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: style == CatalogPdfStyle.editorial ? 12 : 11,
                  letterSpacing: style == CatalogPdfStyle.compact ? 1.4 : 3,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ),
          // 2. Main Photo Section + Details
          pw.Container(
            height: mainPhotoHeight,
            width: availableWidth,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // MAIN PHOTO (P)
                pw.Expanded(
                  child: photoP != null
                      ? _buildImageWidget(
                          photoP,
                          height: mainPhotoHeight,
                          radius: mainRadius,
                        )
                      : _buildImagePlaceholder(
                          height: mainPhotoHeight,
                          width: availableWidth,
                          radius: mainRadius,
                        ),
                ),
                // DETAILS (D1, D2)
                if (detailVariants.isNotEmpty) ...[
                  pw.SizedBox(width: 10),
                  pw.Container(
                    width: detailColumnWidth,
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: detailVariants
                          .map(
                            (v) => pw.Expanded(
                              child: _buildSwatchThumb(
                                v.key,
                                v.value,
                                width: detailColumnWidth,
                                expand: true,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: spacing),
          // 3. Bottom Content (Info + Colors)
          pw.Container(
            height: bottomContentHeight,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Info Section
                pw.Expanded(
                  flex: infoFlex,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        product.name.toUpperCase(),
                        maxLines: nameMaxLines,
                        style: pw.TextStyle(
                          fontSize: productNameSize,
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
                        pw.SizedBox(height: 15),
                        pw.Text(
                          currencyFormat.format(displayPrice),
                          style: pw.TextStyle(
                            fontSize: priceSize,
                            fontWeight: pw.FontWeight.bold,
                            color: _colorPriceGreen,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Colors Section (C1-C4)
                if (colorVariants.isNotEmpty)
                  pw.Expanded(
                    flex: colorFlex,
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

  /// Builds the variant thumb layout based on quantity rules
  static pw.Widget _buildVariantThumbsLayout(
    List<MapEntry<String, ProductImage>> variants,
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
              _buildSwatchThumb(variants[0].key, variants[0].value, width: 22),
              pw.SizedBox(width: 4),
              _buildSwatchThumb(variants[1].key, variants[1].value, width: 22),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              _buildSwatchThumb(variants[2].key, variants[2].value, width: 22),
              pw.SizedBox(width: 4),
              _buildSwatchThumb(variants[3].key, variants[3].value, width: 22),
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
          _buildSwatchThumb(variants[0].key, variants[0].value, width: 42),
          pw.SizedBox(width: 6),
          _buildSwatchThumb(variants[1].key, variants[1].value, width: 42),
        ],
      );
    } else {
      // Casos 1 ou 3
      final thumbWidth = (count == 3) ? 21.0 : 42.0;
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        mainAxisSize: pw.MainAxisSize.min,
        children: variants.asMap().entries.map((entry) {
          return pw.Padding(
            padding: pw.EdgeInsets.only(left: entry.key == 0 ? 0 : 6),
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
    ProductImage img, {
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
        child: _buildImageWidget(
          img,
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
        if (label.trim().isNotEmpty) ...[
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

  static List<ProductImage> _extractLoosePhotos(Product product) {
    return product.images;
  }

  static String _resolveColorLabel(ProductImage img) {
    final explicit = img.colorTag?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final fromPath = _extractColorFromPath(img.uri);
    if (fromPath != null && fromPath.isNotEmpty) {
      return fromPath;
    }

    final label = img.label?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    return 'COR';
  }

  static String? _extractColorFromPath(String path) {
    final fileName = path.split(RegExp(r'[\\/]')).last;
    if (fileName.isEmpty) return null;

    final base = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');

    // Internal format: 106603__C1__PRETO
    final internal = RegExp(
      r'__c\d*__([a-z0-9_\-\s]+)$',
      caseSensitive: false,
    ).firstMatch(base);
    if (internal != null) {
      return _normalizeColorText(internal.group(1)!);
    }

    // External formats:
    // 106603_cor_preto / 106603_cor_azul-marinho / 106603_preto
    final byRef = RegExp(
      r'^\d+[_\-\s]+(.+)$',
      caseSensitive: false,
    ).firstMatch(base);
    if (byRef == null) return null;

    var suffix = byRef.group(1) ?? '';
    suffix = suffix.replaceFirst(
      RegExp(r'^cor[_\-\s]+', caseSensitive: false),
      '',
    );
    if (suffix.trim().isEmpty) return null;

    return _normalizeColorText(suffix);
  }

  static String _normalizeColorText(String raw) {
    final parts = raw
        .split(RegExp(r'[_\-\s]+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return raw.trim().toUpperCase();
    return parts.join(' ').toUpperCase();
  }

  static String _resolveColorLabelLegacy(String path) {
    final fromPath = _extractColorFromPath(path);
    if (fromPath != null && fromPath.isNotEmpty) {
      return fromPath;
    }
    return 'COR';
  }

  /// Remove prefixo "C1", "C2", "C3", "C4" do label de cor.
  /// Ex: "C1 Azul" -> "Azul", "C2 ROSA" -> "ROSA", "Preto" -> "Preto"
  static String _stripColorPrefix(String label) {
    return label
        .replaceFirst(RegExp(r'^C[1-4]\s+', caseSensitive: false), '')
        .trim();
  }

  static pw.Widget _buildImageWidget(
    ProductImage img, {
    required double height,
    double? width,
    double radius = 0,
  }) {
    try {
      // Todas as imagens já foram pré-carregadas em _imageCache
      final bytes = _imageCache[img.uri];

      if (bytes != null) {
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
            child: pw.FittedBox(fit: pw.BoxFit.contain, child: pw.Image(image)),
          ),
        );
      }
    } catch (e) {
      print('Falha ao processar imagem no PDF: ${img.uri} - $e');
    }
    return _buildImagePlaceholder(height: height, width: width, radius: radius);
  }

  static pw.Widget _buildImageBox(
    String path, {
    required double height,
    double? width,
    double radius = 0,
  }) {
    // Legacy support for cover images which might be paths
    final img = ProductImage.local(path: path);
    return _buildImageWidget(img, height: height, width: width, radius: radius);
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
        color: PdfColor(0.9, 0.9, 0.9), // Cinza claro
        borderRadius: pw.BorderRadius.circular(radius),
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'Imagem',
            style: pw.TextStyle(color: _colorMuted, fontSize: 8),
          ),
          pw.Text(
            'indisponível',
            style: pw.TextStyle(color: _colorMuted, fontSize: 8),
          ),
        ],
      ),
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

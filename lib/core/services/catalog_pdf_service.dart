import 'dart:io' as io;
import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

enum CatalogPdfStyle { classic, clean, compact, editorial, minimal }

class CatalogPdfService {
  static const PdfColor _colorPriceGreen = PdfColor(0.12, 0.42, 0.29);
  static const PdfColor _colorMuted = PdfColor(0.45, 0.45, 0.45);
  static const PdfColor _colorImageBg = PdfColor(0.953, 0.953, 0.953);
  static const PdfColor _colorSizePillBg = PdfColor(0.929, 0.929, 0.929);
  static const PdfPageFormat _defaultMobileFormat = PdfPageFormat(360, 640);

  // Cache unificado de imagens (rede + local + memória) durante a geração.
  // Usamos URIs trimados como chave para evitar falhas por espaços em branco.
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

    // Coleta TODAS as imagens possíveis para pré-carregamento (Produtos + Capas + Banners)
    // Inclui TODAS as fontes (images, photos, remoteImages) sem exclusão mútua.
    final allImages = <ProductImage>[];
    for (final p in products) {
      // Novas imagens
      allImages.addAll(p.images);
      // Imagens legadas (converte para ProductImage para unificar o processamento)
      for (final ph in p.photos) {
        allImages.add(ph.toProductImage());
      }
      // URLs remotas legadas
      for (final url in p.remoteImages) {
        if (url.trim().isNotEmpty) {
          allImages.add(ProductImage.network(url: url.trim()));
        }
      }
    }

    if (bannerImagePath != null && bannerImagePath.isNotEmpty) {
      allImages.add(_inferProductImage(bannerImagePath));
    }

    if (collectionCover != null) {
      if (collectionCover.coverImagePath?.isNotEmpty == true) {
        allImages.add(_inferProductImage(collectionCover.coverImagePath!));
      }
      if (collectionCover.coverMiniPath?.isNotEmpty == true) {
        allImages.add(_inferProductImage(collectionCover.coverMiniPath!));
      }
      if (collectionCover.coverPagePath?.isNotEmpty == true) {
        allImages.add(_inferProductImage(collectionCover.coverPagePath!));
      }
    }

    if (collectionsMap != null) {
      for (final cat in collectionsMap.values) {
        if (cat.cover != null) {
          if (cat.cover!.coverImagePath?.isNotEmpty == true) {
            allImages.add(_inferProductImage(cat.cover!.coverImagePath!));
          }
          if (cat.cover!.coverMiniPath?.isNotEmpty == true) {
            allImages.add(_inferProductImage(cat.cover!.coverMiniPath!));
          }
          if (cat.cover!.coverPagePath?.isNotEmpty == true) {
            allImages.add(_inferProductImage(cat.cover!.coverPagePath!));
          }
        }
      }
    }

    // Pré-carregar TODAS as imagens unificadamente (rede + local + memória)
    await _preloadImages(allImages);

    // Group products by collection to facilitate batching
    final List<List<Product>> collectionBatches = [];
    if (collectionsMap != null) {
      String? lastId;
      List<Product> currentCollection = [];
      for (final p in products) {
        String? prodCatId;
        for (final id in p.categoryIds) {
          if (collectionsMap.containsKey(id)) {
            prodCatId = id;
            break;
          }
        }
        if (prodCatId != lastId && currentCollection.isNotEmpty) {
          collectionBatches.add(currentCollection);
          currentCollection = [];
        }
        currentCollection.add(p);
        lastId = prodCatId;
      }
      if (currentCollection.isNotEmpty) {
        collectionBatches.add(currentCollection);
      }
    } else {
      collectionBatches.add(products);
    }

    final int itemsPerPage = switch (style) {
      CatalogPdfStyle.compact => 3,
      CatalogPdfStyle.minimal => 2,
      _ => 1,
    };

    for (final batch in collectionBatches) {
      // Add collection opening page if needed
      if (collectionsMap != null && batch.isNotEmpty) {
        String? prodCollectionId;
        for (final catId in batch.first.categoryIds) {
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

      // Process products in this collection with batching
      for (var i = 0; i < batch.length; i += itemsPerPage) {
        final productsInPage = batch.skip(i).take(itemsPerPage).toList();

        // If useLoosePhotos is ON, we still do 1 page per photo for now
        if (useLoosePhotos) {
          for (final product in productsInPage) {
            final loosePhotos = _extractLoosePhotos(product);
            final photosToProcess = loosePhotos.isEmpty ? [null] : loosePhotos;

            for (final photo in photosToProcess) {
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
                    forcedHeroPath: photo?.uri,
                    style: style,
                  ),
                ),
              );
            }
          }
        } else {
          // Standard batched page
          pdf.addPage(
            pw.Page(
              pageFormat: pageFormat,
              margin: pw.EdgeInsets.zero, // Styles handle their own margins
              build: (context) {
                final double itemHeight =
                    (pageFormat.height - 36) / itemsPerPage;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 18),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    children: productsInPage.map((product) {
                      return pw.Container(
                        height: itemHeight,
                        child: _buildProductPage(
                          product,
                          mode,
                          currencyFormat,
                          pageFormat.copyWith(
                            height: itemHeight,
                          ), // Treat each item area as a miniature page
                          collectionName: collectionName,
                          defaultSubtitle: defaultSubtitle,
                          showPrice: showPrice,
                          useLoosePhotos: false,
                          style: style,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          );
        }
      }
    }

    final result = await pdf.save();
    // Limpar cache após salvar para liberar memória
    _imageCache.clear();
    return result;
  }

  static Future<void> _preloadImages(List<ProductImage> imageObjects) async {
    // Garante que o cache comece limpo para esta geração
    _imageCache.clear();

    final networkUrls = <String>{};
    final localPaths = <String>{};
    final memoryUris = <String>{};

    for (final img in imageObjects) {
      final uri = img.uri.trim();
      if (uri.isEmpty) continue;

      var effectiveSource = img.sourceType;
      // Se for desconhecido, inferimos pelo prefixo da URI
      if (effectiveSource == ProductImageSource.unknown) {
        if (uri.startsWith('http')) {
          effectiveSource = ProductImageSource.networkUrl;
        } else if (uri.startsWith('data:')) {
          effectiveSource = ProductImageSource.memory;
        } else if (uri.startsWith('blob:')) {
          effectiveSource = ProductImageSource.networkUrl;
        } else {
          effectiveSource = ProductImageSource.localPath;
        }
      }

      switch (effectiveSource) {
        case ProductImageSource.networkUrl:
          networkUrls.add(uri);
          break;
        case ProductImageSource.localPath:
          // No Web, "localPath" pode ser um asset ou algo mal categorizado.
          // Mas como File não existe, só tentamos carregar se não for Web.
          if (!kIsWeb) {
            localPaths.add(uri);
          } else {
            // Se for Web e começar com http ou blob, redirecionamos para rede
            if (uri.startsWith('http') || uri.startsWith('blob:')) {
              networkUrls.add(uri);
            }
          }
          break;
        case ProductImageSource.memory:
          memoryUris.add(uri);
          break;
        default:
          if (uri.startsWith('http') || uri.startsWith('blob:')) {
            networkUrls.add(uri);
          }
          break;
      }
    }

    const int maxConcurrent = 5; // Reduzido para maior estabilidade

    // 1. Processar imagens locais (Apenas Mobile)
    if (localPaths.isNotEmpty && !kIsWeb) {
      final pathsList = localPaths.toList();
      for (var i = 0; i < pathsList.length; i += maxConcurrent) {
        final batch = pathsList.skip(i).take(maxConcurrent);
        await Future.wait(
          batch.map((path) async {
            try {
              final file = io.File(path);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                if (kIsWeb) {
                  _imageCache[path] = bytes;
                } else {
                  final result = await FlutterImageCompress.compressWithFile(
                    path,
                    minWidth: 700,
                    minHeight: 700,
                    quality: 40,
                  );
                  _imageCache[path] = result ?? bytes;
                }
              }
            } catch (e) {
              debugPrint('Erro ao processar imagem local: $path - $e');
            }
          }),
        );
      }
    }

    // 2. Processar imagens em memória
    if (memoryUris.isNotEmpty) {
      final urisList = memoryUris.toList();
      for (var i = 0; i < urisList.length; i += maxConcurrent) {
        final batch = urisList.skip(i).take(maxConcurrent);
        await Future.wait(
          batch.map((uri) async {
            try {
              if (uri.startsWith('data:')) {
                final commaIndex = uri.indexOf(',');
                if (commaIndex != -1) {
                  final bytes = base64Decode(uri.substring(commaIndex + 1));
                  if (kIsWeb) {
                    _imageCache[uri] = bytes;
                  } else {
                    final compressed =
                        await FlutterImageCompress.compressWithList(
                          bytes,
                          minWidth: 700,
                          minHeight: 700,
                          quality: 40,
                        );
                    _imageCache[uri] = compressed ?? bytes;
                  }
                }
              }
            } catch (e) {
              debugPrint('Erro ao decodificar imagem em memória: $e');
            }
          }),
        );
      }
    }

    // 3. Processar imagens de rede (Usa http para compatibilidade Web)
    if (networkUrls.isNotEmpty) {
      final urls = networkUrls.toList();
      for (var i = 0; i < urls.length; i += maxConcurrent) {
        final batch = urls.skip(i).take(maxConcurrent);
        await Future.wait(
          batch.map((url) async {
            try {
              final uri = Uri.parse(url);
              final response = await http
                  .get(uri)
                  .timeout(const Duration(seconds: 15));

              if (response.statusCode == 200) {
                final bytes = response.bodyBytes;
                if (kIsWeb) {
                  _imageCache[url] = bytes;
                } else {
                  try {
                    final compressed =
                        await FlutterImageCompress.compressWithList(
                          bytes,
                          minWidth: 700,
                          minHeight: 700,
                          quality: 40,
                        );
                    _imageCache[url] = compressed ?? bytes;
                  } catch (e) {
                    debugPrint('Erro na compressão: $url - $e');
                    _imageCache[url] = bytes;
                  }
                }
              } else {
                debugPrint('Falha ao baixar imagem (Status ${response.statusCode}): $url');
              }
            } catch (e) {
              debugPrint('Erro ao baixar imagem: $url - $e');
            }
          }),
        );
      }
    }
  }

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

    // Unifica todas as fontes de imagem do produto para garantir que nada falte no layout
    final List<ProductImage> allImgs = [];
    final Set<String> seenUris = {};

    void addIfUnique(ProductImage img) {
      final uri = img.uri.trim();
      if (uri.isNotEmpty && !seenUris.contains(uri)) {
        allImgs.add(img);
        seenUris.add(uri);
      }
    }

    // Prioridade: images > photos > remoteImages
    for (final img in product.images) {
      addIfUnique(img);
    }
    for (final ph in product.photos) {
      addIfUnique(ph.toProductImage());
    }
    for (final url in product.remoteImages) {
      addIfUnique(ProductImage.network(url: url));
    }

    if (forcedHeroPath != null && forcedHeroPath.trim().isNotEmpty) {
      photoP = _inferProductImage(forcedHeroPath);
      detailVariants = const [];
      colorVariants = const [];
    } else {
      // 1. Encontrar a foto principal (Busca por label 'P'/'principal' ou primeira da lista)
      photoP =
          allImgs.where((i) {
                final l = i.label?.toLowerCase() ?? '';
                return l == 'p' || l == 'principal';
              }).firstOrNull ??
          (allImgs.isNotEmpty ? allImgs.first : null);

      // 2. Encontrar detalhes (Busca por label 'D1'/'D2'/'detalhe' ou próximas da lista)
      var details = allImgs.where((i) {
        if (i.uri.trim() == photoP?.uri.trim()) return false;
        final l = i.label?.toLowerCase() ?? '';
        return l == 'd1' || l == 'd2' || l.startsWith('detalhe');
      }).toList();

      if (details.isEmpty && allImgs.length > 1) {
        details =
            allImgs
                .where((i) {
                  if (i.uri.trim() == photoP?.uri.trim()) return false;
                  final l = i.label?.toLowerCase() ?? '';
                  return !l.startsWith('cor') && l != 'c1' && l != 'c2';
                })
                .take(2)
                .toList();
      }
      detailVariants = details.take(2).map((img) => MapEntry('', img)).toList();

      // 3. Encontrar variantes de cor (Busca por label 'C1'-'C4' ou 'cor')
      final uniqueColors = <String, MapEntry<String, ProductImage>>{};
      final colorCandidates = allImgs.where((i) {
        if (i.colorTag != null && i.colorTag!.isNotEmpty) return true;
        final l = i.label?.toLowerCase() ?? '';
        return l == 'c1' ||
            l == 'c2' ||
            l == 'c3' ||
            l == 'c4' ||
            l.startsWith('cor');
      }).toList();

      for (final img in colorCandidates) {
        final rawLabel = img.colorTag ?? _resolveColorLabelLegacy(img.uri);
        final label = _stripColorPrefix(rawLabel);
        if (label.isNotEmpty && !uniqueColors.containsKey(label)) {
          uniqueColors[label] = MapEntry(label, img);
        }
      }
      colorVariants = uniqueColors.values.take(4).toList();
    }

    final sizesText = _extractSizesText(product);
    final topHeaderText =
        (collectionName != null && collectionName.trim().isNotEmpty)
        ? collectionName.trim()
        : defaultSubtitle;

    final availableWidth = pageFormat.width - 36;
    final availableHeight = pageFormat.height - 36;

    switch (style) {
      case CatalogPdfStyle.clean:
        return _buildClassicLayout(
          product,
          showPrice,
          displayPrice,
          photoP,
          detailVariants,
          colorVariants,
          sizesText,
          topHeaderText,
          availableWidth,
          availableHeight,
          currencyFormat,
          isClean: true,
          showDetails: false,
        );
      case CatalogPdfStyle.compact:
        return _buildCompactLayout(
          product,
          showPrice,
          displayPrice,
          photoP,
          detailVariants,
          colorVariants,
          sizesText,
          topHeaderText,
          availableWidth,
          availableHeight,
          currencyFormat,
          useDenseMode:
              false, // `products` is not available here, assuming default false
        );
      case CatalogPdfStyle.editorial:
        return _buildEditorialLayout(
          product,
          showPrice,
          displayPrice,
          photoP,
          detailVariants,
          colorVariants,
          sizesText,
          topHeaderText,
          pageFormat,
          currencyFormat,
        );
      case CatalogPdfStyle.minimal:
        return _buildMinimalLayout(
          product,
          showPrice,
          displayPrice,
          photoP,
          detailVariants,
          colorVariants,
          sizesText,
          topHeaderText,
          availableWidth,
          availableHeight,
          currencyFormat,
        );
      case CatalogPdfStyle.classic:
        return _buildClassicLayout(
          product,
          showPrice,
          displayPrice,
          photoP,
          detailVariants,
          colorVariants,
          sizesText,
          topHeaderText,
          availableWidth,
          availableHeight,
          currencyFormat,
        );
    }
  }

  static pw.Widget _buildEditorialLayout(
    Product product,
    bool showPrice,
    double displayPrice,
    ProductImage? photoP,
    List<MapEntry<String, ProductImage>> detailVariants,
    List<MapEntry<String, ProductImage>> colorVariants,
    String sizesText,
    String topHeaderText,
    PdfPageFormat pageFormat,
    NumberFormat currencyFormat,
  ) {
    final lookNumber =
        'LOOK ${(product.id.hashCode % 99).toString().padLeft(2, '0')}';

    return pw.Container(
      width: pageFormat.width,
      height: pageFormat.height,
      child: pw.Stack(
        children: [
          // 1. Full Bleed Background
          pw.Positioned.fill(
            child: photoP != null
                ? _buildImageWidget(
                    photoP,
                    height: pageFormat.height,
                    radius: 0,
                  )
                : _buildImagePlaceholder(
                    height: pageFormat.height,
                    width: pageFormat.width,
                    radius: 0,
                  ),
          ),

          // 2. Top Header (Look ID & Collection)
          pw.Positioned(
            top: 40,
            left: 40,
            right: 40,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      lookNumber,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    pw.Container(
                      height: 1,
                      width: 30,
                      color: PdfColors.white,
                      margin: const pw.EdgeInsets.only(top: 4),
                    ),
                  ],
                ),
                pw.Text(
                  topHeaderText.toUpperCase(),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    letterSpacing: 5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 3. Floating Detail Polaroids
          if (detailVariants.isNotEmpty)
            pw.Positioned(
              top: 100,
              right: 25,
              child: pw.Column(
                children: detailVariants.take(2).map((v) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 20),
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.white, width: 1),
                      boxShadow: [
                        pw.BoxShadow(
                          color: PdfColor(0, 0, 0, 0.3),
                          blurRadius: 6,
                          offset: const PdfPoint(2, 2),
                        ),
                      ],
                    ),
                    child: _buildImageWidget(
                      v.value,
                      height: 100,
                      width: 75,
                      radius: 0,
                    ),
                  );
                }).toList(),
              ),
            ),

          // 4. Bottom Info - Floating Text (No Black Box)
          pw.Positioned(
            left: 40,
            right: 40,
            bottom: 50,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                // Product Name - Cleaner, more elegant typography
                pw.Text(
                  product.name.toUpperCase(),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 30,
                    fontWeight: pw.FontWeight.normal,
                    letterSpacing: 3,
                  ),
                ),
                pw.SizedBox(height: 16),

                // Meta Info & Price Row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // REF & Sizes
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'REF: ${product.reference}',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          sizesText,
                          style: pw.TextStyle(
                            color: PdfColor(1, 1, 1, 0.8),
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),

                    // Price Column
                    if (showPrice)
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          if (product.promoEnabled)
                            pw.Text(
                              currencyFormat.format(
                                product.priceForMode(CatalogMode.varejo.name) /
                                    (1 - (product.promoPercent / 100)),
                              ),
                              style: pw.TextStyle(
                                color: PdfColor(1, 1, 1, 0.6),
                                fontSize: 14,
                                decoration: pw.TextDecoration.lineThrough,
                              ),
                            ),
                          pw.Text(
                            currencyFormat.format(displayPrice),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 38,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Visual Color Swatches - Real photos for each color
                if (colorVariants.isNotEmpty) ...[
                  pw.SizedBox(height: 25),
                  pw.Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colorVariants.take(6).map((v) {
                      return pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          _buildSwatchThumb(v.key, v.value, width: 42),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            v.key.toUpperCase(),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMinimalLayout(
    Product product,
    bool showPrice,
    double displayPrice,
    ProductImage? photoP,
    List<MapEntry<String, ProductImage>> detailVariants,
    List<MapEntry<String, ProductImage>> colorVariants,
    String sizesText,
    String topHeaderText,
    double availableWidth,
    double availableHeight,
    NumberFormat currencyFormat,
  ) {
    // Height optimized for 2-per-page (availableHeight ~300)
    final heroHeight = availableHeight * 0.45;

    return pw.Container(
      color: PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Hero Image
          pw.Container(
            height: heroHeight,
            child: photoP != null
                ? _buildImageWidget(
                    photoP,
                    height: heroHeight,
                    width: availableWidth * 0.7,
                    radius: 8,
                  )
                : _buildImagePlaceholder(
                    height: heroHeight,
                    width: availableWidth * 0.7,
                    radius: 8,
                  ),
          ),

          pw.SizedBox(height: 10),

          // Product Name
          pw.Text(
            product.name.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.normal,
              color: PdfColors.black,
              letterSpacing: 2,
            ),
          ),

          pw.SizedBox(height: 4),

          // REF & Sizes
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'REF: ${product.reference}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Container(
                width: 1,
                height: 8,
                color: PdfColors.grey300,
                margin: const pw.EdgeInsets.symmetric(horizontal: 6),
              ),
              pw.Text(
                sizesText,
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),

          pw.SizedBox(height: 8),

          // Price Section
          if (showPrice)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (product.promoEnabled) ...[
                  pw.Text(
                    currencyFormat.format(
                      product.priceForMode(CatalogMode.varejo.name) /
                          (1 - (product.promoPercent / 100)),
                    ),
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey400,
                      decoration: pw.TextDecoration.lineThrough,
                    ),
                  ),
                  pw.SizedBox(width: 6),
                ],
                pw.Text(
                  currencyFormat.format(displayPrice),
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ],
            ),

          // Color Swatches (Small photo + Name)
          if (colorVariants.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: pw.WrapAlignment.center,
              children: colorVariants.take(5).map((v) {
                return pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    _buildSwatchThumb(v.key, v.value, width: 36),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      v.key.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 6,
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
    );
  }

  static pw.Widget _buildCompactLayout(
    Product product,
    bool showPrice,
    double displayPrice,
    ProductImage? photoP,
    List<MapEntry<String, ProductImage>> detailVariants,
    List<MapEntry<String, ProductImage>> colorVariants,
    String sizesText,
    String topHeaderText,
    double availableWidth,
    double availableHeight,
    NumberFormat currencyFormat, {
    bool useDenseMode = false,
  }) {
    // Determine info 60% / photo 40%
    final photoWidth = availableWidth * 0.4;
    // final infoWidth = availableWidth * 0.6; // Not directly used

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 18),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Left: Photo
          pw.Container(
            width: photoWidth,
            height: photoWidth * 1.25, // 4:5 aspect ratio
            child: photoP != null
                ? _buildImageWidget(
                    photoP,
                    height: photoWidth * 1.25,
                    radius: 8,
                  )
                : _buildImagePlaceholder(height: photoWidth * 1.25, radius: 8),
          ),
          pw.SizedBox(width: 16),
          // Right: Info
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        product.name.toUpperCase(),
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    if (product.promoEnabled)
                      _buildBadge('-${product.promoPercent.toInt()}%'),
                  ],
                ),
                pw.Text(
                  'REF: ${product.reference}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 8),
                if (showPrice)
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        currencyFormat.format(displayPrice),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: _colorPriceGreen,
                        ),
                      ),
                      if (product.promoEnabled) ...[
                        pw.SizedBox(width: 8),
                        pw.Text(
                          currencyFormat.format(
                            product.priceForMode(CatalogMode.varejo.name) /
                                (1 - (product.promoPercent / 100)),
                          ),
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey500,
                            decoration: pw.TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                pw.SizedBox(height: 6),
                _buildSizePill(sizesText),
                pw.SizedBox(height: 6),
                // Colors Thumbnails
                if (!useDenseMode && colorVariants.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: colorVariants.take(6).map((v) {
                      return pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          _buildSwatchThumb(v.key, v.value, width: 28),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            v.key.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 6,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
                if (!useDenseMode && detailVariants.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: detailVariants
                        .take(2)
                        .map(
                          (v) => pw.Padding(
                            padding: const pw.EdgeInsets.only(right: 8),
                            child: _buildImageWidget(
                              v.value,
                              height: 45,
                              width: 36,
                              radius: 6,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildClassicLayout(
    Product product,
    bool showPrice,
    double displayPrice,
    ProductImage? photoP,
    List<MapEntry<String, ProductImage>> detailVariants,
    List<MapEntry<String, ProductImage>> colorVariants,
    String sizesText,
    String topHeaderText,
    double availableWidth,
    double availableHeight,
    NumberFormat currencyFormat, {
    bool isClean = false,
    bool showDetails = true,
  }) {
    final mainPhotoHeight = availableHeight - 35 - 175 - 15;
    final radius = isClean ? 14.0 : 0.0;
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
              style: pw.TextStyle(
                fontSize: 11,
                letterSpacing: 3,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.Container(
            height: mainPhotoHeight,
            width: availableWidth,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  child: photoP != null
                      ? _buildImageWidget(
                          photoP,
                          height: mainPhotoHeight,
                          radius: radius,
                        )
                      : _buildImagePlaceholder(
                          height: mainPhotoHeight,
                          width: availableWidth,
                          radius: radius,
                        ),
                ),
                if (showDetails && detailVariants.isNotEmpty) ...[
                  pw.SizedBox(width: 12),
                  pw.Container(
                    width: 100, // Increased for better visibility
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: detailVariants.take(3).map((v) {
                        return pw.Expanded(
                          child: pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 6),
                            child: _buildSwatchThumb(
                              v.key,
                              v.value,
                              width: 100,
                              expand: true,
                            ),
                          ),
                        );
                      }).toList(),
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
            decoration: isClean
                ? pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(12),
                  )
                : null,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        product.name.toUpperCase(),
                        maxLines: 2,
                        style: pw.TextStyle(
                          fontSize: isClean ? 17 : 15,
                          fontWeight: isClean
                              ? pw.FontWeight.normal
                              : pw.FontWeight.bold,
                          color: PdfColors.black,
                          letterSpacing: isClean ? 1.5 : 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      _buildSizePill(sizesText),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        'REF: ${product.reference}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (showPrice) ...[
                        pw.SizedBox(height: 15),
                        pw.Text(
                          currencyFormat.format(displayPrice),
                          style: pw.TextStyle(
                            fontSize: isClean ? 24 : 22,
                            fontWeight: pw.FontWeight.bold,
                            color: isClean ? PdfColors.black : _colorPriceGreen,
                          ),
                        ),
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

  static pw.Widget _buildBadge(
    String text, {
    PdfColor color = PdfColors.red800,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
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
              _buildSwatchThumb(variants[0].key, variants[0].value, width: 45),
              pw.SizedBox(width: 8),
              _buildSwatchThumb(variants[1].key, variants[1].value, width: 45),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              _buildSwatchThumb(variants[2].key, variants[2].value, width: 45),
              pw.SizedBox(width: 8),
              _buildSwatchThumb(variants[3].key, variants[3].value, width: 45),
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
          _buildSwatchThumb(variants[0].key, variants[0].value, width: 65),
          pw.SizedBox(width: 10),
          _buildSwatchThumb(variants[1].key, variants[1].value, width: 65),
        ],
      );
    } else {
      // Casos 1 ou 3
      final thumbWidth = (count == 3) ? 48.0 : 65.0;
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
            width: thumbWidth + 14,
            child: pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: small ? 7 : 8,
                letterSpacing: 0.2,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
              textAlign: pw.TextAlign.center,
              maxLines: 2,
              overflow: pw.TextOverflow.span,
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

  static ProductImage _inferProductImage(String uri) {
    if (uri.startsWith('http')) {
      return ProductImage.network(url: uri);
    } else if (uri.startsWith('data:')) {
      return ProductImage(
        id: 'memory-${uri.hashCode}',
        sourceType: ProductImageSource.memory,
        uri: uri,
      );
    } else if (uri.startsWith('blob:')) {
      return ProductImage(
        id: 'blob-${uri.hashCode}',
        sourceType: ProductImageSource.networkUrl,
        uri: uri,
      );
    } else {
      return ProductImage.local(path: uri);
    }
  }

  static pw.Widget _buildImageWidget(
    ProductImage img, {
    required double height,
    double? width,
    double radius = 0,
  }) {
    try {
      final uri = img.uri.trim();
      if (uri.isEmpty) return _buildImagePlaceholder(height: height, width: width, radius: radius);

      // Todas as imagens já foram pré-carregadas em _imageCache (usando chave trimada)
      final bytes = _imageCache[uri];

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
    // Legacy support for cover images which might be paths or URLs
    final img = _inferProductImage(path);
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

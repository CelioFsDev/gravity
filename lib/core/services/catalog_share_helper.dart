import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/core/services/catalog_pdf_service.dart';
import 'package:catalogo_ja/viewmodels/settings_viewmodel.dart';
import 'package:catalogo_ja/core/services/whatsapp_share_service.dart';
import 'package:catalogo_ja/data/repositories/products_repository.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:catalogo_ja/models/category.dart';
import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/viewmodels/products_viewmodel.dart';
import 'package:intl/intl.dart';
import 'package:catalogo_ja/core/services/photo_classification_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:catalogo_ja/core/services/catalogo_ja_package_service.dart';

class CatalogShareHelper {
  static Future<void> showShareOptions({
    required BuildContext context,
    required WidgetRef ref,
    required Catalog catalog,
  }) async {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Gerar PDF e Enviar'),
            subtitle: const Text('Gera um arquivo PDF com os produtos'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await generateAndSharePdf(context, ref, catalog);
            },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Compartilhar Link'),
            subtitle: const Text('Envia o link do cat\u00e1logo online'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await shareCatalogLink(context, ref, catalog);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Salvar PDF no dispositivo'),
            subtitle: const Text(
              'Cria uma c\u00f3pia do cat\u00e1logo em PDF nos documentos',
            ),
            onTap: () async {
              Navigator.pop(sheetContext);
              await saveCatalogPdf(context, ref, catalog);
            },
          ),
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('Exportar Pacote (.zip)'),
            subtitle: const Text('Gera um arquivo com todos os dados e fotos'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await exportAndSharePackage(context, ref, catalog);
            },
          ),
        ],
      ),
    );
  }

  static Future<void> generateAndSharePdf(
    BuildContext context,
    WidgetRef ref,
    Catalog catalog,
  ) async {
    try {
      // 1. Fetch relevant products and validate them
      final productsState = await ref.read(productsViewModelProvider.future);
      final catalogProducts = productsState.allProducts
          .where((p) => catalog.productIds.contains(p.id))
          .toList();

      if (catalogProducts.isEmpty) {
        throw Exception('Nenhum produto encontrado para este catálogo.');
      }

      final issues = _validateCatalogProducts(ref, catalogProducts);
      if (issues.isNotEmpty) {
        final proceed = await _showValidationIssuesDialog(context, issues);
        if (!proceed) return;
      }

      // 2. Fetch relevant collections for the catalog
      final availableCollections = await _getRelevantCollections(ref, catalog);

      final options = await _selectExportOptions(
        context,
        catalog,
        availableCollections,
      );
      if (options == null) return;
      if (!context.mounted) return;
      final width = MediaQuery.of(context).size.width;
      final columnsCount = width < 600 ? 1 : 2;
      if (options.useLoosePhotos) {
        final files = await _runWithLoadingDialog(
          context,
          () => _generatePerProductPdfFiles(
            ref,
            catalog,
            mode: options.mode,
            showPrice: options.showPrice,
            pdfStyle: options.pdfStyle,
          ),
        );
        if (files.isEmpty) {
          throw Exception('Nenhum produto encontrado para exportação avulsa.');
        }

        final savedPaths = <String>[];
        if (!kIsWeb) {
          for (final file in files) {
            final savedPath = await _writePdfToDevice(
              file.bytes,
              file.fileName,
            );
            savedPaths.add(savedPath);
          }
        }

        try {
          await WhatsAppShareService.shareFiles(
            files: files
                .map(
                  (f) => (
                    bytes: f.bytes,
                    fileName: f.fileName,
                    mimeType: 'application/pdf',
                  ),
                )
                .toList(),
            text: 'Confira nosso catálogo ${catalog.name}!',
          );
        } catch (shareError) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  !kIsWeb && savedPaths.isNotEmpty
                      ? 'PDFs gerados, mas não foi possível compartilhar: $shareError. '
                            'Arquivos salvos em ${p.dirname(savedPaths.first)}'
                      : 'PDFs gerados, mas não foi possível compartilhar: $shareError.',
                ),
              ),
            );
          }
          return;
        }
      } else {
        final pdfBytes = await _runWithLoadingDialog(
          context,
          () => _generatePdfBytes(
            ref,
            catalog,
            columnsCount: columnsCount,
            mode: options.mode,
            showPrice: options.showPrice,
            useLoosePhotos: false,
            pdfStyle: options.pdfStyle,
            coverTypeOverride: options.coverType,
            collectionIdOverride: options.collectionId,
          ),
        );

        final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
        final fileName = 'VITORIANA-$dateStr.PDF';
        String? savedPath;
        if (!kIsWeb) {
          savedPath = await _writePdfToDevice(pdfBytes, fileName);
        }

        try {
          await WhatsAppShareService.shareFile(
            bytes: pdfBytes,
            fileName: fileName,
            text: 'Confira nosso catálogo ${catalog.name}!',
            mimeType: 'application/pdf',
          );
        } catch (shareError) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  !kIsWeb && savedPath != null
                      ? 'PDF gerado, mas não foi possível compartilhar: $shareError. '
                            'Arquivo salvo em $savedPath'
                      : 'PDF gerado, mas não foi possível compartilhar: $shareError.',
                ),
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
      }
    }
  }

  static Future<void> exportAndSharePackage(
    BuildContext context,
    WidgetRef ref,
    Catalog catalog,
  ) async {
    try {
      // 1. Fetch relevant products and validate them
      final productsState = await ref.read(productsViewModelProvider.future);
      final catalogProducts = productsState.allProducts
          .where((p) => catalog.productIds.contains(p.id))
          .toList();

      if (catalogProducts.isEmpty) {
        throw Exception('Nenhum produto encontrado para este catálogo.');
      }

      // 2. Fetch relevant collections for the catalog
      final availableCollections = await _getRelevantCollections(ref, catalog);

      // 3. Export data package
      final packageFile = await _runWithLoadingDialog(
        context,
        () => ref
            .read(catalogoJaPackageServiceProvider)
            .exportPackageForCatalog(
              products: catalogProducts,
              collections: availableCollections,
            ),
      );

      final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final safeCatalogName = _sanitizeFileNamePart(catalog.name);
      final fileName = 'CatalogoJa_${safeCatalogName}_$dateStr.zip';

      await WhatsAppShareService.shareXFile(
        filePath: packageFile.path,
        fileName: fileName,
        text: 'Confira o pacote de dados do catálogo ${catalog.name}!',
        mimeType: 'application/zip',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao exportar pacote: $e')));
      }
    }
  }

  static Future<String> _writePdfToDevice(
    Uint8List bytes,
    String fileName,
  ) async {
    final baseDirectory =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    if (!await baseDirectory.exists()) {
      await baseDirectory.create(recursive: true);
    }

    final filePath = p.join(baseDirectory.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> shareCatalogLink(
    BuildContext context,
    WidgetRef ref,
    Catalog catalog,
  ) async {
    try {
      final settings = ref.read(settingsViewModelProvider);
      final baseUrl = settings.publicBaseUrl.isEmpty
          ? 'https://CatalogoJa.app'
          : settings.publicBaseUrl;
      final shareUrl = '$baseUrl/c/${catalog.slug}';
      await WhatsAppShareService.shareCatalog(
        catalogName: catalog.name,
        catalogUrl: shareUrl,
        mode: catalog.mode,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar link: $e')),
        );
      }
    }
  }

  static Future<void> saveCatalogPdf(
    BuildContext context,
    WidgetRef ref,
    Catalog catalog,
  ) async {
    try {
      // 1. Fetch relevant products and validate them
      final productsState = await ref.read(productsViewModelProvider.future);
      final catalogProducts = productsState.allProducts
          .where((p) => catalog.productIds.contains(p.id))
          .toList();

      if (catalogProducts.isEmpty) {
        throw Exception('Nenhum produto encontrado para este cat\u00e1logo.');
      }

      final issues = _validateCatalogProducts(ref, catalogProducts);
      if (issues.isNotEmpty) {
        final proceed = await _showValidationIssuesDialog(context, issues);
        if (!proceed) return;
      }

      // 2. Fetch relevant collections for the catalog
      final availableCollections = await _getRelevantCollections(ref, catalog);

      final options = await _selectExportOptions(
        context,
        catalog,
        availableCollections,
      );
      if (options == null) return;
      if (!context.mounted) return;
      final width = MediaQuery.of(context).size.width;
      final columnsCount = width < 600 ? 1 : 2;
      final documentsDirectory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      if (options.useLoosePhotos) {
        final files = await _runWithLoadingDialog(
          context,
          () => _generatePerProductPdfFiles(
            ref,
            catalog,
            mode: options.mode,
            showPrice: options.showPrice,
            pdfStyle: options.pdfStyle,
          ),
        );
        if (files.isEmpty) {
          throw Exception(
            'Nenhum produto encontrado para exportaÃ§Ã£o avulsa.',
          );
        }
        for (final pdf in files) {
          final filePath = p.join(documentsDirectory.path, pdf.fileName);
          final file = File(filePath);
          await file.writeAsBytes(pdf.bytes);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${files.length} PDFs salvos em ${documentsDirectory.path}',
              ),
            ),
          );
        }
      } else {
        final pdfBytes = await _runWithLoadingDialog(
          context,
          () => _generatePdfBytes(
            ref,
            catalog,
            columnsCount: columnsCount,
            mode: options.mode,
            showPrice: options.showPrice,
            useLoosePhotos: false,
            pdfStyle: options.pdfStyle,
            coverTypeOverride: options.coverType,
            collectionIdOverride: options.collectionId,
          ),
        );
        final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
        final filename = 'VITORIANA-$dateStr.PDF';
        final filePath = p.join(documentsDirectory.path, filename);
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cat\u00e1logo salvo em ${file.path}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar PDF: $e')));
      }
    }
  }

  static Future<Uint8List> _generatePdfBytes(
    WidgetRef ref,
    Catalog catalog, {
    int columnsCount = 1,
    required CatalogMode mode,
    bool showPrice = true,
    bool useLoosePhotos = false,
    CatalogPdfStyle pdfStyle = CatalogPdfStyle.classic,
    String? coverTypeOverride,
    String? collectionIdOverride,
  }) async {
    // Wait for products to load if they haven't yet
    final productsState = await ref.read(productsViewModelProvider.future);
    final allProducts = productsState.allProducts;

    final catalogProducts = allProducts
        .where((p) => catalog.productIds.contains(p.id))
        .toList();
    final bannerImagePath = catalog.banners.isNotEmpty
        ? catalog.banners.first.imagePath
        : null;
    final coverInfo = _resolveCollectionCover(
      catalogProducts,
      productsState.categories,
    );

    // Resolve which cover to show based on settings or override
    bool resolvedIncludeCover;
    CollectionCover? resolvedCollectionCover;
    String? mainCoverCollectionId;

    // Use override if provided, otherwise fallback to catalog settings
    final effectiveCoverType = coverTypeOverride ?? catalog.coverType;

    if (effectiveCoverType != null) {
      if (effectiveCoverType == 'none') {
        resolvedIncludeCover = false;
        resolvedCollectionCover = null;
      } else if (effectiveCoverType == 'standard') {
        resolvedIncludeCover = true;
        resolvedCollectionCover = null; // Forces text standard cover
      } else {
        // 'collection' or default
        resolvedIncludeCover = true;
        var cover = coverInfo.cover; // Default cover (first match)
        var usedCollectionId = coverInfo.collectionId;

        // NEW: If user selected a specific collection, try to find it
        if (collectionIdOverride != null) {
          final requestedCollection = productsState.categories.firstWhere(
            (c) => c.id == collectionIdOverride,
            orElse: () => productsState.categories.firstWhere(
              (c) => c.type == CategoryType.collection,
              orElse: () => productsState.categories.first,
            ), // fallback
          );
          if (requestedCollection.type == CategoryType.collection &&
              requestedCollection.cover != null) {
            cover = requestedCollection.cover;
            usedCollectionId = requestedCollection.id;
          }
        }

        // Fix: If user selected 'collection', ensure we try to show the image
        // even if the saved mode is 'template', provided an image exists.
        if (effectiveCoverType == 'collection' && cover != null) {
          final hasImage =
              (cover.coverImagePath?.isNotEmpty ?? false) ||
              (cover.coverMiniPath?.isNotEmpty ?? false) ||
              (cover.coverPagePath?.isNotEmpty ?? false);
          if (hasImage && cover.mode != CollectionCoverMode.image) {
            cover = cover.copyWith(mode: CollectionCoverMode.image);
          }
        }

        resolvedCollectionCover = cover;
        mainCoverCollectionId = usedCollectionId;
      }
    } else {
      // Legacy fallback
      resolvedIncludeCover = catalog.includeCover;
      resolvedCollectionCover = coverInfo.cover;
      // If legacy true, we still want to avoid dup, so track ID if we have a cover
      if (resolvedIncludeCover && resolvedCollectionCover != null) {
        mainCoverCollectionId = coverInfo.collectionId;
      }
    }

    final collectionsMap = {
      for (final c in productsState.categories)
        if (c.type == CategoryType.collection) c.id: c,
    };

    if (catalogProducts.isEmpty) {
      if (catalog.productIds.isEmpty) {
        throw Exception(
          'Este cat\u00e1logo n\u00e3o possui produtos selecionados.',
        );
      }

      // Fallback: try to fetch directly from repo in case state is stale
      final repository = ref.read(productsRepositoryProvider);
      final freshProducts = await repository.getProducts();
      final fallbackProducts = freshProducts
          .where((p) => catalog.productIds.contains(p.id))
          .toList();

      if (fallbackProducts.isEmpty) {
        throw Exception(
          'Os produtos deste cat\u00e1logo n\u00e3o foram encontrados no banco de dados.',
        );
      }

      final fallbackCoverInfo = _resolveCollectionCover(
        fallbackProducts,
        productsState.categories,
      );
      final catalogName = catalog.name.isEmpty
          ? 'Meu Cat\u00e1logo'
          : catalog.name;

      // Re-resolve for fallback (simplified)
      CollectionCover? fbCover;
      String? fbId;

      // Use override logic for fallback too
      final effectiveFallbackCoverType = coverTypeOverride ?? catalog.coverType;

      if (resolvedIncludeCover) {
        if (effectiveFallbackCoverType == 'standard') {
          fbCover = null;
        } else {
          fbCover = fallbackCoverInfo.cover;
          fbId = fallbackCoverInfo.collectionId;
        }
      }

      return CatalogPdfService.generateCatalogPdf(
        catalogName: catalogName,
        products: fallbackProducts,
        columnsCount: columnsCount,
        mode: mode,
        showPrice: showPrice,
        useLoosePhotos: useLoosePhotos,
        style: pdfStyle,
        bannerImagePath: bannerImagePath,
        collectionCover: fbCover,
        collectionName: fallbackCoverInfo.name,
        includeCover: resolvedIncludeCover,
        collectionsMap: collectionsMap,
        mainCoverCollectionId: fbId,
      );
    }

    final catalogName = catalog.name.isEmpty
        ? 'Meu Cat\u00e1logo'
        : catalog.name;
    return CatalogPdfService.generateCatalogPdf(
      catalogName: catalogName,
      products: catalogProducts,
      columnsCount: columnsCount,
      mode: mode,
      showPrice: showPrice,
      useLoosePhotos: useLoosePhotos,
      style: pdfStyle,
      bannerImagePath: bannerImagePath,
      collectionCover: resolvedCollectionCover,
      collectionName: coverInfo.name,
      includeCover: resolvedIncludeCover,
      collectionsMap: collectionsMap,
      mainCoverCollectionId: mainCoverCollectionId,
    );
  }

  static Future<T> _runWithLoadingDialog<T>(
    BuildContext context,
    Future<T> Function() action,
  ) async {
    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      return await action();
    } finally {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }
    }
  }

  static Future<CatalogExportOptions?> _selectExportOptions(
    BuildContext context,
    Catalog catalog,
    List<Category> availableCollections,
  ) async {
    CatalogMode selectedMode = CatalogMode.varejo;
    bool showPrice = true;
    bool useLoosePhotos = false;
    CatalogPdfStyle selectedPdfStyle = CatalogPdfStyle.classic;
    String selectedCoverType =
        'collection'; // Default to collection/custom if available
    String? selectedCollectionId = availableCollections.isNotEmpty
        ? availableCollections.first.id
        : null;

    return showModalBottomSheet<CatalogExportOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);

            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppTokens.radiusLg),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 8,
                left: 24,
                right: 24,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.86,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Op\u00e7\u00f5es de Exporta\u00e7\u00e3o',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // PRICE SECTION
                            _buildSubHeader(context, 'Pre\u00e7o no PDF'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildOptionCard(
                                  context,
                                  label: 'Varejo',
                                  isSelected:
                                      showPrice &&
                                      selectedMode == CatalogMode.varejo,
                                  onTap: () => setState(() {
                                    showPrice = true;
                                    selectedMode = CatalogMode.varejo;
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _buildOptionCard(
                                  context,
                                  label: 'Atacado',
                                  isSelected:
                                      showPrice &&
                                      selectedMode == CatalogMode.atacado,
                                  onTap: () => setState(() {
                                    showPrice = true;
                                    selectedMode = CatalogMode.atacado;
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _buildOptionCard(
                                  context,
                                  label: 'Sem PreÃ§o',
                                  isSelected: !showPrice,
                                  onTap: () =>
                                      setState(() => showPrice = false),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // PHOTO SECTION
                            _buildSubHeader(context, 'Fotos no PDF'),
                            const SizedBox(height: 12),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Fotos avulsas',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: const Text(
                                'Gera 1 PDF por peça (nome + referência).',
                              ),
                              value: useLoosePhotos,
                              onChanged: (value) =>
                                  setState(() => useLoosePhotos = value),
                              activeThumbColor: AppTokens.accentBlue,
                            ),
                            const SizedBox(height: 24),

                            // STYLE SECTION
                            _buildSubHeader(context, 'Estilo do Layout'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: CatalogPdfStyle.values.map((style) {
                                final isSelected = selectedPdfStyle == style;
                                return ChoiceChip(
                                  label: Text(_pdfStyleLabel(style)),
                                  selected: isSelected,
                                  onSelected: (_) =>
                                      setState(() => selectedPdfStyle = style),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),

                            // COVER SECTION
                            _buildSubHeader(context, 'Capa do Cat\u00e1logo'),
                            const SizedBox(height: 12),
                            _buildCoverTypeTile(
                              context,
                              title: 'Capa da Cole\u00e7\u00e3o (Com Foto)',
                              subtitle:
                                  'Usa a imagem principal da cole\u00e7\u00e3o',
                              isSelected: selectedCoverType == 'collection',
                              icon: Icons.image_outlined,
                              onTap: () => setState(
                                () => selectedCoverType = 'collection',
                              ),
                            ),
                            if (selectedCoverType == 'collection' &&
                                availableCollections.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  left: 12,
                                  right: 12,
                                ),
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedCollectionId,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Selecione a Cole\u00e7\u00e3o',
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                  ),
                                  items: availableCollections.map((c) {
                                    return DropdownMenuItem<String>(
                                      value: c.id,
                                      child: Text(c.safeName),
                                    );
                                  }).toList(),
                                  onChanged: (v) =>
                                      setState(() => selectedCollectionId = v),
                                ),
                              ),
                            const SizedBox(height: 8),
                            _buildCoverTypeTile(
                              context,
                              title: 'Capa Padr\u00e3o (Texto)',
                              subtitle:
                                  'Apenas logo e t\u00edtulo centralizado',
                              isSelected: selectedCoverType == 'standard',
                              icon: Icons.text_fields,
                              onTap: () => setState(
                                () => selectedCoverType = 'standard',
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildCoverTypeTile(
                              context,
                              title: 'Sem Capa',
                              subtitle: 'Inicia direto na lista de produtos',
                              isSelected: selectedCoverType == 'none',
                              icon: Icons.block,
                              onTap: () =>
                                  setState(() => selectedCoverType = 'none'),
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ACTIONS
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(
                              sheetContext,
                              CatalogExportOptions(
                                selectedMode,
                                selectedCoverType,
                                selectedCollectionId,
                                showPrice,
                                useLoosePhotos,
                                selectedPdfStyle,
                              ),
                            ),
                            child: const Text(
                              'Gerar PDF',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildSubHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
      ),
    );
  }

  static Widget _buildOptionCard(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildCoverTypeTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.05)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  /// Fetches and filters collections that have products in the given [catalog].
  static Future<List<Category>> _getRelevantCollections(
    WidgetRef ref,
    Catalog catalog,
  ) async {
    final productsState = await ref.read(productsViewModelProvider.future);
    final allProducts = productsState.allProducts;
    final catalogProducts = allProducts
        .where((p) => catalog.productIds.contains(p.id))
        .toList();

    // Filter collections that have products in this catalog
    final catalogCollectionIds = catalogProducts
        .expand((p) => p.categoryIds)
        .toSet();

    return productsState.categories
        .where(
          (c) =>
              c.type == CategoryType.collection &&
              catalogCollectionIds.contains(c.id),
        )
        .toList();
  }

  static Map<Product, List<PhotoValidationIssue>> _validateCatalogProducts(
    WidgetRef ref,
    List<Product> products,
  ) {
    final validationService = ref.read(
      photoClassificationServiceProvider.notifier,
    );
    final results = <Product, List<PhotoValidationIssue>>{};

    for (final product in products) {
      final issues = validationService.validateProductPhotos(product);
      if (issues.isNotEmpty) {
        results[product] = issues;
      }
    }

    return results;
  }

  static Future<bool> _showValidationIssuesDialog(
    BuildContext context,
    Map<Product, List<PhotoValidationIssue>> results,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                const Text('Pend\u00eancias de Fotos'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Os seguintes produtos possuem problemas nas fotos que podem afetar o layout do PDF:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...results.entries.map((entry) {
                      final product = entry.key;
                      final issues = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${product.ref} - ${product.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ...issues.map(
                              (issue) => Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  top: 2,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '\u2022 ',
                                      style: TextStyle(
                                        color: issue.isCritical
                                            ? Colors.red
                                            : Colors.orange,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        issue.message,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: issue.isCritical
                                              ? Colors.red
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('CORRIGIR AGORA'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('GERAR MESMO ASSIM'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class CatalogExportOptions {
  final CatalogMode mode;
  final String coverType;
  final String? collectionId;
  final bool showPrice;
  final bool useLoosePhotos;
  final CatalogPdfStyle pdfStyle;
  CatalogExportOptions(
    this.mode,
    this.coverType,
    this.collectionId,
    this.showPrice,
    this.useLoosePhotos,
    this.pdfStyle,
  );
}

class _GeneratedPdfFile {
  final String fileName;
  final Uint8List bytes;

  const _GeneratedPdfFile({required this.fileName, required this.bytes});
}

String _sanitizeFileNamePart(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .replaceAll(RegExp(r'\s+'), '_');
}

Future<List<_GeneratedPdfFile>> _generatePerProductPdfFiles(
  WidgetRef ref,
  Catalog catalog, {
  required CatalogMode mode,
  required bool showPrice,
  required CatalogPdfStyle pdfStyle,
}) async {
  final productsState = await ref.read(productsViewModelProvider.future);
  final catalogProducts = productsState.allProducts
      .where((p) => catalog.productIds.contains(p.id))
      .toList();

  final usedNames = <String, int>{};
  final files = <_GeneratedPdfFile>[];

  for (final product in catalogProducts) {
    final pdfBytes = await CatalogPdfService.generateCatalogPdf(
      catalogName: catalog.name.isEmpty ? 'Meu CatÃ¡logo' : catalog.name,
      products: [product],
      mode: mode,
      showPrice: showPrice,
      includeCover: false,
      collectionsMap: null,
      useLoosePhotos: false,
      style: pdfStyle,
    );

    final baseName =
        '${_sanitizeFileNamePart(product.name)}-${_sanitizeFileNamePart(product.reference)}';
    final count = (usedNames[baseName] ?? 0) + 1;
    usedNames[baseName] = count;
    final uniqueName = count == 1 ? baseName : '${baseName}_$count';

    files.add(_GeneratedPdfFile(fileName: '$uniqueName.pdf', bytes: pdfBytes));
  }

  return files;
}

String _pdfStyleLabel(CatalogPdfStyle style) {
  return switch (style) {
    CatalogPdfStyle.classic => 'Clássico',
    CatalogPdfStyle.clean => 'Clean',
    CatalogPdfStyle.compact => 'Compacto',
    CatalogPdfStyle.editorial => 'Editorial',
    CatalogPdfStyle.minimal => 'Minimalista',
  };
}

class _CollectionCoverResult {
  final CollectionCover? cover;
  final String? name;
  final String? collectionId;

  const _CollectionCoverResult(this.cover, this.name, this.collectionId);
}

_CollectionCoverResult _resolveCollectionCover(
  List<Product> products,
  List<Category> categories,
) {
  if (products.isEmpty || categories.isEmpty) {
    return const _CollectionCoverResult(null, null, null);
  }

  final collections = <String, Category>{
    for (final category in categories)
      if (category.type == CategoryType.collection) category.id: category,
  };

  if (collections.isEmpty) {
    return const _CollectionCoverResult(null, null, null);
  }

  final matchedIds = <String>{};
  for (final product in products) {
    for (final id in product.categoryIds) {
      if (collections.containsKey(id)) {
        matchedIds.add(id);
      }
    }
  }

  if (matchedIds.isEmpty) {
    return const _CollectionCoverResult(null, null, null);
  }

  // Use the first matched collection cover
  final collectionId = matchedIds.first;
  final collection = collections[collectionId];
  if (collection == null) return const _CollectionCoverResult(null, null, null);

  return _CollectionCoverResult(
    collection.cover,
    collection.safeName,
    collectionId,
  );
}

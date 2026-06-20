import 'package:catalogo_ja/models/product.dart';
import 'package:catalogo_ja/models/product_image.dart';

/// Retorna se [uri] já pode ser usada pela nuvem sem reler um arquivo local.
bool isCloudImageUri(String uri) {
  final trimmed = uri.trim();
  return trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('gs://') ||
      trimmed.startsWith('tenants/') ||
      trimmed.startsWith('public_catalogs/');
}

/// Procura uma URL remota equivalente a uma imagem local.
///
/// Imagens importadas antes do uso na web podem ter o arquivo baixado salvo
/// apenas no dispositivo, mas ainda mantêm a URL original em [remoteImages] ou
/// na lista legada de [Product.photos]. O navegador não consegue reler esse
/// arquivo local; nesse caso reutilizamos a URL já conhecida em vez de tentar
/// fazer upload sem bytes.
String? findCloudImageFallback({
  required Product product,
  required ProductImage image,
  required int imageIndex,
}) {
  final candidates = <ProductImage>[];
  final seenUris = <String>{};

  void addCandidate(ProductImage candidate) {
    final uri = candidate.uri.trim();
    if (!isCloudImageUri(uri) || !seenUris.add(uri)) return;
    candidates.add(candidate.copyWith(uri: uri));
  }

  for (final photo in product.photos) {
    addCandidate(photo.toProductImage());
  }
  for (final remoteUrl in product.remoteImages) {
    addCandidate(ProductImage.network(url: remoteUrl));
  }
  for (final productImage in product.images) {
    addCandidate(productImage);
  }

  String normalized(String? value) => value?.trim().toLowerCase() ?? '';
  final label = normalized(image.label);
  final colorTag = normalized(image.colorTag);

  final sameLabelAndColor = candidates
      .where(
        (candidate) =>
            label.isNotEmpty &&
            normalized(candidate.label) == label &&
            colorTag.isNotEmpty &&
            normalized(candidate.colorTag) == colorTag,
      )
      .toList();
  if (sameLabelAndColor.length == 1) return sameLabelAndColor.single.uri;

  final sameLabel = candidates
      .where(
        (candidate) =>
            label.isNotEmpty && normalized(candidate.label) == label,
      )
      .toList();
  if (sameLabel.length == 1) return sameLabel.single.uri;

  final sameColor = candidates
      .where(
        (candidate) =>
            colorTag.isNotEmpty && normalized(candidate.colorTag) == colorTag,
      )
      .toList();
  if (sameColor.length == 1) return sameColor.single.uri;

  if (imageIndex < product.images.length) {
    final sameSlot = product.images[imageIndex];
    if (isCloudImageUri(sameSlot.uri)) return sameSlot.uri.trim();
  }

  if (imageIndex < product.photos.length) {
    final photo = product.photos[imageIndex].toProductImage();
    if (isCloudImageUri(photo.uri)) return photo.uri.trim();
  }

  if (imageIndex < product.remoteImages.length) {
    final remoteUrl = product.remoteImages[imageIndex].trim();
    if (isCloudImageUri(remoteUrl)) return remoteUrl;
  }

  return candidates.length == 1 ? candidates.single.uri : null;
}

class CloudDiagnosticResult {
  final int localProducts;
  final int cloudProducts;
  final int localPhotos;
  final int cloudPhotosWithUrl;
  final List<String> productsWithLocalPhotoButNoCloudUrl;
  final int localPromotions;
  final int cloudPromotions;
  final int localCatalogs;
  final int cloudCatalogs;

  CloudDiagnosticResult({
    required this.localProducts,
    required this.cloudProducts,
    required this.localPhotos,
    required this.cloudPhotosWithUrl,
    required this.productsWithLocalPhotoButNoCloudUrl,
    required this.localPromotions,
    required this.cloudPromotions,
    required this.localCatalogs,
    required this.cloudCatalogs,
  });
}

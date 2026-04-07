class ApiConfig {
  // Alterar para o IP do seu servidor/máquina local se estiver testando em dispositivo físico
  static const String baseUrl = 'http://localhost:8080';
  
  // Endpoints
  static const String uploadProductImage = '$baseUrl/api/v1/upload/product-image';
  static const String uploadCategoryCover = '$baseUrl/api/v1/upload/category-cover';
  static const String uploadCatalogBanner = '$baseUrl/api/v1/upload/catalog-banner';
  static const String uploadCatalogPdf = '$baseUrl/api/v1/upload/catalog-pdf';
  static const String uploadProfileAvatar = '$baseUrl/api/v1/upload/profile-avatar';
  static const String getFileUrl = '$baseUrl/api/v1/file-url';
  static const String deleteFile = '$baseUrl/api/v1/file';
  static const String deleteProductImages = '$baseUrl/api/v1/product-images';
}

class PublicCatalogConfig {
  static const defaultBaseUrl = 'https://catalogo-ja-89aae.web.app';

  static String normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    final lower = trimmed.toLowerCase();
    if (trimmed.isEmpty ||
        lower == 'https://catalogoja.app' ||
        lower == 'http://catalogoja.app' ||
        lower == 'catalogoja.app' ||
        lower == 'https://catalogo-ja.app' ||
        lower == 'http://catalogo-ja.app' ||
        lower == 'catalogo-ja.app') {
      return defaultBaseUrl;
    }

    var normalized = trimmed;
    if (normalized.contains('#')) {
      normalized = normalized.split('#').first;
    }
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    if (normalized.startsWith('http://')) {
      normalized = normalized.replaceFirst('http://', 'https://');
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static String buildCatalogUrl(
    String baseUrl,
    String shareCode, {
    String? whatsappNumber,
  }) {
    final normalized = normalizeBaseUrl(baseUrl);
    final query = <String, String>{
      if (whatsappNumber != null && whatsappNumber.trim().isNotEmpty)
        'w': whatsappNumber.trim(),
    };
    final route = Uri(
      path: '/c/${shareCode.trim().toLowerCase()}',
      queryParameters: query.isEmpty ? null : query,
    ).toString();

    return '$normalized/#$route';
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

class NuvemshopApiClient {
  final String storeId;
  final String accessToken;
  final String baseUrl;
  final String userAgent;

  NuvemshopApiClient({
    required this.storeId,
    required this.accessToken,
    this.baseUrl = 'https://api.nuvemshop.com.br',
    this.userAgent = 'CatalogoJa Importer (contato@CatalogoJa.local)',
  });

  Future<List<String>> getProductImageUrlsBySku(String sku) async {
    final normalizedSku = sku.trim();
    if (normalizedSku.isEmpty) return const [];

    final uri = Uri.parse(
      '$baseUrl/v1/$storeId/products/sku/${Uri.encodeComponent(normalizedSku)}',
    );
    final response = await http.get(
      uri,
      headers: {
        'Authentication': 'bearer $accessToken',
        'User-Agent': userAgent,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    dynamic payload;
    try {
      payload = jsonDecode(response.body);
    } catch (_) {
      return const [];
    }

    if (payload is! Map<String, dynamic>) return const [];
    final images = payload['images'];
    if (images is! List) return const [];

    final urls = <String>[];
    for (final image in images) {
      if (image is! Map) continue;
      final src = image['src']?.toString().trim() ?? '';
      if (src.isNotEmpty) urls.add(src);
    }

    return urls.toSet().toList();
  }
}


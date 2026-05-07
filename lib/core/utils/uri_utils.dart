import 'package:flutter/foundation.dart';

class UriUtils {
  /// Checks if the given URI is a valid network image URI (http or https with a host).
  static bool isNetworkImageUri(String uri) {
    if (uri.isEmpty) return false;
    final parsed = Uri.tryParse(uri);
    if (parsed == null) return false;
    
    // Support for blob: URIs on Web
    if (parsed.scheme == 'blob') {
      return kIsWeb && uri.length > 'blob:'.length;
    }
    
    // Must be http or https and have a non-empty host
    return (parsed.scheme == 'http' || parsed.scheme == 'https') &&
        parsed.host.isNotEmpty;
  }

  /// Checks if the given URI is a usable image path (not empty, not just relative segments, not local file).
  static bool isUsableImagePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == '.' || trimmed == '/') return false;
    if (trimmed.startsWith('file:')) return false;
    return true;
  }
}

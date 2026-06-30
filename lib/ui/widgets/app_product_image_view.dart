import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:catalogo_ja/core/utils/uri_utils.dart';

class AppProductImageView extends StatelessWidget {
  const AppProductImageView({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
  });

  static const _storageBucket = 'gs://catalogo-ja-89aae.firebasestorage.app';
  static final Map<String, Future<String?>> _downloadUrlCache = {};

  final String? imageUrl;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();

    if (url == null || url.isEmpty || !UriUtils.isUsableImagePath(url)) {
      return _placeholder();
    }

    // Firebase Storage URI/path: gs://bucket/path or tenants/... saved in Firestore.
    if (_isFirebaseStorageReference(url)) {
      return FutureBuilder<String?>(
        future: _downloadUrlCache.putIfAbsent(url, () => _getDownloadUrl(url)),
        builder: (context, snapshot) {
          final resolvedUrl = snapshot.data;
          if (resolvedUrl == null || resolvedUrl.isEmpty) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _loadingPlaceholder();
            }
            return _placeholder(icon: Icons.cloud_off);
          }
          return _buildNetworkImage(resolvedUrl);
        },
      );
    }

    // Data URI (web browser bytes)
    if (url.startsWith('data:')) {
      return _buildDataUrlImage(url);
    }

    // HTTP/HTTPS Network Image
    if (UriUtils.isNetworkImageUri(url)) {
      return _buildNetworkImage(url);
    }

    // Local file path (Mobile/Desktop only)
    if (!kIsWeb) {
      try {
        final file = File(url);
        if (file.existsSync() &&
            file.statSync().type != FileSystemEntityType.directory) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.file(
              file,
              width: width,
              height: height,
              fit: fit,
            ),
          );
        }
      } catch (_) {}
    }

    return _placeholder();
  }

  Widget _buildNetworkImage(String uri) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: uri,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _loadingPlaceholder(),
        errorWidget: (context, url, error) {
          debugPrint('Erro ao carregar imagem do produto: $url');
          debugPrint('Erro: $error');
          return _placeholder();
        },
      ),
    );
  }

  Widget _buildDataUrlImage(String uri) {
    try {
      final commaIndex = uri.indexOf(',');
      if (commaIndex == -1) return _placeholder();
      final bytes = base64Decode(uri.substring(commaIndex + 1));
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
        ),
      );
    } catch (_) {
      return _placeholder();
    }
  }

  Widget _placeholder({IconData icon = Icons.image_not_supported_outlined}) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        icon,
        color: const Color(0xFF94A3B8),
        size: 32,
      ),
    );
  }

  Widget _loadingPlaceholder() {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFCBD5E1),
        ),
      ),
    );
  }

  Future<String?> _getDownloadUrl(String storageUri) async {
    try {
      final storage = FirebaseStorage.instanceFor(bucket: _storageBucket);
      final ref = storageUri.startsWith('gs://')
          ? storage.refFromURL(storageUri)
          : storage.ref(_storagePathFrom(storageUri));
      return await ref.getDownloadURL();
    } catch (error) {
      debugPrint('Erro ao resolver imagem do Firebase Storage: $storageUri');
      debugPrint('Erro: $error');
      return null;
    }
  }

  bool _isFirebaseStorageReference(String uri) {
    final trimmed = _storagePathFrom(uri);
    return trimmed.startsWith('gs://') ||
        trimmed.startsWith('tenants/') ||
        trimmed.startsWith('public_catalogs/') ||
        trimmed.startsWith('users/');
  }

  String _storagePathFrom(String uri) {
    final trimmed = uri.trim();
    if (trimmed.startsWith('gs://')) return trimmed;
    return trimmed.replaceFirst(RegExp(r'^/+'), '');
  }
}

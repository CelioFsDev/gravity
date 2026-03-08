import 'package:catalogo_ja/models/product.dart';
import 'package:diacritic/diacritic.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photo_classification_service.g.dart';

class PhotoClassification {
  final String ref;
  final String photoType;
  final String? colorName;
  final String standardName;

  PhotoClassification({
    required this.ref,
    required this.photoType,
    this.colorName,
    required this.standardName,
  });
}

class PhotoValidationIssue {
  final String message;
  final bool isCritical;
  final String? photoType;

  PhotoValidationIssue({
    required this.message,
    this.isCritical = false,
    this.photoType,
  });
}

@riverpod
class PhotoClassificationService extends _$PhotoClassificationService {
  @override
  void build() {}

  static const String typePrimary = 'P';
  static const String typeDetail1 = 'D1';
  static const String typeDetail2 = 'D2';
  static const String typeColor = 'C';

  List<PhotoValidationIssue> validateProductPhotos(Product product) {
    final issues = <PhotoValidationIssue>[];
    final photos = product.photos;

    // 1. Missing Primary
    final hasPrimary = photos.any((p) => p.photoType == typePrimary);
    if (!hasPrimary) {
      issues.add(
        PhotoValidationIssue(
          message: 'Foto Principal (P) n\u00e3o encontrada.',
          isCritical: true,
          photoType: typePrimary,
        ),
      );
    }

    // 2. Missing Details (Optional)
    final hasD1 = photos.any((p) => p.photoType == typeDetail1);
    if (!hasD1) {
      issues.add(
        PhotoValidationIssue(
          message: 'Foto Detalhe 1 (D1) n\u00e3o encontrada.',
          photoType: typeDetail1,
        ),
      );
    }

    final hasD2 = photos.any((p) => p.photoType == typeDetail2);
    if (!hasD2) {
      issues.add(
        PhotoValidationIssue(
          message: 'Foto Detalhe 2 (D2) n\u00e3o encontrada.',
          photoType: typeDetail2,
        ),
      );
    }

    // 3. Unidentified Colors
    for (final photo in photos) {
      if (photo.photoType != null && photo.photoType!.startsWith('C')) {
        if (photo.colorKey == null || photo.colorKey!.trim().isEmpty) {
          issues.add(
            PhotoValidationIssue(
              message:
                  'Foto de cor (${photo.photoType}) sem identificacao de nome.',
              photoType: photo.photoType,
            ),
          );
        }
      }
    }

    return issues;
  }

  PhotoClassification? classifyFileName(String fileName) {
    // Accepted examples:
    // 106603_p.jpg / 106603_principal.jpg
    // 106603_d1.jpg / 106603_d2.jpg
    // 106603_detalhe1.jpg / 106603_detalhe2.jpg
    // 106603_preto.jpg / 106603_cor_preto.jpg
    // Legacy compatibility: 106603_referencia_principal.jpg
    final parsed = RegExp(
      r'^(\d+)[_\-\s]+(.+)\.([a-z0-9]+)$',
      caseSensitive: false,
    ).firstMatch(fileName);
    if (parsed == null) return null;

    final ref = parsed.group(1)!;
    final suffixRaw = parsed.group(2)!;
    final extension = parsed.group(3)!;

    var tokens = suffixRaw
        .split(RegExp(r'[_\-\s]+'))
        .map((t) => removeDiacritics(t).toLowerCase().trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;

    // Ignore legacy connector word.
    if (tokens.first == 'referencia') {
      tokens = tokens.skip(1).toList();
    }
    if (tokens.isEmpty) return null;

    String photoType;
    String? colorName;

    final first = tokens.first;
    final colorPrefixMatch = RegExp(r'^c([1-4])$').firstMatch(first);

    if (first == 'p' || first == 'principal') {
      photoType = typePrimary;
    } else if (first == 'd1' ||
        first == 'detalhe1' ||
        (first == 'detalhe' && tokens.length > 1 && tokens[1] == '1')) {
      photoType = typeDetail1;
    } else if (first == 'd2' ||
        first == 'detalhe2' ||
        (first == 'detalhe' && tokens.length > 1 && tokens[1] == '2')) {
      photoType = typeDetail2;
    } else if (colorPrefixMatch != null) {
      photoType = 'C${colorPrefixMatch.group(1)}';
      tokens = tokens.skip(1).toList();
      if (tokens.isNotEmpty) {
        colorName = normalizeColor(tokens.join('_'));
      }
    } else {
      photoType = typeColor;
      if (first == 'cor') {
        tokens = tokens.skip(1).toList();
      }
      if (tokens.isEmpty) return null;
      colorName = normalizeColor(tokens.join('_'));
    }

    final standardName = buildInternalName(
      ref,
      photoType,
      colorName,
      extension,
    );

    return PhotoClassification(
      ref: ref,
      photoType: photoType,
      colorName: colorName,
      standardName: standardName,
    );
  }

  String normalizeColor(String color) {
    // azul_marinho -> AZUL MARINHO
    // róseo_claro -> ROSEO CLARO
    // preto -> PRETO
    String normalized = color.replaceAll('_', ' ');
    normalized = removeDiacritics(normalized);
    normalized = normalized.trim().toUpperCase();
    return normalized;
  }

  String buildInternalName(
    String ref,
    String photoType,
    String? colorName,
    String extension,
  ) {
    // {REF}__P.jpg
    // {REF}__C1__PRETO.jpg
    if (photoType.startsWith('C')) {
      final suffix = colorName != null ? '__$colorName' : '';
      // Garante que se o tipo for apenas 'C', usamos o placeholder {N} para ser preenchido pela organização
      final typeStr = photoType == 'C' ? 'C{N}' : photoType;
      return '${ref}__$typeStr$suffix.$extension';
    } else {
      return '${ref}__$photoType.$extension';
    }
  }

  /// Reorganizes colors to ensure PRETO is C1, and others are C2-C4.
  /// Max 4 colors.
  List<ProductPhoto> organizeColors(
    List<ProductPhoto> existingPhotos,
    ProductPhoto newPhoto,
  ) {
    final newType = newPhoto.photoType ?? '';
    if (!newType.startsWith('C')) return existingPhotos;

    final colorPhotos = existingPhotos
        .where((p) => p.photoType != null && p.photoType!.startsWith('C'))
        .toList();
    final nonColorPhotos = existingPhotos
        .where((p) => p.photoType == null || !p.photoType!.startsWith('C'))
        .toList();

    // Check if color already exists (by name or same Cx slot)
    final newColorName = _getColorNameFromPath(newPhoto.path);
    final existingColorIdx = colorPhotos.indexWhere((p) {
      if (newColorName.isNotEmpty &&
          _getColorNameFromPath(p.path) == newColorName) {
        return true;
      }
      // Se tivermos um slot explícito no arquivo original (ex: C1) e o novo também for C1, substitui
      return newType != 'C' && p.photoType == newType;
    });

    if (existingColorIdx != -1) {
      colorPhotos[existingColorIdx] = newPhoto;
    } else {
      if (colorPhotos.length >= 4) {
        // Se já temos 4 e a nova cor não é PRETO para forçar entrada, bloqueia
        if (newColorName != 'PRETO') {
          return existingPhotos;
        }
        // Se for PRETO, vamos substituir a última cor para manter o limite de 4
        colorPhotos.removeLast();
      }
      colorPhotos.add(newPhoto);
    }

    // Sort: PRETO first, then others alphabetically by color name.
    colorPhotos.sort((a, b) {
      final nameA = _getColorNameFromPath(a.path);
      final nameB = _getColorNameFromPath(b.path);
      if (nameA == 'PRETO') return -1;
      if (nameB == 'PRETO') return 1;
      return nameA.compareTo(nameB);
    });

    // Re-assign C1-C4 only if they don't have explicit types or to normalize
    final organizedColors = colorPhotos.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final photo = entry.value;
      final type = 'C$idx';
      // Atualiza o colorKey se estiver vazio usando o nome do arquivo
      final colorKey = photo.colorKey ?? _getColorNameFromPath(photo.path);
      return photo.copyWith(photoType: type, colorKey: colorKey);
    }).toList();

    return [...nonColorPhotos, ...organizedColors];
  }

  String _getColorNameFromPath(String path) {
    // 106603__C1__PRETO.jpg -> PRETO
    final fileName = p.basename(path);
    final parts = fileName.split('__');
    if (parts.length >= 3) {
      final lastPart = parts.last; // PRETO.jpg ou C1 VERMELHO.jpg
      String name = lastPart.split('.').first;
      // Limpa prefixos legados como "C1 " se existirem no nome da cor
      name = name.replaceFirst(RegExp(r'^C[1-4]\s+'), '');
      return name;
    }
    return '';
  }
}

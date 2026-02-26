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
      issues.add(PhotoValidationIssue(
        message: 'Foto Principal (P) n\u00e3o encontrada.',
        isCritical: true,
        photoType: typePrimary,
      ));
    }

    // 2. Missing Details (Optional)
    final hasD1 = photos.any((p) => p.photoType == typeDetail1);
    if (!hasD1) {
      issues.add(PhotoValidationIssue(
        message: 'Foto Detalhe 1 (D1) n\u00e3o encontrada.',
        photoType: typeDetail1,
      ));
    }

    final hasD2 = photos.any((p) => p.photoType == typeDetail2);
    if (!hasD2) {
      issues.add(PhotoValidationIssue(
        message: 'Foto Detalhe 2 (D2) n\u00e3o encontrada.',
        photoType: typeDetail2,
      ));
    }

    // 3. Unidentified Colors
    for (final photo in photos) {
      if (photo.photoType != null && photo.photoType!.startsWith('C')) {
        if (photo.colorKey == null || photo.colorKey!.trim().isEmpty) {
          issues.add(PhotoValidationIssue(
            message: 'Foto de cor (${photo.photoType}) sem identificacao de nome.',
            photoType: photo.photoType,
          ));
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
      r'^(\d+)[_\-\s]+(.+)\.(jpg|jpeg|png|webp)$',
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

  String buildInternalName(String ref, String photoType, String? colorName, String extension) {
    // {REF}__P.jpg
    // {REF}__C{N}__{COR}.jpg
    // Note: {N} needs to be determined by the context (existing photos), 
    // but the pattern provided in requirements is {REF}__C{N}__{COR}.jpg
    // For now, let's use a placeholder for {N} or return the base pattern.
    // The requirement 4.1 says: {REF}__C{N}__{COR}.jpg
    
    if (photoType == typeColor) {
      return '${ref}__C{N}__$colorName.$extension';
    } else {
      return '${ref}__$photoType.$extension';
    }
  }

  /// Reorganizes colors to ensure PRETO is C1, and others are C2-C4.
  /// Max 4 colors.
  List<ProductPhoto> organizeColors(List<ProductPhoto> existingPhotos, ProductPhoto newPhoto) {
    if (newPhoto.photoType != typeColor) return existingPhotos;

    final colorPhotos = existingPhotos.where((p) => p.photoType != null && p.photoType!.startsWith('C')).toList();
    final nonColorPhotos = existingPhotos.where((p) => p.photoType == null || !p.photoType!.startsWith('C')).toList();

    // Check if color already exists (by name)
    final newColorName = _getColorNameFromPath(newPhoto.path);
    final existingColorIdx = colorPhotos.indexWhere((p) => _getColorNameFromPath(p.path) == newColorName);

    if (existingColorIdx != -1) {
      colorPhotos[existingColorIdx] = newPhoto;
    } else {
      if (colorPhotos.length >= 4) {
        // Limit reached, but we might be replacing one if PRETO comes in?
        // Actually 7.3 says: Se já existir C1..C4 completos: bloquear a 5ª cor.
        // But 3.2 says if PRETO comes after, reorganize.
        // Let's check if new is PRETO.
        if (newColorName == 'PRETO') {
          // If PRETO enters and we have 4, we must replace or block?
          // "Se já existir C1..C4 completos: bloquear a 5ª cor"
          // This implies if we have 4 DIFFERENT colors, the 5th is blocked.
          // If PRETO is one of the 4, it will just replace or stay at C1.
          return existingPhotos; // Should be handled by caller to block.
        }
        return existingPhotos;
      }
      colorPhotos.add(newPhoto);
    }

    // Sort: PRETO first, then others alphabetically.
    colorPhotos.sort((a, b) {
      final nameA = _getColorNameFromPath(a.path);
      final nameB = _getColorNameFromPath(b.path);
      if (nameA == 'PRETO') return -1;
      if (nameB == 'PRETO') return 1;
      return nameA.compareTo(nameB);
    });

    // Re-assign C1-C4
    final organizedColors = colorPhotos.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final photo = entry.value;
      final type = 'C$idx';
      final newPath = _updatePathWithCorrectC(photo.path, type);
      return photo.copyWith(
        photoType: type,
        path: newPath,
      );
    }).toList();

    return [...nonColorPhotos, ...organizedColors];
  }

  String _getColorNameFromPath(String path) {
    // 106603__C1__PRETO.jpg -> PRETO
    final fileName = p.basename(path);
    final parts = fileName.split('__');
    if (parts.length >= 3) {
      final lastPart = parts.last; // PRETO.jpg
      return lastPart.split('.').first;
    }
    return '';
  }

  String _updatePathWithCorrectC(String path, String newType) {
    // 106603__C2__ROSA.jpg -> 106603__C1__ROSA.jpg
    final directory = p.dirname(path);
    final fileName = p.basename(path);
    final parts = fileName.split('__');
    if (parts.length >= 3) {
      parts[1] = newType;
      return p.join(directory, parts.join('__'));
    }
    return path;
  }
}

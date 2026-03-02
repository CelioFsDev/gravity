import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:catalogo_ja/models/catalog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class WhatsAppShareService {
  static Future<void> shareCatalog({
    required String catalogName,
    required String catalogUrl,
    required CatalogMode mode,
  }) async {
    final label = mode == CatalogMode.atacado
        ? '\ud83d\udce6 *ATACADO*'
        : '\ud83c\udff7\ufe0f *VAREJO*';
    final text =
        'Ol\u00e1! \ud83d\udc4b\n\nConfira nosso cat\u00e1logo digital: *${catalogName.toUpperCase()}*\n\n$label\n\ud83d\udcf1 Clique para ver os produtos: $catalogUrl\n\nAguardamos seu pedido! \ud83d\ude42';
    await _launchWhatsApp(text: text);
  }

  static Future<void> shareFile({
    required List<int> bytes,
    required String fileName,
    String? text,
    String? mimeType,
  }) async {
    // Infer mimeType from extension if null
    String? effectiveMimeType = mimeType;
    if (effectiveMimeType == null) {
      final ext = fileName.toLowerCase();
      if (ext.endsWith('.pdf')) {
        effectiveMimeType = 'application/pdf';
      } else if (ext.endsWith('.zip')) {
        effectiveMimeType = 'application/zip';
      } else if (ext.endsWith('.json')) {
        effectiveMimeType = 'application/json';
      }
    }

    if (kIsWeb) {
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: fileName,
          mimeType: effectiveMimeType,
        ),
      ], text: text);
    } else {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, fileName));
      await tempFile.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles([
        XFile(tempFile.path, mimeType: effectiveMimeType),
      ], text: text);
    }
  }

  static Future<void> shareFiles({
    required List<({List<int> bytes, String fileName, String? mimeType})> files,
    String? text,
  }) async {
    final xfiles = <XFile>[];
    for (final file in files) {
      String? effectiveMimeType = file.mimeType;
      if (effectiveMimeType == null) {
        final ext = file.fileName.toLowerCase();
        if (ext.endsWith('.pdf')) {
          effectiveMimeType = 'application/pdf';
        } else if (ext.endsWith('.zip')) {
          effectiveMimeType = 'application/zip';
        } else if (ext.endsWith('.json')) {
          effectiveMimeType = 'application/json';
        }
      }
      if (kIsWeb) {
        xfiles.add(
          XFile.fromData(
            Uint8List.fromList(file.bytes),
            name: file.fileName,
            mimeType: effectiveMimeType,
          ),
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(p.join(tempDir.path, file.fileName));
        await tempFile.writeAsBytes(file.bytes, flush: true);
        xfiles.add(XFile(tempFile.path, mimeType: effectiveMimeType));
      }
    }
    await Share.shareXFiles(xfiles, text: text);
  }

  static Future<void> shareXFile({
    required String filePath,
    required String fileName,
    String? text,
    String? mimeType,
  }) async {
    await Share.shareXFiles([
      XFile(filePath, name: fileName, mimeType: mimeType),
    ], text: text);
  }

  static Future<void> _launchWhatsApp({
    String? phone,
    required String text,
  }) async {
    final cleanPhone = phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final url = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(url);
    }
  }
}

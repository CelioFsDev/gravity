import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'package:gravity/models/catalog.dart';
import 'package:share_plus/share_plus.dart';

class WhatsAppShareService {
  static Future<void> shareCatalog({
    required String catalogName,
    required String catalogUrl,
    required CatalogMode mode,
  }) async {
    final label = mode == CatalogMode.atacado ? '🛍️ *ATACADO*' : '✨ *VAREJO*';
    final text =
        'Olá! 👋\n\nConfira nosso catálogo digital: *${catalogName.toUpperCase()}*\n\n$label\n🔗 Clique para ver os produtos: $catalogUrl\n\nAguardamos seu pedido! 🚀';
    await _launchWhatsApp(text: text);
  }

  static Future<void> shareFile({
    required List<int> bytes,
    required String fileName,
    String? text,
    String? mimeType,
  }) async {
    await Share.shareXFiles([
      XFile.fromData(
        Uint8List.fromList(bytes),
        name: fileName,
        mimeType: mimeType,
      ),
    ], text: text);
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

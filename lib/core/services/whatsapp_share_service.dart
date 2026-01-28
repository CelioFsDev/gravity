import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:gravity/models/catalog.dart';
import 'package:gravity/models/order_item.dart';
import 'package:share_plus/share_plus.dart';

class WhatsAppShareService {
  static Future<void> shareCatalog({
    required String catalogName,
    required String catalogUrl,
    required CatalogMode mode,
  }) async {
    final label = mode.label;
    final text = '$label\nConfira nosso catálogo *$catalogName*:\n$catalogUrl';
    await _launchWhatsApp(text: text);
  }

  static Future<void> shareFile({
    required List<int> bytes,
    required String fileName,
    String? text,
  }) async {
    await Share.shareXFiles([
      XFile.fromData(
        Uint8List.fromList(bytes),
        name: fileName,
        mimeType: 'application/pdf',
      ),
    ], subject: text);
  }

  static Future<void> shareOrder({
    required String storePhone,
    required String catalogName,
    required List<OrderItem> items,
    required double total,
    required String customerName,
  }) async {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final sb = StringBuffer();
    sb.writeln('Olá! Gostaria de fazer um pedido do catálogo *$catalogName*:');
    sb.writeln('');
    for (var item in items) {
      sb.write('${item.quantity}x ${item.productName}');
      if (item.selectedSize != null) sb.write(' (${item.selectedSize})');
      sb.writeln(' - ${currency.format(item.total)}');
    }
    sb.writeln('');
    sb.writeln('*Total: ${currency.format(total)}*');
    sb.writeln('');
    if (customerName.isNotEmpty) sb.writeln('Nome: $customerName');

    await _launchWhatsApp(phone: storePhone, text: sb.toString());
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

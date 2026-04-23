import 'package:catalogo_ja/models/order.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  
  /// Constrói a mensagem estruturada e tenta abrir o WhatsApp (Web ou Mobile)
  static Future<bool> sendOrderToWhatsApp({
    required String merchantPhone,
    required Order order,
    required String storeName,
  }) async {
    final message = _buildOrderMessage(order, storeName);
    return await _launchWhatsApp(merchantPhone, message);
  }

  static String _buildOrderMessage(Order order, String storeName) {
    final buffer = StringBuffer();
    
    buffer.writeln('🛍️ *NOVO PEDIDO - $storeName*');
    buffer.writeln('--------------------------------');
    buffer.writeln('👤 *Cliente:* ${order.customerName}');
    buffer.writeln('📱 *Telefone:* ${order.customerPhone}');
    buffer.writeln('📅 *Data:* ${_formatDate(order.createdAt)}');
    buffer.writeln('--------------------------------');
    buffer.writeln('*ITENS DO PEDIDO:*');
    
    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      buffer.writeln('${i + 1}. *${item.productName}*');
      
      if (item.sku != null && item.sku!.isNotEmpty) {
        buffer.writeln('   SKU: ${item.sku}');
      }
      
      if (item.attributes != null && item.attributes!.isNotEmpty) {
        final attrs = item.attributes!.entries.map((e) => '${e.key}: ${e.value}').join(', ');
        buffer.writeln('   Variação: $attrs');
      }
      
      buffer.writeln('   Qtd: ${item.quantity} un. x R\$ ${item.unitPrice.toStringAsFixed(2)}');
      buffer.writeln('   _Sub: R\$ ${item.totalPrice.toStringAsFixed(2)}_');
      buffer.writeln('');
    }

    buffer.writeln('--------------------------------');
    
    if (order.discount > 0) {
      buffer.writeln('Desconto: - R\$ ${order.discount.toStringAsFixed(2)}');
    }
    if (order.shippingCost > 0) {
      buffer.writeln('Frete: + R\$ ${order.shippingCost.toStringAsFixed(2)}');
    }
    
    buffer.writeln('💰 *TOTAL: R\$ ${order.totalAmount.toStringAsFixed(2)}*');
    buffer.writeln('--------------------------------');
    
    // Em uma versão corporativa maior, aqui vai o link de rastreio/status do pedido.
    
    return buffer.toString();
  }

  static Future<bool> _launchWhatsApp(String phone, String message) async {
    // Formata o telefone (remove caracteres não numéricos)
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    
    // Constrói a URI Universal do WhatsApp
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(uri)) {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      // Tenta fallback pro esquema de App nativo antigo
      final fallbackUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(fallbackUri)) {
        return await launchUrl(fallbackUri);
      }
      return false;
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

import 'dart:io';
import 'package:gravity/core/importer/nuvemshop_csv_reader.dart';
import 'package:gravity/core/importer/nuvemshop_forward_fill.dart';
import 'package:gravity/core/importer/parse_utils.dart';

Future<void> main() async {
  final file = File(r'd:\DOWNLOAD\tiendanube-4597800-17706886192015272610435045385.csv');
  final table = await NuvemshopCsvReader.readFromFile(file);
  print('headers=${table.headers.length}');
  print(table.headers.take(10).toList());

  final rows = forwardFill(table.rows, const [
    'Identificador URL',
    'Nome',
    'Categorias',
    'Preço',
    'Preço promocional',
    'Descrição',
    'Tags',
  ]);

  int ok = 0;
  int noSlug = 0;
  int noSku = 0;
  int badPrice = 0;

  for (final row in rows) {
    final slug = (row['Identificador URL'] ?? '').trim();
    final sku = (row['SKU'] ?? '').trim();
    final price = parseMoney((row['Preço'] ?? '').trim());
    if (slug.isEmpty) noSlug++;
    if (sku.isEmpty) noSku++;
    if (price <= 0) badPrice++;
    if (slug.isNotEmpty && sku.isNotEmpty) ok++;
  }

  print('rows=${rows.length} ok=$ok noSlug=$noSlug noSku=$noSku badPrice=$badPrice');
  print('sample1 slug=${rows.first['Identificador URL']} sku=${rows.first['SKU']} price=${rows.first['Preço']} parsed=${parseMoney(rows.first['Preço'] ?? '')}');
}

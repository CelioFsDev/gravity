import 'dart:io';
import 'package:gravity/core/importer/nuvemshop_csv_reader.dart';
import 'package:gravity/core/importer/nuvemshop_forward_fill.dart';

String norm(String s) {
  var n = s.toLowerCase().trim();
  const rep = {
    'á':'a','à':'a','â':'a','ã':'a','ä':'a',
    'é':'e','è':'e','ê':'e','ë':'e',
    'í':'i','ì':'i','î':'i','ï':'i',
    'ó':'o','ò':'o','ô':'o','õ':'o','ö':'o',
    'ú':'u','ù':'u','û':'u','ü':'u',
    'ç':'c','ñ':'n'
  };
  rep.forEach((k,v){ n = n.replaceAll(k,v); });
  n = n.replaceAll(RegExp(r'\s+'),' ');
  n = n.replaceAll(RegExp(r'[^a-z0-9 ]'),'');
  return n.trim();
}

String value(Map<String,String> row, String key){
  if (row.containsKey(key)) return (row[key] ?? '').trim();
  final nk = norm(key);
  final aliases = <String,List<String>>{
    'identificador url':['identificador url','url','handle','slug'],
    'nome':['nome','titulo','title','name'],
    'sku':['sku','codigo','codigo de barras','ean','referencia','ref'],
  };
  final a = aliases[nk] ?? [nk];
  final nr = <String,String>{ for (final e in row.entries) norm(e.key): e.value.trim() };
  for (final k in a){ if (nr.containsKey(k)) return nr[k] ?? ''; }
  return '';
}

Future<void> main() async {
  final f = File(r'd:\DOWNLOAD\tiendanube-4597800-17706886192015272610435045385.csv');
  final t = await NuvemshopCsvReader.readFromFile(f);
  final rows = forwardFill(t.rows, const ['Identificador URL','Nome','Categorias','Preço','Preço promocional','Descrição','Tags']);
  print('headers=${t.headers.length} rows=${rows.length}');
  print('first_headers=${t.headers.take(8).toList()}');
  int withName=0, withSku=0, withSlug=0;
  for (final r in rows){
    if (value(r,'Nome').isNotEmpty) withName++;
    if (value(r,'SKU').isNotEmpty) withSku++;
    if (value(r,'Identificador URL').isNotEmpty) withSlug++;
  }
  print('withName=$withName withSku=$withSku withSlug=$withSlug');
  if (rows.isNotEmpty){
    final r = rows.first;
    print('sample_name=${value(r,'Nome')}');
    print('sample_sku=${value(r,'SKU')}');
    print('sample_slug=${value(r,'Identificador URL')}');
    print('sample_keys=${r.keys.take(12).toList()}');
  }
}

import 'dart:io';

void main() {
  final dir = Directory('lib');
  int filesChanged = 0;
  int occurrencesReplaced = 0;

  for (final file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = file.readAsStringSync();
      if (content.contains('.valueOrNull')) {
        final newContent = content.replaceAll('.valueOrNull', '.asData?.value');
        file.writeAsStringSync(newContent);
        filesChanged++;
        occurrencesReplaced += '.valueOrNull'.allMatches(content).length;
        print('Modificado: ${file.path}');
      }
    }
  }

  print('Total de arquivos modificados: $filesChanged');
  print('Total de ocorrencias substituidas: $occurrencesReplaced');
}

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:catalogo_ja/data/repositories/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_description_service.g.dart';

@riverpod
class AiDescriptionService extends _$AiDescriptionService {
  @override
  void build() {}

  Future<String?> generateDescription({
    required String productName,
    required String category,
    String? details,
  }) async {
    try {
      final settings = ref.read(settingsRepositoryProvider).getSettings();
      final apiKey = settings.geminiApiKey;

      if (apiKey.isEmpty) {
        throw Exception('API Key do Gemini n\u00e3o configurada nos Ajustes.');
      }

      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

      final prompt =
          '''
      Voc\u00ea \u00e9 um redator especialista em e-commerce e vendas.
      Escreva uma descri\u00e7\u00e3o atraente e profissional para o seguinte produto:
      Nome: $productName
      Categoria: $category
      ${details != null ? 'Detalhes adicionais: $details' : ''}
      
      Regras:
      1. Use um tom convincente e elegante.
      2. Foque nos benef\u00edcios para o cliente.
      3. Use bullet points para caracter\u00edsticas t\u00e9cnicas se necess\u00e1rio.
      4. A descri\u00e7\u00e3o deve ter entre 3 e 6 par\u00e1grafos curtos.
      5. Responda apenas com o texto da descri\u00e7\u00e3o.
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      return response.text;
    } catch (e) {
      print('Error generating AI description: $e');
      rethrow;
    }
  }
}

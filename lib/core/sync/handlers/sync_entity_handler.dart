import 'package:catalogo_ja/core/sync/models/sync_queue_item.dart';

/// Define o contrato para processar a sincronização remota de um tipo específico de entidade.
/// Isso permite que o SyncWorker atue apenas como Orquestrador, delegando a lógica 
/// (como upload de fotos ou validação) para especialistas de domínio.
abstract class SyncEntityHandler {
  /// Retorna o identificador do tipo de entidade (ex: 'product', 'category')
  String get entityType;

  /// Processa a sincronização de um item da fila.
  /// Lança exceção em caso de erro, que será capturada pelo worker para gerenciar o backoff.
  Future<void> processItem(SyncQueueItem item);
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Serviço central de Telemetria e Observabilidade.
/// Abstrai a implementação real (Sentry, Firebase Crashlytics, Datadog)
/// para que o resto do app não fique acoplado a nenhum SDK específico.
class TelemetryService {
  
  /// Registra um erro de Sincronização na Fila (Background)
  void recordSyncError({
    required String entityType,
    required String entityId,
    required String tenantId,
    required dynamic error,
    StackTrace? stackTrace,
  }) {
    _reportToCloud(
      error: error, 
      stackTrace: stackTrace, 
      reason: 'SyncQueue Error [$entityType]',
      extras: {
        'entityId': entityId,
        'tenantId': tenantId,
        'layer': 'OfflineFirst_Worker'
      }
    );
  }

  /// Registra falhas específicas de Upload de Mídia (Bucket Storage)
  void recordUploadFailure({
    required String localPath,
    required String tenantId,
    required dynamic error,
    StackTrace? stackTrace,
  }) {
    _reportToCloud(
      error: error, 
      stackTrace: stackTrace, 
      reason: 'Media Upload Failure',
      extras: {
        'path': localPath,
        'tenantId': tenantId,
        'layer': 'StorageResolver'
      }
    );
  }

  /// Registra falhas críticas no app (Crashes de UI ou Lógica Core)
  void recordFatalError(dynamic error, StackTrace stackTrace) {
    _reportToCloud(
      error: error,
      stackTrace: stackTrace,
      reason: 'Fatal Exception',
      isFatal: true,
    );
  }

  /// Registra um evento de negócio (Funil, Billing, Actions)
  void logEvent(String name, {Map<String, dynamic>? parameters}) {
    if (kDebugMode) {
      debugPrint('📊 [Analytics Event]: $name | Params: $parameters');
    }
    // TODO: Plugar FirebaseAnalytics.instance.logEvent() ou Mixpanel
  }

  // ---- Implementação Interna ----
  
  void _reportToCloud({
    required dynamic error,
    StackTrace? stackTrace,
    required String reason,
    bool isFatal = false,
    Map<String, dynamic>? extras,
  }) {
    if (kDebugMode) {
      debugPrint('🚨 [Telemetry] $reason: $error');
      if (extras != null) debugPrint('   Extras: $extras');
      if (stackTrace != null) debugPrint('   Stack: $stackTrace');
    } else {
      // TODO: Aqui será plugado o FirebaseCrashlytics.instance.recordError
      // FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: reason, fatal: isFatal);
      
      // Se houvesse Sentry:
      // Sentry.captureException(error, stackTrace: stackTrace, hint: reason);
    }
  }
}

final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  return TelemetryService();
});

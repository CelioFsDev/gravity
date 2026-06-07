import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
        'layer': 'OfflineFirst_Worker',
      },
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
        'layer': 'StorageResolver',
      },
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
      return;
    }

    final analyticsParameters = <String, Object>{
      for (final entry in (parameters ?? const <String, dynamic>{}).entries)
        entry.key:
            entry.value is num || entry.value is String || entry.value is bool
            ? entry.value as Object
            : entry.value.toString(),
    };

    unawaited(
      FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: analyticsParameters,
      ),
    );
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
      return;
    }

    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: isFatal,
      ),
    );

    if (extras != null && extras.isNotEmpty) {
      unawaited(
        FirebaseCrashlytics.instance.setCustomKey('telemetry_reason', reason),
      );
      for (final entry in extras.entries) {
        unawaited(
          FirebaseCrashlytics.instance.setCustomKey(
            'telemetry_${entry.key}',
            entry.value.toString(),
          ),
        );
      }
    }
  }
}

final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  return TelemetryService();
});

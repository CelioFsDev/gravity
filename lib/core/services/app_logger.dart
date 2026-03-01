import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_logger.g.dart';

enum AppEvent {
  pdfGenerated('pdf_generated'),
  catalogShared('catalog_shared'),
  orderSubmitted('order_submitted'),
  importCompleted('import_completed'),
  productCreated('product_created'),
  productUpdated('product_updated'),
  productDeleted('product_deleted');

  final String name;
  const AppEvent(this.name);
}

@riverpod
class AppLogger extends _$AppLogger {
  @override
  void build() {}

  void log(AppEvent event, {Map<String, dynamic>? parameters}) {
    final eventName = event.name;
    final params = parameters != null ? ' params: $parameters' : '';

    if (kDebugMode) {
      debugPrint('🚀 [AppLogger] Event: $eventName $params');
    }

    // Future: Plug Crashlytics/Analytics here
    // FirebaseAnalytics.instance.logEvent(name: eventName, parameters: parameters);
  }

  void logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('❌ [AppLogger] Error: $message');
      if (error != null) debugPrint('   Error detail: $error');
      if (stackTrace != null) debugPrint('   StackTrace: $stackTrace');
    }

    // Future: Crashlytics
    // FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
  }
}

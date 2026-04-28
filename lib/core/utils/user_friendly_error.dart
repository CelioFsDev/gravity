import 'package:cloud_firestore/cloud_firestore.dart';

class UserFriendlyError {
  static const cloudSyncFallback =
      'N\u00e3o foi poss\u00edvel sincronizar com a nuvem. Seus dados foram salvos no aparelho e ser\u00e3o enviados depois.';

  static String message(
    Object error, {
    String fallback = 'N\u00e3o foi poss\u00edvel concluir a opera\u00e7\u00e3o agora. Tente novamente em alguns instantes.',
  }) {
    if (error is FirebaseException) {
      return _firebaseMessage(error, fallback);
    }

    final raw = error.toString().toLowerCase();

    if (raw.contains('cloud_firestore') ||
        raw.contains('permission-denied') ||
        raw.contains('permission denied') ||
        raw.contains('firebaseexception')) {
      return cloudSyncFallback;
    }

    if (raw.contains('network') ||
        raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('timeout')) {
      return 'Sem conex\u00e3o est\u00e1vel no momento. Verifique a internet e tente novamente.';
    }

    if (raw.contains('file_picker') ||
        raw.contains('permission') ||
        raw.contains('access is denied')) {
      return 'N\u00e3o foi poss\u00edvel acessar o arquivo selecionado. Verifique a permiss\u00e3o e tente novamente.';
    }

    if (raw.contains('share') || raw.contains('activity')) {
      return 'O arquivo foi gerado, mas n\u00e3o foi poss\u00edvel abrir o compartilhamento neste aparelho.';
    }

    return fallback;
  }

  static String _firebaseMessage(
    FirebaseException error,
    String fallback,
  ) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return cloudSyncFallback;
      case 'unavailable':
      case 'deadline-exceeded':
        return 'A nuvem est\u00e1 indispon\u00edvel no momento. Seus dados locais continuam salvos.';
      case 'not-found':
        return 'N\u00e3o encontramos os dados solicitados. Atualize a tela e tente novamente.';
      default:
        return fallback;
    }
  }
}

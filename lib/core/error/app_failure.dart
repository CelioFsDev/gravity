import 'package:firebase_core/firebase_core.dart';

class AppFailure {
  final String code;
  final String message;
  final String? details;
  final Object? originalError;

  AppFailure({
    required this.code,
    required this.message,
    this.details,
    this.originalError,
  });

  @override
  String toString() => message;

  factory AppFailure.fromError(Object error, {String? action, String? entity}) {
    // Basic mapping for common errors
    if (error is AppFailure) return error;

    if (error is FirebaseException) {
      return AppFailure(
        code: error.code,
        message: _messageForFirebaseError(error),
        details:
            'Ação: $action | Entidade: $entity | Erro original: ${error.message ?? error}',
        originalError: error,
      );
    }

    final detailsStr = 'Ação: $action | Entidade: $entity | Erro original: $error';
    
    // Log the unknown error for debugging
    print('❌ AppFailure (UNKNOWN_ERROR): $detailsStr');

    return AppFailure(
      code: 'UNKNOWN_ERROR',
      message: 'Ocorreu um erro inesperado: $error',
      details: detailsStr,
      originalError: error,
    );
  }

  static String _messageForFirebaseError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Não foi possível acessar os dados públicos desta vitrine.';
      case 'unavailable':
        return 'Serviço temporariamente indisponível. Tente novamente em instantes.';
      case 'not-found':
      case 'object-not-found':
        return 'Vitrine não encontrada.';
      case 'failed-precondition':
        return 'A vitrine precisa ser publicada novamente.';
      default:
        return error.message ?? 'Ocorreu um erro ao carregar os dados.';
    }
  }
}

sealed class Result<T> {
  const Result();

  factory Result.success(T data) = Success<T>;
  factory Result.failure(AppFailure failure) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => this is Success<T> ? (this as Success<T>).data : null;
  AppFailure? get failureOrNull =>
      this is Failure<T> ? (this as Failure<T>).failure : null;
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final AppFailure failure;
  const Failure(this.failure);
}

extension AppFailureExtension on Object {
  AppFailure toAppFailure({String? action, String? entity}) {
    return AppFailure.fromError(this, action: action, entity: entity);
  }
}

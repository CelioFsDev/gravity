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
  String toString() =>
      'AppFailure(code: $code, message: $message, details: $details)';

  factory AppFailure.fromError(Object error, {String? action, String? entity}) {
    // Basic mapping for common errors
    if (error is AppFailure) return error;

    return AppFailure(
      code: 'UNKNOWN_ERROR',
      message: 'Ocorreu um erro inesperado.',
      details: 'Ação: $action | Entidade: $entity | Erro original: $error',
      originalError: error,
    );
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

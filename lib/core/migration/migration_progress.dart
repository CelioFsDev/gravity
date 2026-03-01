class MigrationProgress {
  final String stage; // ex: 'init', 'products', 'done'
  final int completed; // quantos itens processados
  final int total; // total de itens
  final String message; // mensagem exibida na UI

  const MigrationProgress({
    required this.stage,
    required this.completed,
    required this.total,
    required this.message,
  });

  MigrationProgress copyWith({
    String? stage,
    int? completed,
    int? total,
    String? message,
  }) {
    return MigrationProgress(
      stage: stage ?? this.stage,
      completed: completed ?? this.completed,
      total: total ?? this.total,
      message: message ?? this.message,
    );
  }
}

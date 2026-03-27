import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'global_loading_provider.g.dart';

class BackgroundTask {
  final String id;
  final String title;
  final String message;
  final double progress;
  final bool isDone;
  final String? error;

  BackgroundTask({
    required this.id,
    required this.title,
    required this.message,
    this.progress = 0,
    this.isDone = false,
    this.error,
  });

  BackgroundTask copyWith({
    String? title,
    String? message,
    double? progress,
    bool? isDone,
    String? error,
  }) {
    return BackgroundTask(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      isDone: isDone ?? this.isDone,
      error: error ?? this.error,
    );
  }
}

@Riverpod(keepAlive: true)
class GlobalLoading extends _$GlobalLoading {
  @override
  Map<String, BackgroundTask> build() {
    return {};
  }

  void addTask(BackgroundTask task) {
    state = {...state, task.id: task};
  }

  void updateTask(String id, {String? message, double? progress, bool? isDone, String? error}) {
    final task = state[id];
    if (task == null) return;

    state = {
      ...state,
      id: task.copyWith(
        message: message,
        progress: progress,
        isDone: isDone,
        error: error,
      ),
    };
  }

  void removeTask(String id) {
    if (!state.containsKey(id)) return;
    final newState = Map<String, BackgroundTask>.from(state);
    newState.remove(id);
    state = newState;
  }

  bool hasActiveTasks() => state.values.any((t) => !t.isDone);
  
  BackgroundTask? mainActiveTask() {
    final active = state.values.where((t) => !t.isDone).toList();
    return active.isEmpty ? null : active.first;
  }
}

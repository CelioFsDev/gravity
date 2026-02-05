import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:gravity/core/services/dto/gravity_export_dtos.dart';
import 'package:gravity/core/services/export_import_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gravity_import_viewmodel.g.dart';

class GravityImportState {
  final int step; // 0: Pick File, 1: Preview/Mode, 2: Result
  final bool isLoading;
  final String? errorMessage;
  final GravityExportPayload? payload;
  final ImportPreview? preview;
  final ImportMode selectedMode;
  final ImportResult? result;

  GravityImportState({
    this.step = 0,
    this.isLoading = false,
    this.errorMessage,
    this.payload,
    this.preview,
    this.selectedMode = ImportMode.merge,
    this.result,
  });

  GravityImportState copyWith({
    int? step,
    bool? isLoading,
    String? errorMessage,
    GravityExportPayload? payload,
    ImportPreview? preview,
    ImportMode? selectedMode,
    ImportResult? result,
  }) {
    return GravityImportState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      payload: payload ?? this.payload,
      preview: preview ?? this.preview,
      selectedMode: selectedMode ?? this.selectedMode,
      result: result ?? this.result,
    );
  }
}

@riverpod
class GravityImportViewModel extends _$GravityImportViewModel {
  @override
  GravityImportState build() {
    return GravityImportState();
  }

  void setMode(ImportMode mode) {
    state = state.copyWith(selectedMode: mode);
  }

  Future<void> pickFile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final service = ref.read(exportImportServiceProvider);

        final payload = await service.parsePayload(file);
        final preview = await service.previewImport(payload);

        state = state.copyWith(
          payload: payload,
          preview: preview,
          step: 1, // Move to Preview
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao ler arquivo: $e',
      );
    }
  }

  Future<void> executeImport() async {
    if (state.payload == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final service = ref.read(exportImportServiceProvider);
      final result = await service.executeImport(
        state.payload!,
        state.selectedMode,
      );

      state = state.copyWith(
        result: result,
        step: 2, // Move to Result
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao importar: $e',
      );
    }
  }

  void reset() {
    state = GravityImportState();
  }
}

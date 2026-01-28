import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DataBackend { hive, firestore, hybrid }

final dataBackendProvider = StateProvider<DataBackend>(
  (ref) => DataBackend.hive,
);

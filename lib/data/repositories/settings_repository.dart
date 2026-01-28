import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gravity/core/config/data_backend.dart';
import 'package:gravity/data/repositories/contracts/settings_repository_contract.dart';
import 'package:gravity/models/app_settings.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_repository.g.dart';

const _settingsKey = 'current_settings';
const _settingsDocId = 'current_settings';

Stream<AppSettings> _settingsStream(Box<AppSettings> box) {
  return Stream<AppSettings>.multi((controller) {
    controller.add(box.get(_settingsKey) ?? AppSettings());
    final subscription = box.watch(key: _settingsKey).listen((_) {
      controller.add(box.get(_settingsKey) ?? AppSettings());
    });
    controller.onCancel = subscription.cancel;
  });
}

class HiveSettingsRepository implements SettingsRepositoryContract {
  final Box<AppSettings> _box;

  HiveSettingsRepository(this._box);

  Box<AppSettings> get box => _box;

  @override
  Future<AppSettings> getSettings() async {
    return _box.get(_settingsKey) ?? AppSettings();
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _box.put(_settingsKey, settings);
  }

  @override
  Stream<AppSettings> watchSettings() => _settingsStream(_box);
}

class SettingsFirestoreRepository implements SettingsRepositoryContract {
  final FirebaseFirestore _firestore;
  final DocumentReference<Map<String, dynamic>> _doc;

  SettingsFirestoreRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _doc = (firestore ?? FirebaseFirestore.instance)
            .collection('settings')
            .doc(_settingsDocId);

  @override
  Future<AppSettings> getSettings() async {
    final snapshot = await _doc.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return AppSettings();
    }
    return AppSettings.fromFirestore(snapshot.data()!);
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _doc.set(settings.toFirestoreMap());
  }

  @override
  Stream<AppSettings> watchSettings() {
    return _doc.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return AppSettings();
      }
      return AppSettings.fromFirestore(snapshot.data()!);
    });
  }
}

class HybridSettingsRepository implements SettingsRepositoryContract {
  final HiveSettingsRepository _hive;
  final SettingsFirestoreRepository _firestore;
  late final StreamSubscription<AppSettings> _subscription;

  HybridSettingsRepository({
    required SettingsFirestoreRepository firestore,
    required HiveSettingsRepository hive,
  })  : _firestore = firestore,
        _hive = hive {
    _subscription = _firestore.watchSettings().listen(_handleRemote);
  }

  void _handleRemote(AppSettings remote) {
    _syncRemote(remote);
  }

  Future<void> _syncRemote(AppSettings remote) async {
    if (!_hive.box.isOpen) return;
    await _hive.saveSettings(remote);
  }

  void dispose() {
    _subscription.cancel();
  }

  @override
  Future<AppSettings> getSettings() => _hive.getSettings();

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _firestore.saveSettings(settings);
    await _hive.saveSettings(settings);
  }

  @override
  Stream<AppSettings> watchSettings() => _hive.watchSettings();
}

@Riverpod(keepAlive: true)
SettingsRepositoryContract settingsRepository(SettingsRepositoryRef ref) {
  final backend = ref.watch(dataBackendProvider);
  final settingsBox = Hive.box<AppSettings>('settings');

  final hiveRepo = HiveSettingsRepository(settingsBox);
  final firestoreRepo = SettingsFirestoreRepository();

  switch (backend) {
    case DataBackend.hive:
      return hiveRepo;
    case DataBackend.firestore:
      return firestoreRepo;
    case DataBackend.hybrid:
      final hybrid = HybridSettingsRepository(
        firestore: firestoreRepo,
        hive: hiveRepo,
      );
      ref.onDispose(hybrid.dispose);
      return hybrid;
  }
}

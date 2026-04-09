import 'package:hive/hive.dart';

part 'sync_status.g.dart';

@HiveType(typeId: 30)
enum SyncStatus {
  @HiveField(0)
  synced,
  @HiveField(1)
  pendingUpdate,
  @HiveField(2)
  conflict,
}

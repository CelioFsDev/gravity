import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserSyncResult {
  const UserSyncResult({
    required this.created,
    required this.processed,
    required this.skipped,
    required this.updated,
  });

  factory UserSyncResult.fromMap(Map<Object?, Object?> map) {
    int readInt(String key) => (map[key] as num?)?.toInt() ?? 0;

    return UserSyncResult(
      created: readInt('created'),
      processed: readInt('processed'),
      skipped: readInt('skipped'),
      updated: readInt('updated'),
    );
  }

  final int created;
  final int processed;
  final int skipped;
  final int updated;
}

class UserSyncRepository {
  UserSyncRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<UserSyncResult> syncAuthUsers() async {
    final callable = _functions.httpsCallable('syncAuthUsers');
    final response = await callable.call<Map<String, dynamic>>();
    return UserSyncResult.fromMap(response.data.cast<Object?, Object?>());
  }
}

final userSyncRepositoryProvider = Provider<UserSyncRepository>((ref) {
  return UserSyncRepository();
});

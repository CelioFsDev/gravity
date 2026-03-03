import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreatedUserAccount {
  const CreatedUserAccount({
    required this.email,
    required this.role,
    required this.uid,
  });

  factory CreatedUserAccount.fromMap(Map<Object?, Object?> map) {
    return CreatedUserAccount(
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'viewer',
      uid: map['uid'] as String? ?? '',
    );
  }

  final String email;
  final String role;
  final String uid;
}

class AdminUserAccountRepository {
  AdminUserAccountRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<CreatedUserAccount> createEmailPasswordUser({
    required String email,
    required String password,
    required String role,
  }) async {
    final callable = _functions.httpsCallable('createEmailPasswordUser');
    final response = await callable.call<Map<String, dynamic>>({
      'email': email,
      'password': password,
      'role': role,
    });

    return CreatedUserAccount.fromMap(response.data.cast<Object?, Object?>());
  }
}

final adminUserAccountRepositoryProvider = Provider<AdminUserAccountRepository>(
  (ref) {
    return AdminUserAccountRepository();
  },
);

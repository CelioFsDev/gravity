import 'package:cloud_firestore/cloud_firestore.dart';

class AuthUser {
  final String uid;
  final String email;
  final String role;

  final DateTime? createdAt;

  const AuthUser({
    required this.uid,
    required this.email,
    this.role = 'user',
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  AuthUser copyWith({
    String? uid,
    String? email,
    String? role,
    DateTime? createdAt,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AuthUser.fromMap(String uid, Map<String, dynamic>? data) {
    return AuthUser(
      uid: uid,
      email: data?['email'] as String? ?? '',
      role: data?['role'] as String? ?? 'user',
      createdAt: data?['createdAt'] is Timestamp
          ? (data?['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {'email': email, 'role': role};
  }
}

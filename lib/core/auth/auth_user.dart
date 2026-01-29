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
    if (data == null) {
      return AuthUser(uid: uid, email: '', createdAt: DateTime.now());
    }

    DateTime? createdAtDate;
    if (data['createdAt'] is int) {
      createdAtDate = DateTime.fromMillisecondsSinceEpoch(
        data['createdAt'] as int,
      );
    } else if (data['createdAt'] is String) {
      createdAtDate = DateTime.tryParse(data['createdAt'] as String);
    }

    return AuthUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'user',
      createdAt: createdAtDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

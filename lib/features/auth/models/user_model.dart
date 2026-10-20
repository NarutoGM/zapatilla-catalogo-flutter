enum UserRole { client, admin }

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final UserRole role;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.role,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    final roleString = map['role'] as String? ?? 'client';
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      role: roleString.toLowerCase() == 'admin' ? UserRole.admin : UserRole.client,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role == UserRole.admin ? 'admin' : 'client',
    };
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isClient => role == UserRole.client;
}

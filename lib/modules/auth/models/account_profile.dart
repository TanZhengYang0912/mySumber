class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String status;

  bool get isActive => status == 'active';

  factory AccountProfile.fromMap(Map<String, dynamic> map) => AccountProfile(
        id: map['id'] as String,
        fullName: (map['full_name'] as String?) ?? '',
        email: map['email'] as String,
        role: map['role'] as String,
        status: (map['status'] as String?) ?? 'active',
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'role': role,
        'status': status,
      };
}

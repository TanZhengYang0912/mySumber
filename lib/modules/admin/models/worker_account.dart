class WorkerAccount {
  const WorkerAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.status,
  });

  final String id;
  final String fullName;
  final String email;
  final String status;

  bool get isActive => status == 'active';

  factory WorkerAccount.fromMap(Map<String, dynamic> map) => WorkerAccount(
        id: map['id'] as String,
        fullName: (map['full_name'] as String?) ?? '',
        email: map['email'] as String,
        status: (map['status'] as String?) ?? 'active',
      );
}

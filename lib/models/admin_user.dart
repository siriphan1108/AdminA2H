/// ประเภทผู้ใช้
const kUserRoles = ['ผู้ใช้ทั่วไป', 'ผู้ดูแลระบบ'];

/// สถานะบัญชี
const kUserStatuses = ['ใช้งาน', 'ระงับใช้งาน'];

/// ผู้ใช้งานในระบบ (ฝั่งแอดมิน)
class AdminUser {
  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'ผู้ใช้ทั่วไป',
    this.status = 'ใช้งาน',
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String status;
  final DateTime createdAt;

  bool get isAdmin => role == 'ผู้ดูแลระบบ';
  bool get isActive => status == 'ใช้งาน';

  AdminUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    String? status,
  }) => AdminUser(
    id: id,
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    status: status ?? this.status,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    email: j['email'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    role: j['role'] as String? ?? 'ผู้ใช้ทั่วไป',
    status: j['status'] as String? ?? 'ใช้งาน',
    createdAt:
        DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

import 'package:admin_a2h/services/admin_auth.dart';

/// ระบบหลังบ้านปลอมสำหรับเทสต์ — ทำตัวเหมือน Supabase + ไฟล์ SQL ของเรา
class FakeAuthBackend implements AuthBackend {
  final users = <String, ({String email, String password})>{};
  final profiles = <String, AdminProfile>{};
  String? _session;
  final resetEmails = <String>[];

  void addUser(String id, String email, String password, {String role = kRoleUser, String name = ''}) {
    users[id] = (email: email, password: password);
    profiles[id] = AdminProfile(id: id, email: email, name: name, phone: '', role: role);
  }

  @override
  String? get sessionUserId => _session;

  @override
  Future<String> signIn(String email, String password) async {
    for (final e in users.entries) {
      if (e.value.email.toLowerCase() == email.toLowerCase() &&
          e.value.password == password) {
        _session = e.key;
        return e.key;
      }
    }
    throw const AuthException('อีเมลหรือรหัสผ่านไม่ถูกต้อง');
  }

  @override
  Future<void> signOut() async => _session = null;

  @override
  Future<void> updatePassword(String newPassword) async {
    final u = users[_session]!;
    users[_session!] = (email: u.email, password: newPassword);
  }

  @override
  Future<void> sendPasswordReset(String email) async => resetEmails.add(email);

  @override
  Future<AdminProfile?> fetchProfile(String id) async => profiles[id];

  @override
  Future<void> updateProfile(String id, {required String name, required String phone}) async {
    final p = profiles[id]!;
    profiles[id] = AdminProfile(id: id, email: p.email, name: name, phone: phone, role: p.role);
  }

  @override
  Future<List<AdminProfile>> listAdmins() async =>
      profiles.values.where((p) => p.isAdmin).toList();

  /// เลียนแบบฟังก์ชัน set_admin_role ใน SQL
  @override
  Future<void> setRoleByEmail(String email, String role) async {
    if (profiles[_session]?.isOwner != true) {
      throw const AuthException('เฉพาะผู้ดูแลหลักเท่านั้นที่ทำรายการนี้ได้');
    }
    final target = profiles.values
        .where((p) => p.email.toLowerCase() == email.toLowerCase())
        .firstOrNull;
    if (target == null) {
      throw const AuthException('ไม่พบบัญชีอีเมลนี้ — ให้คนนั้นสมัครสมาชิกก่อน');
    }
    if (target.id == _session) {
      throw const AuthException('เปลี่ยนสิทธิ์ของตัวเองไม่ได้');
    }
    if (target.isOwner && role != kRoleOwner &&
        profiles.values.where((p) => p.isOwner).length <= 1) {
      throw const AuthException('ต้องมีผู้ดูแลหลักอย่างน้อย 1 คน');
    }
    profiles[target.id] = AdminProfile(
      id: target.id, email: target.email, name: target.name, phone: target.phone, role: role,
    );
  }
}

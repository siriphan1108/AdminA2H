import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'admin_auth.dart';

/// โปรเจกต์ Supabase ของ HomeConnect
/// (publishable key เป็นคีย์สาธารณะ ใส่ในเว็บได้ — สิทธิ์จริงคุมด้วย RLS)
/// ห้ามใส่ service_role / secret key ในโค้ดเว็บเด็ดขาด
const kSupabaseUrl = 'https://wzhvyovdsjwnhrgqpxzy.supabase.co';
const kSupabasePublishableKey =
    'sb_publishable_F3-EP4b6ZpcZkth2wLG2Mg_--YlHgZO';

Future<void> initSupabase() => sb.Supabase.initialize(
  url: kSupabaseUrl,
  publishableKey: kSupabasePublishableKey,
);

class SupabaseAuthBackend implements AuthBackend {
  sb.SupabaseClient get _c => sb.Supabase.instance.client;

  @override
  String? get sessionUserId => _c.auth.currentUser?.id;

  @override
  Future<String> signIn(String email, String password) async {
    try {
      final res = await _c.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final id = res.user?.id;
      if (id == null) throw const AuthException('เข้าสู่ระบบไม่สำเร็จ');
      return id;
    } on sb.AuthException catch (e) {
      throw AuthException(_authMessage(e));
    }
  }

  static String _authMessage(sb.AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    }
    if (m.contains('email not confirmed')) {
      return 'บัญชีนี้ยังไม่ได้ยืนยันอีเมล';
    }
    if (m.contains('rate limit') || e.statusCode == '429') {
      return 'ลองเข้าสู่ระบบบ่อยเกินไป กรุณารอสักครู่';
    }
    return 'เข้าสู่ระบบไม่สำเร็จ: ${e.message}';
  }

  @override
  Future<void> signOut() => _c.auth.signOut();

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _c.auth.updateUser(sb.UserAttributes(password: newPassword));
    } on sb.AuthException catch (e) {
      throw AuthException('เปลี่ยนรหัสผ่านไม่สำเร็จ: ${e.message}');
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _c.auth.resetPasswordForEmail(email);
    } on sb.AuthException catch (e) {
      throw AuthException('ส่งอีเมลไม่สำเร็จ: ${e.message}');
    }
  }

  static const _cols = 'id, email, full_name, phone, role';

  @override
  Future<AdminProfile?> fetchProfile(String id) async {
    final row = await _c.from('profiles').select(_cols).eq('id', id).maybeSingle();
    return row == null ? null : AdminProfile.fromRow(row);
  }

  @override
  Future<void> updateProfile(
    String id, {
    required String name,
    required String phone,
  }) async {
    try {
      await _c
          .from('profiles')
          .update({'full_name': name, 'phone': phone})
          .eq('id', id);
    } on sb.PostgrestException catch (e) {
      throw AuthException('บันทึกไม่สำเร็จ: ${e.message}');
    }
  }

  @override
  Future<List<AdminProfile>> listAdmins() async {
    final rows = await _c
        .from('profiles')
        .select(_cols)
        .inFilter('role', kAdminRoles)
        .order('created_at');
    return [for (final r in rows) AdminProfile.fromRow(r)];
  }

  @override
  Future<void> setRoleByEmail(String email, String role) async {
    try {
      await _c.rpc(
        'set_admin_role',
        params: {'p_email': email, 'p_role': role},
      );
    } on sb.PostgrestException catch (e) {
      // ข้อความภาษาไทยมาจากฟังก์ชันในฐานข้อมูล (supabase/001_admin_panel.sql)
      if (e.code == 'PGRST202') {
        throw const AuthException(
          'ยังไม่ได้รันไฟล์ SQL ตั้งค่าแอดมินใน Supabase',
        );
      }
      throw AuthException(e.message);
    }
  }
}

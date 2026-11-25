import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_store.dart';

/// ค่า role ในตาราง profiles ของ Supabase
const kRoleOwner = 'owner'; // ผู้ดูแลหลัก: เพิ่ม/ถอด/เปลี่ยนสิทธิ์แอดมินได้
const kRoleAdmin = 'admin';
const kRoleUser = 'user'; // ลูกค้าในแอป — เข้าเว็บแอดมินไม่ได้
const kAdminRoles = [kRoleOwner, kRoleAdmin];

String roleLabel(String role) => switch (role) {
  kRoleOwner => 'ผู้ดูแลหลัก',
  kRoleAdmin => 'แอดมิน',
  _ => 'ผู้ใช้ทั่วไป',
};

/// โปรไฟล์ผู้ดูแลระบบ (แถวในตาราง profiles)
class AdminProfile {
  const AdminProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
  });

  final String id;
  final String email;
  final String name;
  final String phone;
  final String role;

  bool get isOwner => role == kRoleOwner;
  bool get isAdmin => role == kRoleOwner || role == kRoleAdmin;

  /// ชื่อที่แสดง (ถ้ายังไม่ได้ตั้งชื่อ ใช้ส่วนหน้าของอีเมล)
  String get displayName =>
      name.trim().isNotEmpty ? name.trim() : email.split('@').first;

  factory AdminProfile.fromRow(Map<String, dynamic> r) => AdminProfile(
    id: r['id'] as String,
    email: r['email'] as String? ?? '',
    name: r['full_name'] as String? ?? '',
    phone: r['phone'] as String? ?? '',
    role: r['role'] as String? ?? kRoleUser,
  );
}

/// เกิดเมื่อทำรายการไม่ได้ — [message] เป็นภาษาไทยสำหรับแสดงผู้ใช้
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// ตัวเชื่อมระบบหลังบ้าน (ของจริง = Supabase, ตอนเทสต์ = ตัวปลอม)
abstract class AuthBackend {
  /// id ผู้ใช้ของ session ที่ค้างอยู่ (null = ยังไม่ได้เข้าสู่ระบบ)
  String? get sessionUserId;

  /// เข้าสู่ระบบ คืน id ผู้ใช้ — รหัสผิดให้ throw [AuthException]
  Future<String> signIn(String email, String password);
  Future<void> signOut();
  Future<void> updatePassword(String newPassword);
  Future<void> sendPasswordReset(String email);

  Future<AdminProfile?> fetchProfile(String id);
  Future<void> updateProfile(String id, {required String name, required String phone});
  Future<List<AdminProfile>> listAdmins();

  /// เปลี่ยนสิทธิ์ด้วยอีเมล (ฝั่งเซิร์ฟเวอร์ตรวจว่าเป็นผู้ดูแลหลัก)
  Future<void> setRoleByEmail(String email, String role);
}

/// ระบบบัญชีผู้ดูแลระบบ — ใช้ Supabase Auth + ตาราง profiles (role)
///
/// - เข้าได้เฉพาะ role = admin / owner (ลูกค้าในแอปเข้าไม่ได้)
/// - ล็อกการเข้าสู่ระบบชั่วคราวเมื่อใส่รหัสผิดเกินที่ตั้งไว้ (ฝั่งเบราว์เซอร์)
///   ส่วน Supabase เองก็จำกัดจำนวนครั้งที่ฝั่งเซิร์ฟเวอร์อีกชั้น
class AdminAuth extends ChangeNotifier {
  AdminAuth._();
  static final AdminAuth instance = AdminAuth._();

  static const _rememberKey = 'admin_a2h_remember_v2';
  static const _lockKey = 'admin_a2h_login_lock_v1';
  static const lockDuration = Duration(minutes: 5);

  AuthBackend? _backend;
  AdminProfile? _current;
  List<AdminProfile> _admins = [];
  int _failed = 0;
  DateTime? _lockedUntil;
  Future<void>? _loading;

  /// เรียกครั้งเดียวตอนเปิดแอป (main.dart) หรือในเทสต์
  void useBackend(AuthBackend backend) {
    _backend = backend;
    _loading = null;
  }

  AuthBackend get _b {
    final b = _backend;
    if (b == null) throw const AuthException('ยังไม่ได้เชื่อมต่อระบบหลังบ้าน');
    return b;
  }

  AdminProfile? get current => _current;
  String? get name => _current?.displayName;

  /// รายชื่อผู้ดูแลระบบล่าสุดที่โหลดมา (เรียก [refreshAdmins] เพื่ออัปเดต)
  List<AdminProfile> get admins => List.unmodifiable(_admins);

  DateTime? get lockedUntil =>
      _lockedUntil != null && _lockedUntil!.isAfter(DateTime.now())
      ? _lockedUntil
      : null;

  @visibleForTesting
  void debugReset() {
    _backend = null;
    _current = null;
    _admins = [];
    _failed = 0;
    _lockedUntil = null;
    _loading = null;
  }

  /// โหลดตอนเปิดเว็บ: ถ้ามี session ค้างและติ๊ก "จดจำ" ไว้ ให้อยู่ในระบบต่อ
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final lock = prefs.getString(_lockKey);
    if (lock != null) {
      try {
        final j = jsonDecode(lock) as Map<String, dynamic>;
        _failed = j['failed'] as int? ?? 0;
        _lockedUntil = DateTime.tryParse(j['until'] as String? ?? '');
      } catch (_) {}
    }
    final b = _backend;
    if (b == null) return;
    final id = b.sessionUserId;
    if (id == null) return;
    if (prefs.getBool(_rememberKey) != true) {
      await b.signOut(); // ไม่ได้ติ๊กจดจำ → เปิดเว็บใหม่ต้องล็อกอินใหม่
      return;
    }
    try {
      final p = await b.fetchProfile(id);
      if (p != null && p.isAdmin) {
        _current = p;
      } else {
        await b.signOut();
      }
    } catch (e) {
      debugPrint('ตรวจ session ไม่สำเร็จ: $e');
    }
    notifyListeners();
  }

  Future<void> _saveLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lockKey,
      jsonEncode({'failed': _failed, 'until': _lockedUntil?.toIso8601String()}),
    );
  }

  Future<AuthException> _failure(String message) async {
    await SettingsStore.instance.load();
    final max = SettingsStore.instance.number('max_login_attempts');
    _failed++;
    if (_failed >= max) {
      _failed = 0;
      _lockedUntil = DateTime.now().add(lockDuration);
      await _saveLock();
      return AuthException(
        'ใส่รหัสผ่านผิดครบ $max ครั้ง ระบบล็อกการเข้าสู่ระบบไว้ 5 นาที',
      );
    }
    await _saveLock();
    return AuthException('$message (เหลืออีก ${max - _failed} ครั้ง)');
  }

  /// เข้าสู่ระบบด้วยอีเมลและรหัสผ่าน — ต้องเป็นแอดมินเท่านั้น
  Future<void> login(
    String email,
    String password, {
    bool remember = false,
  }) async {
    final until = lockedUntil;
    if (until != null) {
      final mins = until.difference(DateTime.now()).inMinutes + 1;
      throw AuthException(
        'ใส่รหัสผ่านผิดหลายครั้ง กรุณาลองใหม่ในอีก $mins นาที',
      );
    }
    final String id;
    try {
      id = await _b.signIn(email.trim(), password);
    } on AuthException catch (e) {
      throw await _failure(e.message);
    }
    final p = await _b.fetchProfile(id);
    if (p == null || !p.isAdmin) {
      await _b.signOut();
      throw const AuthException(
        'บัญชีนี้ไม่มีสิทธิ์ผู้ดูแลระบบ กรุณาติดต่อผู้ดูแลหลัก',
      );
    }
    _failed = 0;
    _lockedUntil = null;
    await _saveLock();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, remember);
    _current = p;
    notifyListeners();
  }

  Future<void> logout() async {
    _current = null;
    _admins = [];
    notifyListeners();
    try {
      await _backend?.signOut();
    } catch (e) {
      debugPrint('ออกจากระบบไม่สำเร็จ: $e');
    }
  }

  Future<void> updateProfile({required String name, required String phone}) async {
    final me = _requireMe();
    await _b.updateProfile(me.id, name: name.trim(), phone: phone.trim());
    _current = await _b.fetchProfile(me.id) ?? me;
    notifyListeners();
  }

  /// เปลี่ยนรหัสผ่าน — ตรวจรหัสเดิมก่อน (ลองเข้าสู่ระบบด้วยรหัสเดิม)
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final me = _requireMe();
    try {
      await _b.signIn(me.email, currentPassword);
    } on AuthException {
      throw const AuthException('รหัสผ่านปัจจุบันไม่ถูกต้อง');
    }
    await _b.updatePassword(newPassword);
  }

  /// ส่งอีเมลให้ตั้งรหัสผ่านใหม่ (ใช้ตอนแอดมินลืมรหัส)
  Future<void> sendPasswordReset(String email) => _b.sendPasswordReset(email);

  AdminProfile _requireMe() {
    final me = _current;
    if (me == null) throw const AuthException('กรุณาเข้าสู่ระบบ');
    return me;
  }

  /// โหลดรายชื่อผู้ดูแลใหม่ และอัปเดตสิทธิ์ของตัวเองด้วย
  /// (เช่น เพิ่งถูกตั้งเป็นผู้ดูแลหลักใน Supabase ไม่ต้องออกแล้วเข้าใหม่)
  Future<void> refreshAdmins() async {
    final me = _current;
    if (me != null) {
      final fresh = await _b.fetchProfile(me.id);
      if (fresh == null || !fresh.isAdmin) {
        // ถูกถอดสิทธิ์ระหว่างใช้งาน
        await logout();
        throw const AuthException('บัญชีนี้ไม่มีสิทธิ์ผู้ดูแลระบบแล้ว');
      }
      _current = fresh;
    }
    _admins = await _b.listAdmins();
    notifyListeners();
  }

  /// ผู้ดูแลหลักเพิ่มแอดมิน / เปลี่ยนสิทธิ์ / ถอดสิทธิ์ (role = user)
  Future<void> setRole(String email, String role) async {
    if (_current?.isOwner != true) {
      throw const AuthException('เฉพาะผู้ดูแลหลักเท่านั้นที่ทำรายการนี้ได้');
    }
    await _b.setRoleByEmail(email.trim(), role);
    await refreshAdmins();
  }

  static String? validatePassword(String? v) {
    if ((v ?? '').length < 8) return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัว';
    return null;
  }
}

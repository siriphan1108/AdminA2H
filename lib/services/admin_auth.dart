import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_store.dart';

const kRoleOwner = 'ผู้ดูแลหลัก'; // เพิ่ม/ระงับ/ลบแอดมินคนอื่นได้
const kRoleAdmin = 'แอดมิน';
const kAdminRoles = [kRoleOwner, kRoleAdmin];

/// บัญชีผู้ดูแลระบบ (คนที่เข้าเว็บแอดมินได้)
class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.phone = '',
    required this.role,
    this.active = true,
    required this.salt,
    required this.hash,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String username;
  final String email;
  final String phone;
  final String role;
  final bool active;
  final String salt;
  final String hash;
  final DateTime createdAt;

  bool get isOwner => role == kRoleOwner;

  AdminAccount copyWith({
    String? name,
    String? username,
    String? email,
    String? phone,
    String? role,
    bool? active,
    String? salt,
    String? hash,
  }) => AdminAccount(
    id: id,
    name: name ?? this.name,
    username: username ?? this.username,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    active: active ?? this.active,
    salt: salt ?? this.salt,
    hash: hash ?? this.hash,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    'email': email,
    'phone': phone,
    'role': role,
    'active': active,
    'salt': salt,
    'hash': hash,
    'created_at': createdAt.toIso8601String(),
  };

  factory AdminAccount.fromJson(Map<String, dynamic> j) => AdminAccount(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    username: j['username'] as String? ?? '',
    email: j['email'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    role: j['role'] as String? ?? kRoleAdmin,
    active: j['active'] as bool? ?? true,
    salt: j['salt'] as String,
    hash: j['hash'] as String,
    createdAt:
        DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

/// เกิดเมื่อทำรายการไม่ได้ — [message] เป็นข้อความภาษาไทยสำหรับแสดงผู้ใช้
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// ระบบบัญชีแอดมินแบบเก็บในเบราว์เซอร์ (ทางเลือก ข.)
///
/// รหัสผ่านไม่ได้เก็บตรง ๆ: เก็บเป็น SHA-256 แบบใส่ salt และวนซ้ำหลายรอบ
/// แต่ข้อมูลทั้งหมดอยู่ใน localStorage ของเครื่องนี้ คนที่ใช้เครื่องนี้แก้ไขได้
/// จึงเหมาะกับการสาธิต ไม่ใช่ความปลอดภัยจริง
/// TODO: ย้ายไป backend (เช่น Supabase Auth) ตอนใช้งานจริง
class AdminAuth extends ChangeNotifier {
  AdminAuth._();
  static final AdminAuth instance = AdminAuth._();

  static const _accountsKey = 'admin_a2h_admins_v1';
  static const _sessionKey = 'admin_a2h_session_v1';
  static const _lockKey = 'admin_a2h_login_lock_v1';
  static const lockDuration = Duration(minutes: 5);
  static const _rounds = 4000;

  final List<AdminAccount> _accounts = [];
  String? _currentId;
  int _failed = 0;
  DateTime? _lockedUntil;
  Future<void>? _loading;

  List<AdminAccount> get accounts => List.unmodifiable(_accounts);
  bool get hasAdmins => _accounts.isNotEmpty;

  AdminAccount? get current {
    for (final a in _accounts) {
      if (a.id == _currentId) return a;
    }
    return null;
  }

  DateTime? get lockedUntil =>
      _lockedUntil != null && _lockedUntil!.isAfter(DateTime.now())
      ? _lockedUntil
      : null;

  Future<void> load() => _loading ??= _load();

  @visibleForTesting
  void debugReset() {
    _accounts.clear();
    _currentId = null;
    _failed = 0;
    _lockedUntil = null;
    _loading = null;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_accountsKey);
      if (raw != null) {
        for (final e in jsonDecode(raw) as List) {
          _accounts.add(AdminAccount.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      // จดจำการเข้าสู่ระบบ
      final session = prefs.getString(_sessionKey);
      if (session != null &&
          _accounts.any((a) => a.id == session && a.active)) {
        _currentId = session;
      }
      final lock = prefs.getString(_lockKey);
      if (lock != null) {
        final j = jsonDecode(lock) as Map<String, dynamic>;
        _failed = j['failed'] as int? ?? 0;
        _lockedUntil = DateTime.tryParse(j['until'] as String? ?? '');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('โหลดบัญชีแอดมินไม่สำเร็จ: $e');
    }
  }

  // ------------------------------ password ---------------------------------

  static String _newSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String _hash(String password, String salt) {
    var bytes = utf8.encode('$salt:$password');
    for (var i = 0; i < _rounds; i++) {
      bytes = Uint8List.fromList(sha256.convert(bytes).bytes);
    }
    return base64Url.encode(bytes);
  }

  static bool _check(AdminAccount a, String password) =>
      _hash(password, a.salt) == a.hash;

  static String? validatePassword(String? v) {
    if ((v ?? '').length < 8) return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัว';
    return null;
  }

  // ----------------------------- persistence -------------------------------

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _accountsKey,
      jsonEncode([for (final a in _accounts) a.toJson()]),
    );
  }

  Future<void> _saveLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lockKey,
      jsonEncode({'failed': _failed, 'until': _lockedUntil?.toIso8601String()}),
    );
  }

  AdminAccount? _find(String usernameOrEmail) {
    final q = usernameOrEmail.trim().toLowerCase();
    for (final a in _accounts) {
      if (a.username.toLowerCase() == q || a.email.toLowerCase() == q) {
        return a;
      }
    }
    return null;
  }

  void _checkUnique(String username, String email, {String? exceptId}) {
    for (final a in _accounts) {
      if (a.id == exceptId) continue;
      if (a.username.toLowerCase() == username.trim().toLowerCase()) {
        throw const AuthException('ชื่อผู้ใช้นี้มีอยู่แล้ว');
      }
      if (email.isNotEmpty &&
          a.email.toLowerCase() == email.trim().toLowerCase()) {
        throw const AuthException('อีเมลนี้มีผู้ดูแลระบบใช้แล้ว');
      }
    }
  }

  AdminAccount _newAccount({
    required String name,
    required String username,
    required String email,
    required String role,
    required String password,
  }) {
    final salt = _newSalt();
    return AdminAccount(
      id: 'a${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      username: username.trim(),
      email: email.trim(),
      role: role,
      salt: salt,
      hash: _hash(password, salt),
      createdAt: DateTime.now(),
    );
  }

  // ------------------------------- actions ---------------------------------

  /// สร้างผู้ดูแลหลักคนแรก (ทำได้ครั้งเดียว ตอนยังไม่มีแอดมินเลย) แล้วเข้าสู่ระบบ
  Future<void> createFirstOwner({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    await load();
    if (hasAdmins) {
      throw const AuthException('มีผู้ดูแลระบบอยู่แล้ว กรุณาเข้าสู่ระบบ');
    }
    final a = _newAccount(
      name: name,
      username: username,
      email: email,
      role: kRoleOwner,
      password: password,
    );
    _accounts.add(a);
    _currentId = a.id;
    await _save();
    notifyListeners();
  }

  /// เข้าสู่ระบบด้วยชื่อผู้ใช้หรืออีเมล — ผิดเกินจำนวนที่ตั้งไว้จะล็อก 5 นาที
  Future<void> login(
    String usernameOrEmail,
    String password, {
    bool remember = false,
  }) async {
    await load();
    final until = lockedUntil;
    if (until != null) {
      final mins = until.difference(DateTime.now()).inMinutes + 1;
      throw AuthException(
        'ใส่รหัสผ่านผิดหลายครั้ง กรุณาลองใหม่ในอีก $mins นาที',
      );
    }
    final a = _find(usernameOrEmail);
    if (a == null || !_check(a, password)) {
      await SettingsStore.instance.load();
      final max = SettingsStore.instance.number('max_login_attempts');
      _failed++;
      if (_failed >= max) {
        _failed = 0;
        _lockedUntil = DateTime.now().add(lockDuration);
        await _saveLock();
        throw AuthException(
          'ใส่รหัสผ่านผิดครบ $max ครั้ง ระบบล็อกการเข้าสู่ระบบไว้ 5 นาที',
        );
      }
      await _saveLock();
      throw AuthException(
        'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง (เหลืออีก ${max - _failed} ครั้ง)',
      );
    }
    if (!a.active) {
      throw const AuthException('บัญชีนี้ถูกระงับ กรุณาติดต่อผู้ดูแลหลัก');
    }
    _failed = 0;
    _lockedUntil = null;
    await _saveLock();
    _currentId = a.id;
    final prefs = await SharedPreferences.getInstance();
    if (remember) {
      await prefs.setString(_sessionKey, a.id);
    } else {
      await prefs.remove(_sessionKey);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _currentId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    notifyListeners();
  }

  void _replace(AdminAccount updated) {
    final i = _accounts.indexWhere((a) => a.id == updated.id);
    _accounts[i] = updated;
  }

  /// แก้ข้อมูลของบัญชีที่เข้าสู่ระบบอยู่
  Future<void> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    final me = current;
    if (me == null) throw const AuthException('กรุณาเข้าสู่ระบบ');
    _checkUnique(me.username, email, exceptId: me.id);
    _replace(
      me.copyWith(name: name.trim(), email: email.trim(), phone: phone.trim()),
    );
    await _save();
    notifyListeners();
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final me = current;
    if (me == null) throw const AuthException('กรุณาเข้าสู่ระบบ');
    if (!_check(me, currentPassword)) {
      throw const AuthException('รหัสผ่านปัจจุบันไม่ถูกต้อง');
    }
    final salt = _newSalt();
    _replace(me.copyWith(salt: salt, hash: _hash(newPassword, salt)));
    await _save();
    notifyListeners();
  }

  void _requireOwner() {
    if (current?.isOwner != true) {
      throw const AuthException('เฉพาะผู้ดูแลหลักเท่านั้นที่ทำรายการนี้ได้');
    }
  }

  /// ผู้ดูแลหลักเพิ่มแอดมินใหม่ พร้อมรหัสผ่านชั่วคราว
  Future<void> addAdmin({
    required String name,
    required String username,
    required String email,
    required String role,
    required String password,
  }) async {
    _requireOwner();
    _checkUnique(username, email);
    _accounts.add(
      _newAccount(
        name: name,
        username: username,
        email: email,
        role: role,
        password: password,
      ),
    );
    await _save();
    notifyListeners();
  }

  /// ต้องเหลือผู้ดูแลหลักที่ใช้งานได้อย่างน้อย 1 คนเสมอ
  void _keepOneOwner(AdminAccount changing) {
    final others = _accounts.where(
      (a) => a.id != changing.id && a.isOwner && a.active,
    );
    if (changing.isOwner && others.isEmpty) {
      throw const AuthException('ต้องมีผู้ดูแลหลักที่ใช้งานได้อย่างน้อย 1 คน');
    }
  }

  Future<void> setRole(AdminAccount a, String role) async {
    _requireOwner();
    if (role != kRoleOwner) _keepOneOwner(a);
    _replace(a.copyWith(role: role));
    await _save();
    notifyListeners();
  }

  Future<void> setActive(AdminAccount a, bool active) async {
    _requireOwner();
    if (a.id == _currentId) {
      throw const AuthException('ระงับบัญชีของตัวเองไม่ได้');
    }
    if (!active) _keepOneOwner(a);
    _replace(a.copyWith(active: active));
    await _save();
    notifyListeners();
  }

  /// ผู้ดูแลหลักตั้งรหัสผ่านใหม่ให้แอดมินที่ลืมรหัส
  Future<void> resetPassword(AdminAccount a, String newPassword) async {
    _requireOwner();
    final salt = _newSalt();
    _replace(a.copyWith(salt: salt, hash: _hash(newPassword, salt)));
    await _save();
    notifyListeners();
  }

  Future<void> remove(AdminAccount a) async {
    _requireOwner();
    if (a.id == _currentId) throw const AuthException('ลบบัญชีของตัวเองไม่ได้');
    _keepOneOwner(a);
    _accounts.removeWhere((x) => x.id == a.id);
    await _save();
    notifyListeners();
  }
}

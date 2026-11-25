import 'package:admin_a2h/services/admin_auth.dart';
import 'package:admin_a2h/services/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AdminAuth auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SettingsStore.instance.debugReset();
    auth = AdminAuth.instance..debugReset();
  });

  test('first owner, login, wrong password lockout', () async {
    await auth.load();
    expect(auth.hasAdmins, isFalse);

    await auth.createFirstOwner(
      name: 'สมศรี',
      username: 'somsri',
      email: 'somsri@a2.co.th',
      password: 'password123',
    );
    expect(auth.current?.isOwner, isTrue);
    // รหัสผ่านไม่ได้เก็บตรง ๆ
    expect(auth.current!.hash.contains('password123'), isFalse);

    // สร้างคนแรกซ้ำไม่ได้
    expect(
      () => auth.createFirstOwner(
        name: 'x',
        username: 'x',
        email: '',
        password: 'password123',
      ),
      throwsA(isA<AuthException>()),
    );

    await auth.logout();
    expect(auth.current, isNull);

    await auth.login('SOMSRI@a2.co.th', 'password123'); // อีเมลก็ได้
    expect(auth.current?.username, 'somsri');
    await auth.logout();

    // ผิด 5 ครั้ง (ค่าเริ่มต้น) = ล็อก
    for (var i = 0; i < 4; i++) {
      await expectLater(
        auth.login('somsri', 'wrong-pass'),
        throwsA(isA<AuthException>()),
      );
    }
    await expectLater(
      auth.login('somsri', 'wrong-pass'),
      throwsA(
        isA<AuthException>().having((e) => e.message, 'm', contains('ล็อก')),
      ),
    );
    expect(auth.lockedUntil, isNotNull);
    // ถึงรหัสถูกก็เข้าไม่ได้ระหว่างล็อก
    await expectLater(
      auth.login('somsri', 'password123'),
      throwsA(isA<AuthException>()),
    );
  });

  test('owner adds admins; admin cannot; keep one owner', () async {
    await auth.createFirstOwner(
      name: 'Owner',
      username: 'owner',
      email: 'owner@a2.co.th',
      password: 'password123',
    );
    final owner = auth.current!;

    await auth.addAdmin(
      name: 'Staff',
      username: 'staff',
      email: 'staff@a2.co.th',
      role: kRoleAdmin,
      password: 'temp-pass-1',
    );
    expect(auth.accounts.length, 2);

    // ชื่อผู้ใช้ซ้ำไม่ได้
    expect(
      () => auth.addAdmin(
        name: 'dup',
        username: 'STAFF',
        email: '',
        role: kRoleAdmin,
        password: 'temp-pass-1',
      ),
      throwsA(isA<AuthException>()),
    );

    // ลบ/ระงับตัวเองไม่ได้
    expect(() => auth.remove(owner), throwsA(isA<AuthException>()));

    // แอดมินธรรมดาเพิ่มคนอื่นไม่ได้
    await auth.logout();
    await auth.login('staff', 'temp-pass-1');
    expect(
      () => auth.addAdmin(
        name: 'n',
        username: 'nnn',
        email: '',
        role: kRoleAdmin,
        password: 'temp-pass-1',
      ),
      throwsA(isA<AuthException>()),
    );

    // เปลี่ยนรหัสผ่านตัวเอง
    await expectLater(
      auth.changePassword('wrong', 'new-pass-123'),
      throwsA(isA<AuthException>()),
    );
    await auth.changePassword('temp-pass-1', 'new-pass-123');
    await auth.logout();
    await auth.login('staff', 'new-pass-123');

    // ผู้ดูแลหลักระงับ staff แล้ว staff เข้าไม่ได้
    await auth.logout();
    await auth.login('owner', 'password123');
    final staff = auth.accounts.firstWhere((a) => a.username == 'staff');
    await auth.setActive(staff, false);
    await auth.logout();
    await expectLater(
      auth.login('staff', 'new-pass-123'),
      throwsA(
        isA<AuthException>().having((e) => e.message, 'm', contains('ระงับ')),
      ),
    );

    // ลดสิทธิ์ผู้ดูแลหลักคนสุดท้ายไม่ได้
    await auth.login('owner', 'password123');
    expect(
      () => auth.setRole(auth.current!, kRoleAdmin),
      throwsA(isA<AuthException>()),
    );
  });

  test('remember login survives reload', () async {
    await auth.createFirstOwner(
      name: 'Owner',
      username: 'owner',
      email: '',
      password: 'password123',
    );
    await auth.logout();
    await auth.login('owner', 'password123', remember: true);

    auth.debugReset(); // จำลองการรีเฟรชหน้าเว็บ
    await auth.load();
    expect(auth.current?.username, 'owner');
  });
}

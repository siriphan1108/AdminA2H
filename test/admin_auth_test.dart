import 'package:admin_a2h/services/admin_auth.dart';
import 'package:admin_a2h/services/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_backend.dart';

void main() {
  late AdminAuth auth;
  late FakeAuthBackend backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SettingsStore.instance.debugReset();
    backend = FakeAuthBackend()
      ..addUser('o1', 'owner@a2.co.th', 'password123', role: kRoleOwner, name: 'Owner')
      ..addUser('a1', 'staff@a2.co.th', 'staffpass1', role: kRoleAdmin)
      ..addUser('c1', 'customer@gmail.com', 'custpass12');
    auth = AdminAuth.instance
      ..debugReset()
      ..useBackend(backend);
  });

  test('only admins can log in; customers are signed out again', () async {
    await expectLater(
      auth.login('customer@gmail.com', 'custpass12'),
      throwsA(isA<AuthException>().having((e) => e.message, 'm', contains('ไม่มีสิทธิ์'))),
    );
    expect(auth.current, isNull);
    expect(backend.sessionUserId, isNull);

    await auth.login('OWNER@a2.co.th', 'password123');
    expect(auth.current?.isOwner, isTrue);
    expect(auth.name, 'Owner');

    await auth.logout();
    expect(auth.current, isNull);
    expect(backend.sessionUserId, isNull);
  });

  test('wrong password counts down and locks after 5 tries', () async {
    for (var i = 0; i < 4; i++) {
      await expectLater(
        auth.login('owner@a2.co.th', 'nope'),
        throwsA(isA<AuthException>().having((e) => e.message, 'm', contains('เหลืออีก'))),
      );
    }
    await expectLater(
      auth.login('owner@a2.co.th', 'nope'),
      throwsA(isA<AuthException>().having((e) => e.message, 'm', contains('ล็อก'))),
    );
    // ถึงรหัสถูกก็เข้าไม่ได้ระหว่างล็อก
    await expectLater(
      auth.login('owner@a2.co.th', 'password123'),
      throwsA(isA<AuthException>()),
    );
  });

  test('owner manages admins; admin cannot', () async {
    await auth.login('owner@a2.co.th', 'password123');
    await auth.refreshAdmins();
    expect(auth.admins.length, 2);

    await auth.setRole('customer@gmail.com', kRoleAdmin);
    expect(auth.admins.map((a) => a.email), contains('customer@gmail.com'));

    await expectLater(
      auth.setRole('nobody@x.com', kRoleAdmin),
      throwsA(isA<AuthException>().having((e) => e.message, 'm', contains('ไม่พบ'))),
    );
    await expectLater(
      auth.setRole('owner@a2.co.th', kRoleUser),
      throwsA(isA<AuthException>()), // เปลี่ยนสิทธิ์ตัวเองไม่ได้
    );

    await auth.setRole('customer@gmail.com', kRoleUser); // ถอดสิทธิ์
    expect(auth.admins.length, 2);

    await auth.logout();
    await auth.login('staff@a2.co.th', 'staffpass1');
    await expectLater(
      auth.setRole('customer@gmail.com', kRoleAdmin),
      throwsA(isA<AuthException>()),
    );
  });

  test('refresh picks up a role change made in Supabase', () async {
    await auth.login('staff@a2.co.th', 'staffpass1');
    expect(auth.current?.isOwner, isFalse);
    backend.profiles['a1'] = const AdminProfile(
      id: 'a1',
      email: 'staff@a2.co.th',
      name: '',
      phone: '',
      role: kRoleOwner,
    );
    await auth.refreshAdmins();
    expect(auth.current?.isOwner, isTrue);
  });

  test('change password checks the current one', () async {
    await auth.login('staff@a2.co.th', 'staffpass1');
    await expectLater(
      auth.changePassword('wrong', 'newpass123'),
      throwsA(isA<AuthException>()),
    );
    await auth.changePassword('staffpass1', 'newpass123');
    await auth.logout();
    await auth.login('staff@a2.co.th', 'newpass123');
    expect(auth.current?.email, 'staff@a2.co.th');
  });

  test('remember me keeps the session after reload; otherwise signs out', () async {
    await auth.login('owner@a2.co.th', 'password123', remember: true);
    auth
      ..debugReset()
      ..useBackend(backend); // จำลองรีเฟรชหน้าเว็บ
    await auth.load();
    expect(auth.current?.email, 'owner@a2.co.th');

    await auth.login('owner@a2.co.th', 'password123');
    auth
      ..debugReset()
      ..useBackend(backend);
    await auth.load();
    expect(auth.current, isNull);
    expect(backend.sessionUserId, isNull);
  });
}

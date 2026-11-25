import 'package:admin_a2h/pages/settings_page.dart';
import 'package:admin_a2h/services/admin_auth.dart';
import 'package:admin_a2h/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_backend.dart';

void main() {
  testWidgets('settings: 6 cards, company info and toggles are saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore.instance..debugReset();
    await tester.runAsync(store.load);
    final backend = FakeAuthBackend()
      ..addUser('o1', 'owner@a2.co.th', 'password123', role: kRoleOwner, name: 'Owner');
    final auth = AdminAuth.instance
      ..debugReset()
      ..useBackend(backend);
    await tester.runAsync(() => auth.login('owner@a2.co.th', 'password123'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(username: 'Admin', onLogout: () {}),
        ),
      ),
    );
    await tester.pump();

    for (final t in [
      'บัญชีผู้ดูแลระบบ',
      'ข้อมูลบริษัท',
      'การแจ้งเตือน',
      'ความปลอดภัย',
      'จัดการข้อมูลระบบ',
      'เกี่ยวกับระบบ',
    ]) {
      expect(find.text(t), findsOneWidget);
    }

    // ข้อมูลบริษัท
    await tester.tap(find.text('ข้อมูลบริษัท'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(2), '02-123-4567');
    await tester.enterText(find.byType(TextFormField).at(3), 'bad-email');
    await tester.tap(find.text('บันทึก'));
    await tester.pump();
    expect(find.text('รูปแบบอีเมลไม่ถูกต้อง'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(3), 'info@a2.co.th');
    await tester.tap(find.text('บันทึก'));
    await tester.runAsync(() => Future.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(store.text('company_phone'), '02-123-4567');
    expect(store.text('company_email'), 'info@a2.co.th');

    // การแจ้งเตือน
    await tester.tap(find.text('การแจ้งเตือน'));
    await tester.pumpAndSettle();
    expect(store.flag('notify_weekly_email'), isFalse);
    await tester.tap(find.text('อีเมลสรุปรายสัปดาห์'));
    await tester.pump();
    await tester.tap(find.text('บันทึก'));
    await tester.runAsync(() => Future.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(store.flag('notify_weekly_email'), isTrue);

    // บัญชี: รหัสผ่านใหม่ไม่ตรงกัน
    await tester.tap(find.text('บัญชีผู้ดูแลระบบ'));
    await tester.pumpAndSettle();
    final f = find.byType(TextFormField);
    await tester.enterText(f.at(2), 'oldpass');
    await tester.enterText(f.at(3), 'newpassword');
    await tester.enterText(f.at(4), 'different1');
    await tester.tap(find.text('บันทึก'));
    await tester.pump();
    expect(find.text('รหัสผ่านไม่ตรงกัน'), findsOneWidget);

    // แท็บผู้ดูแลระบบทั้งหมด: ผู้ดูแลหลักเห็นปุ่มเพิ่ม
    await tester.tap(find.text('ผู้ดูแลระบบทั้งหมด'));
    await tester.runAsync(() => Future.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Owner (คุณ)'), findsOneWidget);
    expect(find.text('เพิ่มผู้ดูแลระบบ'), findsOneWidget);
  });
}

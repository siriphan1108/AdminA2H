import 'package:admin_a2h/pages/login_page.dart';
import 'package:admin_a2h/services/admin_auth.dart';
import 'package:admin_a2h/services/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login form shows validation errors when empty', (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: LoginCard())),
      ),
    );

    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pump();

    expect(find.text('กรุณากรอกอีเมล'), findsOneWidget);
    expect(find.text('กรุณากรอกรหัสผ่าน'), findsOneWidget);
  });

  testWidgets('wrong password clears the field so it can be retyped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    SettingsStore.instance.debugReset();
    AdminAuth.instance
      ..debugReset()
      ..useBackend(
        FakeAuthBackend()
          ..addUser('o1', 'owner@a2.co.th', 'password123', role: kRoleOwner),
      );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: LoginCard()))),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'owner@a2.co.th');
    await tester.enterText(fields.at(1), 'wrong-pass');
    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.runAsync(() => Future.delayed(Duration.zero));
    await tester.pump();

    expect(find.textContaining('ไม่ถูกต้อง'), findsOneWidget);
    final pw = tester.widget<EditableText>(
      find.descendant(of: fields.at(1), matching: find.byType(EditableText)),
    );
    expect(pw.controller.text, isEmpty); // ล้างแล้ว
    expect(pw.focusNode.hasFocus, isTrue); // พร้อมพิมพ์ใหม่

    await tester.enterText(fields.at(1), 'p');
    await tester.pump();
    expect(find.textContaining('ไม่ถูกต้อง'), findsNothing);
  });
}

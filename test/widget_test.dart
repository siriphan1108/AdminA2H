import 'package:admin_a2h/pages/login_page.dart';
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

    expect(find.text('กรุณากรอกชื่อผู้ใช้'), findsOneWidget);
    expect(find.text('กรุณากรอกรหัสผ่าน'), findsOneWidget);
  });
}

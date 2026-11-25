import 'package:admin_a2h/pages/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard renders and sidebar switches pages', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: DashboardPage()));

    expect(find.text('ยินดีต้อนรับสู่ระบบผู้ดูแล'), findsOneWidget);
    expect(find.text('โครงการทั้งหมด'), findsOneWidget);
    expect(find.text('ผู้ใช้งานทั้งหมด'), findsOneWidget);
    expect(find.text('ข้อความใหม่'), findsNothing); // เอาการ์ดข้อความออกแล้ว
    expect(find.text('1,250'), findsNothing); // ไม่มีตัวเลขตัวอย่าง

    await tester.tap(find.text('ตั้งค่าระบบ'));
    await tester.pump();
    expect(find.text('บัญชีผู้ดูแลระบบ'), findsOneWidget);
    expect(find.text('เกี่ยวกับระบบ'), findsOneWidget);
  });
}

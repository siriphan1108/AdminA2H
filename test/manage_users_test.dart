import 'package:admin_a2h/pages/manage_users_page.dart';
import 'package:admin_a2h/services/user_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('user table: sample users, search, edit, delete', (tester) async {
    tester.view.physicalSize = const Size(1800, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final store = UserStore.instance..debugReset();
    await tester.runAsync(store.load);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManageUsersPage(username: 'Admin', onLogout: () {}),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Thanakrit Wongsa'), findsOneWidget);
    expect(find.text('แสดงทั้งหมด 5 รายการ'), findsOneWidget);
    expect(find.text('12/10/2568\n14:32 น.'), findsOneWidget);

    // search
    await tester.enterText(find.byType(TextField), 'natcha');
    await tester.pump();
    expect(find.text('Natcha Srisuk'), findsOneWidget);
    expect(find.text('Thanakrit Wongsa'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    // no add-user button
    expect(find.text('เพิ่มผู้ใช้งาน'), findsNothing);

    // edit: duplicate email is rejected, then suspend
    await tester.tap(find.byTooltip('แก้ไข').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'thanakrit@gmail.com',
    );
    await tester.tap(find.text('บันทึกการแก้ไข'));
    await tester.pump();
    expect(find.text('อีเมลนี้มีผู้ใช้แล้ว'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'siriphan@example.com',
    );
    await tester.tap(find.text('ระงับใช้งาน').last);
    await tester.tap(find.text('บันทึกการแก้ไข'));
    await tester.runAsync(() => Future.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(store.users.first.status, 'ระงับใช้งาน');

    // delete
    await tester.tap(find.byTooltip('ลบ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบผู้ใช้'));
    await tester.runAsync(() => Future.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('ศิริพรรณ รัตนชัยวณิชกุล'), findsNothing);
    expect(store.users.length, 4);
  });
}

import 'package:admin_a2h/data/thai_address.dart';
import 'package:admin_a2h/pages/add_project_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpPage(WidgetTester tester, {int initialStep = 0}) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AddProjectPage(
          username: 'Admin',
          onLogout: () {},
          initialStep: initialStep,
        ),
      ),
    ),
  );
}

/// TextFormField ที่อยู่ใต้ป้ายชื่อช่อง (ช่องบังคับมี " *" ต่อท้าย)
Finder _fieldUnder(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextFormField),
);

void main() {
  testWidgets('stepper shows 5 steps and blocks Next when step 1 is empty', (
    tester,
  ) async {
    await _pumpPage(tester);

    for (final t in [
      'ข้อมูลทั่วไป',
      'รูปภาพ',
      'ราคาและค่าใช้จ่าย',
      'ค่าคอมมิชชั่น',
      'ติดต่อสอบถาม',
    ]) {
      expect(find.text(t), findsWidgets);
    }
    expect(find.text('ขั้นตอนที่ 1 จาก 5'), findsOneWidget);
    expect(find.text('ย้อนกลับ'), findsNothing);

    await tester.ensureVisible(find.text('ถัดไป'));
    await tester.tap(find.text('ถัดไป'));
    await tester.pump();

    expect(find.text('กรุณาเลือกประเภท'), findsOneWidget);
    expect(find.text('ขั้นตอนที่ 1 จาก 5'), findsOneWidget); // still on step 1
  });

  testWidgets('price step → commission step calculates the commission', (
    tester,
  ) async {
    await _pumpPage(tester, initialStep: 2);

    await tester.enterText(_fieldUnder('ราคาเริ่มต้น *'), '2000000');
    await tester.pump();
    expect(find.text('2,000,000'), findsOneWidget);

    await tester.ensureVisible(find.text('ถัดไป'));
    await tester.tap(find.text('ถัดไป'));
    await tester.pump();
    expect(find.text('ขั้นตอนที่ 4 จาก 5'), findsOneWidget);

    await tester.enterText(_fieldUnder('อัตราค่าคอมมิชชั่น *'), '3');
    await tester.pump();
    expect(find.text('60,000'), findsOneWidget);

    // Back keeps what was typed.
    await tester.ensureVisible(find.text('ย้อนกลับ'));
    await tester.tap(find.text('ย้อนกลับ'));
    await tester.pump();
    expect(find.text('ขั้นตอนที่ 3 จาก 5'), findsOneWidget);
    expect(find.text('2,000,000'), findsOneWidget);
  });

  addressAndDateTests();
}

void addressAndDateTests() {
  test(
    'Thai address data: province → district → subdistrict → postcode',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      ThaiAddress.debugReset();
      final a = await ThaiAddress.load();
      expect(a.districts('กรุงเทพมหานคร'), contains('พระนคร'));
      expect(a.districts('เชียงใหม่'), contains('เมืองเชียงใหม่'));
      expect(
        a.subdistricts('กรุงเทพมหานคร', 'พระนคร'),
        contains('พระบรมมหาราชวัง'),
      );
    },
  );

  testWidgets('Enter picks the suggestion: province → district → subdistrict', (
    tester,
  ) async {
    // โหลดข้อมูลให้เสร็จด้วยเวลาจริงก่อนเปิดหน้า
    ThaiAddress.debugReset();
    await tester.runAsync(() => ThaiAddress.load());
    await _pumpPage(tester);
    // ให้ .then ของข้อมูลที่โหลดเสร็จแล้ว (อยู่ในเวลาจริง) ได้ทำงาน แล้ววาดใหม่
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    Future<void> typeAndEnter(String label, String text) async {
      final f = _fieldUnder(label);
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.enterText(f, text);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
    }

    await typeAndEnter('จังหวัด *', 'กรุงเท');
    expect(find.text('กรุงเทพมหานคร'), findsOneWidget);

    await typeAndEnter('เขต/อำเภอ *', 'พระน');
    expect(find.text('พระนคร'), findsOneWidget);

    await typeAndEnter('แขวง/ตำบล *', 'พระบรม');
    expect(find.text('พระบรมมหาราชวัง'), findsOneWidget);
  });

  testWidgets('date field opens the Thai date picker', (tester) async {
    await _pumpPage(tester, initialStep: 3);
    final f = _fieldUnder('วันที่เริ่มขาย');
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(find.text('ตกลง'), findsOneWidget);
    expect(find.textContaining('${now.year + 543}'), findsWidgets);

    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    expect(find.text('$d/$m/${now.year + 543}'), findsOneWidget);
  });
}

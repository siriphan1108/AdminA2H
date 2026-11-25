import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// บันทึกไฟล์ลงเครื่องผู้ใช้ (ใช้ได้เฉพาะบนเว็บ)
Future<void> downloadBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.appendChild(a);
  a.click();
  a.remove();
  // รอให้เบราว์เซอร์เริ่มดาวน์โหลดก่อนคืนหน่วยความจำ
  await Future<void>.delayed(const Duration(seconds: 2));
  web.URL.revokeObjectURL(url);
}

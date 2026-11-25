import 'dart:typed_data';

/// บันทึกไฟล์ลงเครื่องผู้ใช้ (ใช้ได้เฉพาะบนเว็บ)
Future<void> downloadBytes(Uint8List bytes, String filename, String mimeType) {
  throw UnsupportedError('ดาวน์โหลดไฟล์ได้เฉพาะบนเว็บ');
}

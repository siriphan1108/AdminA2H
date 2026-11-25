import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// รูปที่วางในเซลล์ (PNG) — [width]/[height] เป็นพิกเซลที่จะแสดงในชีต
class XlsxImage {
  const XlsxImage(this.png, this.width, this.height);
  final Uint8List png;
  final int width;
  final int height;
}

/// ชีตหนึ่งแผ่น: แถวหัวตาราง + แถวข้อมูล
///
/// ค่าในเซลล์เป็น String / num / null หรือ [XlsxImage] (รูปลอยอยู่บนเซลล์นั้น)
class XlsxSheet {
  XlsxSheet({
    required this.name,
    required this.headers,
    required this.rows,
    this.columnWidths = const {},
    this.rowHeight,
  });

  final String name;
  final List<String> headers;
  final List<List<Object?>> rows;

  /// ความกว้างคอลัมน์ (หน่วยตัวอักษรของ Excel) — ไม่ระบุ = 16
  final Map<int, double> columnWidths;

  /// ความสูงแถวข้อมูล (pt) — ใช้เมื่อมีรูป
  final double? rowHeight;
}

/// เขียนไฟล์ .xlsx (Office Open XML) แบบไม่ต้องพึ่งไลบรารี Excel
/// เปิดได้ใน Excel / Google Sheets / LibreOffice
Uint8List buildXlsx(List<XlsxSheet> sheets) {
  final files = <String, List<int>>{};
  void put(String path, String xml) => files[path] = utf8.encode(xml);

  var mediaCount = 0;
  final sheetHasDrawing = <bool>[];

  for (var s = 0; s < sheets.length; s++) {
    final sheet = sheets[s];
    final n = s + 1;
    final images = <(int row, int col, XlsxImage img, int media)>[];

    final sb = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
      )
      // ตรึงแถวหัวตาราง
      ..write(
        '<sheetViews><sheetView workbookViewId="0">'
        '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
        '</sheetView></sheetViews>',
      )
      ..write('<sheetFormatPr defaultRowHeight="20"/>')
      ..write('<cols>');
    for (var c = 0; c < sheet.headers.length; c++) {
      final w = sheet.columnWidths[c] ?? 16;
      sb.write(
        '<col min="${c + 1}" max="${c + 1}" width="$w" customWidth="1"/>',
      );
    }
    sb.write('</cols><sheetData>');

    // แถวหัวตาราง (style 1)
    sb.write('<row r="1" ht="28" customHeight="1">');
    for (var c = 0; c < sheet.headers.length; c++) {
      sb.write(_cell(c, 0, sheet.headers[c], style: 1));
    }
    sb.write('</row>');

    for (var r = 0; r < sheet.rows.length; r++) {
      final rowNo = r + 2;
      final ht = sheet.rowHeight;
      sb.write(
        ht == null
            ? '<row r="$rowNo">'
            : '<row r="$rowNo" ht="$ht" customHeight="1">',
      );
      final row = sheet.rows[r];
      for (var c = 0; c < row.length; c++) {
        final v = row[c];
        if (v is XlsxImage) {
          images.add((r + 1, c, v, ++mediaCount));
          continue;
        }
        if (v != null) sb.write(_cell(c, r + 1, v, style: 2));
      }
      sb.write('</row>');
    }
    sb.write('</sheetData>');
    if (sheet.headers.isNotEmpty) {
      final last = _colName(sheet.headers.length - 1);
      sb.write('<autoFilter ref="A1:$last${sheet.rows.length + 1}"/>');
    }
    if (images.isNotEmpty) sb.write('<drawing r:id="rId1"/>');
    sb.write('</worksheet>');
    put('xl/worksheets/sheet$n.xml', sb.toString());
    sheetHasDrawing.add(images.isNotEmpty);

    if (images.isNotEmpty) {
      put(
        'xl/worksheets/_rels/sheet$n.xml.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" '
            'Target="../drawings/drawing$n.xml"/></Relationships>',
      );
      final d = StringBuffer()
        ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
        ..write(
          '<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" '
          'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
        );
      final rels = StringBuffer()
        ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
        ..write(
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
        );
      for (var i = 0; i < images.length; i++) {
        final (row, col, img, media) = images[i];
        const emu = 9525; // EMU ต่อพิกเซล
        final rid = 'rId${i + 1}';
        d.write(
          '<xdr:oneCellAnchor>'
          '<xdr:from><xdr:col>$col</xdr:col><xdr:colOff>${4 * emu}</xdr:colOff>'
          '<xdr:row>$row</xdr:row><xdr:rowOff>${4 * emu}</xdr:rowOff></xdr:from>'
          '<xdr:ext cx="${img.width * emu}" cy="${img.height * emu}"/>'
          '<xdr:pic><xdr:nvPicPr><xdr:cNvPr id="${i + 2}" name="Picture ${i + 1}"/>'
          '<xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr></xdr:nvPicPr>'
          '<xdr:blipFill><a:blip r:embed="$rid"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill>'
          '<xdr:spPr><a:xfrm><a:off x="0" y="0"/>'
          '<a:ext cx="${img.width * emu}" cy="${img.height * emu}"/></a:xfrm>'
          '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr></xdr:pic>'
          '<xdr:clientData/></xdr:oneCellAnchor>',
        );
        rels.write(
          '<Relationship Id="$rid" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
          'Target="../media/image$media.png"/>',
        );
        files['xl/media/image$media.png'] = img.png;
      }
      d.write('</xdr:wsDr>');
      rels.write('</Relationships>');
      put('xl/drawings/drawing$n.xml', d.toString());
      put('xl/drawings/_rels/drawing$n.xml.rels', rels.toString());
    }
  }

  // workbook
  final wb = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>',
    );
  final wbRels = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    );
  for (var s = 0; s < sheets.length; s++) {
    wb.write(
      '<sheet name="${_esc(_sheetName(sheets[s].name))}" sheetId="${s + 1}" r:id="rId${s + 1}"/>',
    );
    wbRels.write(
      '<Relationship Id="rId${s + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet${s + 1}.xml"/>',
    );
  }
  wb.write('</sheets><definedNames>');
  for (var s = 0; s < sheets.length; s++) {
    final sh = sheets[s];
    if (sh.headers.isEmpty) continue;
    final last = _colName(sh.headers.length - 1);
    wb.write(
      '<definedName name="_xlnm._FilterDatabase" localSheetId="$s" hidden="1">'
      "'${_esc(_sheetName(sh.name)).replaceAll("'", "''")}'!\$A\$1:\$$last\$${sh.rows.length + 1}"
      '</definedName>',
    );
  }
  wb.write('</definedNames></workbook>');
  wbRels.write(
    '<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
    'Target="styles.xml"/></Relationships>',
  );
  put('xl/workbook.xml', wb.toString());
  put('xl/_rels/workbook.xml.rels', wbRels.toString());

  // สไตล์: 0 = ปกติ, 1 = หัวตาราง (ตัวหนา ขาว พื้นน้ำเงิน), 2 = ข้อมูล (ตัดบรรทัด ชิดบน)
  put(
    'xl/styles.xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="2">'
        '<font><sz val="11"/><name val="Tahoma"/><family val="2"/></font>'
        '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Tahoma"/><family val="2"/></font>'
        '</fonts>'
        '<fills count="3">'
        '<fill><patternFill patternType="none"/></fill>'
        '<fill><patternFill patternType="gray125"/></fill>'
        '<fill><patternFill patternType="solid"><fgColor rgb="FF123C8C"/><bgColor indexed="64"/></patternFill></fill>'
        '</fills>'
        '<borders count="2">'
        '<border><left/><right/><top/><bottom/><diagonal/></border>'
        '<border><left style="thin"><color rgb="FFD9E2F2"/></left><right style="thin"><color rgb="FFD9E2F2"/></right>'
        '<top style="thin"><color rgb="FFD9E2F2"/></top><bottom style="thin"><color rgb="FFD9E2F2"/></bottom><diagonal/></border>'
        '</borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="3">'
        '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
        '<alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
        '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1">'
        '<alignment vertical="top" wrapText="1"/></xf>'
        '</cellXfs>'
        '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
        '</styleSheet>',
  );

  put(
    '_rels/.rels',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="xl/workbook.xml"/></Relationships>',
  );

  final ct = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Default Extension="png" ContentType="image/png"/>'
      '<Override PartName="/xl/workbook.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/styles.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>',
    );
  for (var s = 0; s < sheets.length; s++) {
    ct.write(
      '<Override PartName="/xl/worksheets/sheet${s + 1}.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
    );
    if (sheetHasDrawing[s]) {
      ct.write(
        '<Override PartName="/xl/drawings/drawing${s + 1}.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>',
      );
    }
  }
  ct.write('</Types>');
  put('[Content_Types].xml', ct.toString());

  final archive = Archive();
  // [Content_Types].xml ควรอยู่ไฟล์แรก
  for (final path in [
    '[Content_Types].xml',
    ...files.keys.where((k) => k != '[Content_Types].xml'),
  ]) {
    final data = files[path]!;
    archive.addFile(ArchiveFile(path, data.length, data));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _cell(int col, int row, Object value, {int style = 0}) {
  final ref = '${_colName(col)}${row + 1}';
  if (value is num) {
    return '<c r="$ref" s="$style"><v>$value</v></c>';
  }
  return '<c r="$ref" s="$style" t="inlineStr"><is><t xml:space="preserve">'
      '${_esc(value.toString())}</t></is></c>';
}

/// 0 → A, 25 → Z, 26 → AA
String _colName(int index) {
  var n = index + 1;
  var s = '';
  while (n > 0) {
    final m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

/// ชื่อชีต: ห้าม : \ / ? * [ ] และยาวไม่เกิน 31 ตัว
String _sheetName(String name) {
  final clean = name.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').trim();
  return clean.length > 31 ? clean.substring(0, 31) : clean;
}

String _esc(String s) => s
    // ตัดอักขระควบคุมที่ XML ไม่รองรับ
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

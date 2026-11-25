import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../data/thai_address.dart';
import '../data/thai_provinces.dart';
import '../models/project.dart';
import '../services/project_store.dart';
import '../theme/app_colors.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/map_pin_picker.dart';
import '../widgets/panel.dart';
import '../widgets/thai_date_picker.dart';

/// หน้าเพิ่มโครงการ (เวอร์ชันเว็บ)
///
/// เนื้อหาและขั้นตอนเหมือนหน้าเพิ่มโครงการในแอป HomeConnect (กรอกทีละขั้น 5 ขั้น
/// มีแถบขั้นตอนด้านบน) แต่จัดแบบเว็บ: ช่องกรอกเรียงหลายคอลัมน์ในการ์ดกว้าง
class AddProjectPage extends StatefulWidget {
  const AddProjectPage({
    super.key,
    required this.username,
    required this.onLogout,
    this.onMenu,
    this.onDone,
    this.onSaved,
    this.editing,
    this.initialStep = 0,
  });

  /// โครงการเดิมที่จะแก้ไข (null = เพิ่มโครงการใหม่)
  final NewProject? editing;

  /// เรียกหลังบันทึกสำเร็จ (หน้าแม่พาไปหน้าจัดการโครงการ)
  final VoidCallback? onSaved;

  /// ขั้นที่เปิดมาเจอ (ปกติ 0 — ใช้ในเทสต์/พรีวิว)
  final int initialStep;

  final String username;
  final VoidCallback onLogout;
  final VoidCallback? onMenu;

  /// เรียกเมื่อกดล้างฟอร์ม/ยกเลิกการแก้ไข (หน้าแม่ใช้รีเซ็ตฟอร์ม)
  final VoidCallback? onDone;

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  static const _sections = [
    (
      Icons.info_outline_rounded,
      'ข้อมูลทั่วไป',
      'ชื่อ ประเภท ที่ตั้ง ยูนิต และสิ่งอำนวยความสะดวก',
    ),
    (Icons.photo_library_outlined, 'รูปภาพ', 'รูปโครงการ สูงสุด 10 รูป'),
    (
      Icons.payments_outlined,
      'ราคาและค่าใช้จ่าย',
      'ราคาขาย เงินจอง เงินดาวน์ และค่าใช้จ่ายอื่น',
    ),
    (
      Icons.percent_rounded,
      'ค่าคอมมิชชั่น',
      'อัตราค่าคอม เงื่อนไข และสถานะโครงการ',
    ),
    (
      Icons.contact_phone_outlined,
      'ติดต่อสอบถาม',
      'ผู้ติดต่อสำหรับลูกค้าที่สนใจ',
    ),
  ];

  static const _facilityOptions = [
    'สระว่ายน้ำ',
    'ฟิตเนส',
    'สวนส่วนกลาง',
    'รปภ. 24 ชม.',
    'ที่จอดรถ',
    'คลับเฮาส์',
    'ใกล้รถไฟฟ้า',
    'สนามเด็กเล่น',
  ];
  static const _roomTypes = [
    'สตูดิโอ',
    '1 ห้องนอน',
    '2 ห้องนอน',
    '3 ห้องนอน',
    'ดูเพล็กซ์',
    'เพนท์เฮาส์',
    'บ้าน / ทาวน์โฮม',
  ];
  static const _roomSizes = ['เล็ก (S)', 'กลาง (M)', 'ใหญ่ (L)', 'พิเศษ (XL)'];
  static const _directions = [
    'เหนือ',
    'ใต้',
    'ตะวันออก',
    'ตะวันตก',
    'ตะวันออกเฉียงเหนือ',
    'ตะวันออกเฉียงใต้',
    'ตะวันตกเฉียงเหนือ',
    'ตะวันตกเฉียงใต้',
  ];
  static const _commonUnits = ['บาท/ตร.ม./เดือน', 'บาท/เดือน', 'บาท/ปี'];
  static const _downPercents = [5, 10, 15, 20, 25];
  static const _commissionBases = ['ราคาขาย (สุทธิ)', 'ราคาหน้าสัญญา'];
  static const _maxImages = 10;
  static const _maxImageBytes = 5 * 1024 * 1024;

  final _formKeys = List.generate(5, (_) => GlobalKey<FormState>());
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  bool _saving = false;
  late int _step = widget.initialStep;
  // ขั้นไกลสุดที่เคยไปถึง (โหมดแก้ไข: ข้อมูลครบแล้ว กดไปขั้นไหนก็ได้)
  late int _maxReached = widget.editing != null ? 4 : widget.initialStep;
  bool get _isEdit => widget.editing != null;

  // 1. ข้อมูลทั่วไป
  final _nameCtrl = TextEditingController();
  final _developerCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _subdistrictCtrl = TextEditingController();
  final _customFacilityCtrl = TextEditingController();
  String? _type;
  // มีค่าเมื่อเลือก/พิมพ์ตรงกับรายการเท่านั้น
  String? _province;
  String? _district;
  String? _subdistrict;
  ThaiAddress? _addr; // ข้อมูลอำเภอ/ตำบล (โหลดจาก assets)
  LatLng? _pin;
  final Set<String> _facilities = {};
  final List<String> _customFacilities = [];
  final List<_UnitForm> _units = [];

  // 2. รูปภาพ
  final List<Uint8List> _images = [];

  // 3. ราคา
  final _startPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();
  final _contractPriceCtrl = TextEditingController();
  final _reservationCtrl = TextEditingController();
  final _contractFeeCtrl = TextEditingController();
  final _commonCtrl = TextEditingController();
  final _serviceCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  final _priceNoteCtrl = TextEditingController();
  int _downPercent = 10;
  bool _commonOn = false;
  String _commonUnit = _commonUnits.first;
  bool _serviceOn = false;
  bool _otherOn = false;

  // 4. ค่าคอมมิชชั่น
  final _percentCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();
  final _saleStartCtrl = TextEditingController();
  final _promoEndCtrl = TextEditingController();
  String _commissionBase = _commissionBases.first;
  String _status = 'กำลังก่อสร้าง';
  DateTime? _saleStart;
  DateTime? _promoEnd;

  // 5. ติดต่อ
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();

  List<TextEditingController> get _allControllers => [
    _nameCtrl,
    _developerCtrl,
    _addressCtrl,
    _provinceCtrl,
    _districtCtrl,
    _subdistrictCtrl,
    _customFacilityCtrl,
    _startPriceCtrl,
    _maxPriceCtrl,
    _contractPriceCtrl,
    _reservationCtrl,
    _contractFeeCtrl,
    _commonCtrl,
    _serviceCtrl,
    _otherCtrl,
    _priceNoteCtrl,
    _percentCtrl,
    _amountCtrl,
    _termsCtrl,
    _saleStartCtrl,
    _promoEndCtrl,
    _contactNameCtrl,
    _contactPhoneCtrl,
    _contactEmailCtrl,
  ];

  @override
  void initState() {
    super.initState();
    ThaiAddress.load().then((a) {
      if (mounted) setState(() => _addr = a);
    });
    final e = widget.editing;
    if (e != null) _fillFrom(e);
  }

  /// โหมดแก้ไข: ใส่ข้อมูลเดิมลงทุกช่อง
  void _fillFrom(NewProject e) {
    String money(double? v) => v == null ? '' : _fmtMoney(v);
    String plain(double v) => v % 1 == 0 ? v.toInt().toString() : '$v';

    // 1. ข้อมูลทั่วไป
    _nameCtrl.text = e.name;
    _developerCtrl.text = e.developer;
    _addressCtrl.text = e.address;
    _type = kProjectTypes.contains(e.type) ? e.type : null;
    if (kThaiProvinces.contains(e.province)) {
      _province = e.province;
      _provinceCtrl.text = e.province;
    }
    if (e.district.isNotEmpty) {
      _district = e.district;
      _districtCtrl.text = e.district;
    }
    if (e.subDistrict.isNotEmpty) {
      _subdistrict = e.subDistrict;
      _subdistrictCtrl.text = e.subDistrict;
    }
    if (e.latitude != null && e.longitude != null) {
      _pin = LatLng(e.latitude!, e.longitude!);
    }
    for (final f in e.facilities) {
      _facilityOptions.contains(f)
          ? _facilities.add(f)
          : _customFacilities.add(f);
    }
    for (final u in e.units) {
      _units.add(
        _UnitForm()
          ..unitNo.text = u.unitNo
          ..area.text = u.area == null ? '' : plain(u.area!)
          ..floor.text = u.floor
          ..roomType = _roomTypes.contains(u.roomType) ? u.roomType : null
          ..bedrooms = u.bedrooms
          ..bathrooms = u.bathrooms
          ..size = _roomSizes.contains(u.size) ? u.size : null
          ..direction = _directions.contains(u.direction) ? u.direction : null,
      );
    }

    // 2. รูปภาพ
    _images.addAll(e.imageBytes);

    // 3. ราคา
    _startPriceCtrl.text = money(e.startPrice);
    _maxPriceCtrl.text = money(e.maxPrice);
    _contractPriceCtrl.text = money(e.contractPrice);
    _reservationCtrl.text = money(e.reservationFee);
    _contractFeeCtrl.text = money(e.contractFee);
    _downPercent = _downPercents.contains(e.downPaymentPercent)
        ? e.downPaymentPercent
        : 10;
    _commonOn = e.commonFee != null;
    _commonCtrl.text = money(e.commonFee);
    _commonUnit = _commonUnits.contains(e.commonFeeUnit)
        ? e.commonFeeUnit!
        : _commonUnits.first;
    _serviceOn = e.serviceFee != null;
    _serviceCtrl.text = money(e.serviceFee);
    _otherOn = (e.otherCostNote ?? '').isNotEmpty;
    _otherCtrl.text = e.otherCostNote ?? '';
    _priceNoteCtrl.text = e.priceNote;

    // 4. ค่าคอมมิชชั่น
    _percentCtrl.text = plain(e.commissionPercent);
    _commissionBase = _commissionBases.contains(e.commissionBase)
        ? e.commissionBase
        : _commissionBases.first;
    _termsCtrl.text = e.commissionTerms;
    _saleStart = e.saleStart;
    _promoEnd = e.promoEnd;
    _saleStartCtrl.text = e.saleStart == null ? '' : _fmtDate(e.saleStart!);
    _promoEndCtrl.text = e.promoEnd == null ? '' : _fmtDate(e.promoEnd!);
    _status = kProjectStatuses.contains(e.status) ? e.status : 'เปิดขาย';
    _recalcCommission();

    // 5. ติดต่อ
    _contactNameCtrl.text = e.contactName;
    _contactPhoneCtrl.text = e.contactPhone;
    _contactEmailCtrl.text = e.contactEmail;
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in _allControllers) {
      c.dispose();
    }
    for (final u in _units) {
      u.dispose();
    }
    super.dispose();
  }

  // ------------------------------- helpers ---------------------------------

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', ''));

  String _fmtMoney(double v) => v.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  /// วันที่แบบ พ.ศ. เช่น 01/05/2569
  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year + 543}';

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          width: 460,
          backgroundColor: error ? const Color(0xFFC62828) : AppColors.navy,
        ),
      );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'กรุณากรอกข้อมูล' : null;

  void _recalcCommission() {
    final pct = double.tryParse(_percentCtrl.text);
    final base = _commissionBase == 'ราคาหน้าสัญญา'
        ? _num(_contractPriceCtrl)
        : _num(_startPriceCtrl);
    _amountCtrl.text = (pct == null || base == null)
        ? ''
        : _fmtMoney(base * pct / 100);
  }

  /// เรียกเมื่อช่องใดในฟอร์มเปลี่ยน: อัปเดตค่าคอมและแถบความคืบหน้า
  void _onFormChanged() => setState(_recalcCommission);

  bool _sectionComplete(int i) => switch (i) {
    0 =>
      _nameCtrl.text.trim().isNotEmpty &&
          _type != null &&
          _developerCtrl.text.trim().isNotEmpty &&
          _province != null &&
          _district != null &&
          _subdistrict != null &&
          _addressCtrl.text.trim().isNotEmpty &&
          _pin != null,
    1 => _images.isNotEmpty,
    2 => (_num(_startPriceCtrl) ?? 0) > 0,
    3 => double.tryParse(_percentCtrl.text) != null,
    _ =>
      _contactNameCtrl.text.trim().isNotEmpty &&
          _contactPhoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '').length >= 9,
  };

  void _scrollTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// ตรวจข้อมูลของขั้นปัจจุบัน (เหมือนกด "ถัดไป" ในแอป)
  bool _validateStep() {
    final form = _formKeys[_step].currentState;
    if (form != null && !form.validate()) {
      _snack('กรุณากรอกข้อมูลที่จำเป็นให้ครบ', error: true);
      return false;
    }
    if (_step == 0 && _pin == null) {
      _snack('กรุณาปักหมุดตำแหน่งโครงการบนแผนที่', error: true);
      return false;
    }
    if (_step == 1 && _images.isEmpty) {
      _snack('กรุณาอัปโหลดรูปภาพอย่างน้อย 1 รูป', error: true);
      return false;
    }
    return true;
  }

  /// ไปขั้นอื่น: ถอยหลังได้เสมอ, ไปข้างหน้าต้องผ่านการตรวจขั้นปัจจุบันก่อน
  void _goTo(int target) {
    if (target == _step || _saving) return;
    if (target > _step && !_validateStep()) return;
    _addCustomFacility(); // พิมพ์ค้างไว้แต่ลืมกดเพิ่ม ก็ยังเก็บให้
    setState(() {
      _step = target;
      if (target > _maxReached) _maxReached = target;
    });
    _scrollTop();
  }

  // ------------------------------- actions ---------------------------------

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 75,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked.isEmpty) return;

    var tooBig = 0;
    var overLimit = 0;
    for (final f in picked) {
      if (_images.length >= _maxImages) {
        overLimit++;
        continue;
      }
      final bytes = await f.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        tooBig++;
        continue;
      }
      _images.add(bytes);
    }
    if (!mounted) return;
    setState(() {});
    if (tooBig > 0) _snack('ข้ามรูปที่ขนาดเกิน 5MB จำนวน $tooBig รูป');
    if (overLimit > 0) {
      _snack('เลือกได้สูงสุด $_maxImages รูป ข้ามไป $overLimit รูป');
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final d = await showThaiDatePicker(
      context: context,
      title: isStart ? 'วันที่เริ่มขาย' : 'วันสิ้นสุดโปรโมชั่น',
      initialDate: (isStart ? _saleStart : _promoEnd) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 15),
    );
    if (d == null) return;
    setState(() {
      if (isStart) {
        _saleStart = d;
        _saleStartCtrl.text = _fmtDate(d);
      } else {
        _promoEnd = d;
        _promoEndCtrl.text = _fmtDate(d);
      }
    });
  }

  /// พิมพ์หลายอย่างคั่นด้วยจุลภาคได้ เช่น "ซาวน่า, Co-working"
  void _addCustomFacility() {
    final parts = _customFacilityCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    if (parts.isEmpty) return;
    setState(() {
      for (final t in parts) {
        if (_facilityOptions.contains(t)) {
          _facilities.add(t);
        } else if (!_customFacilities.contains(t)) {
          _customFacilities.add(t);
        }
      }
      _customFacilityCtrl.clear();
    });
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isEdit ? 'ยกเลิกการแก้ไข?' : 'ล้างข้อมูลในฟอร์ม?'),
        content: Text(
          _isEdit
              ? 'สิ่งที่แก้ไขไว้จะไม่ถูกบันทึก'
              : 'ข้อมูลที่กรอกไว้ทั้งหมดจะหายไป',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isEdit ? 'ยกเลิกการแก้ไข' : 'ล้างฟอร์ม'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDone?.call();
  }

  Future<void> _save() async {
    if (!_validateStep()) return;
    // ขั้นอื่นอาจถูกแก้ทีหลัง (ย้อนกลับไปลบข้อมูล / โหมดแก้ไขบันทึกจากขั้นไหนก็ได้)
    for (var i = 0; i < _sections.length; i++) {
      if (i != _step && !_sectionComplete(i)) {
        setState(() => _step = i);
        _scrollTop();
        _snack('ขั้น "${_sections[i].$2}" ยังกรอกไม่ครบ', error: true);
        return;
      }
    }

    setState(() => _saving = true);
    final project = NewProject(
      name: _nameCtrl.text.trim(),
      type: _type!,
      developer: _developerCtrl.text.trim(),
      province: _province!,
      district: _district!,
      subDistrict: _subdistrict!,
      address: _addressCtrl.text.trim(),
      imageBytes: List.of(_images),
      facilities: [
        ..._facilityOptions.where(_facilities.contains),
        ..._customFacilities,
      ],
      units: _units.map((u) => u.toUnit()).where((u) => !u.isEmpty).toList(),
      latitude: _pin!.latitude,
      longitude: _pin!.longitude,
      startPrice: _num(_startPriceCtrl)!,
      maxPrice: _num(_maxPriceCtrl),
      contractPrice: _num(_contractPriceCtrl),
      reservationFee: _num(_reservationCtrl),
      contractFee: _num(_contractFeeCtrl),
      downPaymentPercent: _downPercent,
      commonFee: _commonOn ? _num(_commonCtrl) : null,
      commonFeeUnit: _commonOn ? _commonUnit : null,
      serviceFee: _serviceOn ? _num(_serviceCtrl) : null,
      otherCostNote: _otherOn ? _otherCtrl.text.trim() : null,
      priceNote: _priceNoteCtrl.text.trim(),
      commissionPercent: double.parse(_percentCtrl.text),
      commissionAmount: _num(_amountCtrl),
      commissionBase: _commissionBase,
      commissionTerms: _termsCtrl.text.trim(),
      saleStart: _saleStart,
      promoEnd: _promoEnd,
      status: _status,
      contactName: _contactNameCtrl.text.trim(),
      contactPhone: _contactPhoneCtrl.text.trim(),
      contactEmail: _contactEmailCtrl.text.trim(),
      // ส่วนลดไม่มีช่องในฟอร์ม: ตอนแก้ไขให้คงค่าเดิมไว้
      discountType: widget.editing?.discountType ?? '',
      discountValue: widget.editing?.discountValue,
      discountUntil: widget.editing?.discountUntil ?? '',
    );

    final old = widget.editing;
    final String? warning;
    try {
      warning = old == null
          ? await ProjectStore.instance.add(project)
          : await ProjectStore.instance.update(old, project);
    } on ProjectSaveException catch (e) {
      // บันทึกขึ้นเซิร์ฟเวอร์ไม่สำเร็จ: อยู่หน้าฟอร์มต่อ ข้อมูลที่กรอกไม่หาย
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.message);
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(
      warning ??
          (old == null
              ? 'บันทึกโครงการ "${project.name}" เรียบร้อยแล้ว'
              : 'บันทึกการแก้ไข "${project.name}" เรียบร้อยแล้ว'),
    );
    widget.onSaved?.call();
  }

  // --------------------------------- layout --------------------------------

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          DashboardHeader(
            title: _isEdit ? 'แก้ไขโครงการ' : 'เพิ่มโครงการใหม่',
            subtitle: _isEdit
                ? 'แก้ไขได้ทุกขั้น กดวงกลมด้านบนเพื่อข้ามไปขั้นที่ต้องการ'
                : 'กรอกข้อมูลทีละขั้น แล้วกดบันทึกในขั้นสุดท้าย',
            username: widget.username,
            onMenu: widget.onMenu,
            onLogout: widget.onLogout,
            notificationCount: 3,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Panel(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    child: _stepper(),
                  ),
                  const SizedBox(height: 20),
                  _section(_step),
                  const SizedBox(height: 20),
                  _actions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// แถบขั้นตอน 1-5 (แบบเดียวกับในแอป) กดวงกลมเพื่อย้อนไปขั้นที่เคยกรอกแล้วได้
  Widget _stepper() {
    const circle = 46.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        // เว้นที่ให้เส้นเชื่อมอย่างน้อย 20px ต่อช่อง จะได้เห็นเส้นบนจอแคบด้วย
        final stepW =
            ((constraints.maxWidth - 20.0 * (_sections.length - 1)) /
                    _sections.length)
                .clamp(56.0, 130.0);
        final children = <Widget>[];
        for (var i = 0; i < _sections.length; i++) {
          final (_, title, _) = _sections[i];
          final current = i == _step;
          final done =
              !current &&
              (i < _step || (i <= _maxReached && _sectionComplete(i)));
          final reachable = !current && (i <= _maxReached || i == _step + 1);

          children.add(
            MouseRegion(
              cursor: reachable
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: GestureDetector(
                onTap: reachable ? () => _goTo(i) : null,
                child: SizedBox(
                  width: stepW,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: circle,
                        height: circle,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: current
                              ? AppColors.blue
                              : done
                              ? AppColors.skyLight
                              : Colors.white,
                          border: Border.all(
                            color: (current || done)
                                ? AppColors.blue
                                : AppColors.border,
                            width: 2,
                          ),
                          boxShadow: current
                              ? [
                                  BoxShadow(
                                    color: AppColors.blue.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: done
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.blue,
                                size: 24,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: current
                                      ? Colors.white
                                      : AppColors.hint,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          color: current ? AppColors.blue : AppColors.hint,
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: current
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          if (i < _sections.length - 1) {
            children.add(
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: circle / 2 - 1.5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    decoration: BoxDecoration(
                      color: i < _step ? AppColors.blue : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            );
          }
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  Widget _section(int i) {
    final (icon, title, subtitle) = _sections[i];
    return Panel(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: Form(
        key: _formKeys[i],
        onChanged: _onFormChanged,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.skyLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.blue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.hint,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'ขั้นตอนที่ ${i + 1} จาก ${_sections.length}',
                  style: const TextStyle(color: AppColors.hint, fontSize: 13),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1, color: Color(0xFFE3EAF6)),
            ),
            switch (i) {
              0 => _generalSection(),
              1 => _imagesSection(),
              2 => _priceSection(),
              3 => _commissionSection(),
              _ => _contactSection(),
            },
          ],
        ),
      ),
    );
  }

  /// ปุ่มด้านล่าง: ย้อนกลับ | ล้างฟอร์ม · ถัดไป/บันทึก
  Widget _actions() {
    final isLast = _step == _sections.length - 1;
    final resetLabel = _isEdit ? 'ยกเลิกการแก้ไข' : 'ล้างฟอร์ม';
    final resetIcon = _isEdit ? Icons.close_rounded : Icons.restart_alt_rounded;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        );
        return Row(
          children: [
            if (_step > 0)
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _goTo(_step - 1),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                label: const Text('ย้อนกลับ'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 50),
                  foregroundColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.primary),
                  shape: shape,
                ),
              ),
            const Spacer(),
            if (compact)
              IconButton(
                tooltip: resetLabel,
                onPressed: _saving ? null : _confirmReset,
                icon: Icon(resetIcon),
              )
            else
              TextButton.icon(
                onPressed: _saving ? null : _confirmReset,
                icon: Icon(resetIcon, size: 20),
                label: Text(resetLabel),
                style: TextButton.styleFrom(foregroundColor: AppColors.hint),
              ),
            const SizedBox(width: 12),
            // โหมดแก้ไข: บันทึกได้จากทุกขั้น
            if (_isEdit && !isLast) ...[
              OutlinedButton(
                onPressed: _saving ? null : () => _goTo(_step + 1),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(compact ? 90 : 120, 50),
                  foregroundColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.primary),
                  shape: shape,
                ),
                child: const Text('ถัดไป'),
              ),
              const SizedBox(width: 12),
            ],
            SizedBox(
              width: compact ? 160 : 220,
              child: isLast || _isEdit
                  ? _saveButton()
                  : FilledButton(
                      onPressed: () => _goTo(_step + 1),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: AppColors.primary,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: shape,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('ถัดไป'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _saveButton() {
    return FilledButton.icon(
      onPressed: _saving ? null : _save,
      icon: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_rounded),
      label: Text(_isEdit ? 'บันทึกการแก้ไข' : 'บันทึกโครงการ'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ------------------------------ form pieces ------------------------------

  InputDecoration _dec({
    String? hint,
    String? suffix,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
      suffixText: suffix,
      suffixStyle: const TextStyle(color: AppColors.hint, fontSize: 13),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: readOnly ? const Color(0xFFF4F8FC) : Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      disabledBorder: border(const Color(0xFFE3EAF6)),
      focusedBorder: border(AppColors.blue, 1.6),
      errorBorder: border(Colors.red.shade300),
      focusedErrorBorder: border(Colors.red.shade400, 1.6),
    );
  }

  Widget _field(
    String label,
    Widget input, {
    bool required = false,
    String? help,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(
            TextSpan(
              text: label,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
        input,
        if (help != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              help,
              style: const TextStyle(color: AppColors.hint, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _text(
    TextEditingController c, {
    String? hint,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? suffix,
    bool enabled = true,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? prefixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: c,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      // กด Enter ในช่องบรรทัดเดียว = ไปช่องถัดไป (ช่องหลายบรรทัด = ขึ้นบรรทัดใหม่)
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      onFieldSubmitted: onSubmitted,
      keyboardType: keyboard,
      inputFormatters: formatters,
      validator: validator,
      decoration: _dec(
        hint: hint,
        suffix: suffix,
        prefixIcon: prefixIcon,
        readOnly: readOnly && onTap == null,
      ),
    );
  }

  Widget _money(
    TextEditingController c, {
    String suffix = 'บาท',
    String? hint,
    String? Function(String?)? validator,
    bool enabled = true,
  }) => _text(
    c,
    hint: hint ?? '0',
    suffix: suffix,
    enabled: enabled,
    validator: validator,
    keyboard: TextInputType.number,
    formatters: [_ThousandsFormatter()],
  );

  Widget _dropdown<T>({
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String? hint,
    String? Function(T?)? validator,
    String Function(T)? labelOf,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      hint: hint == null
          ? null
          : Text(
              hint,
              style: const TextStyle(color: AppColors.hint, fontSize: 14),
            ),
      items: [
        for (final e in items)
          DropdownMenuItem(
            value: e,
            child: Text(
              labelOf?.call(e) ?? '$e',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: enabled ? onChanged : null,
      validator: validator,
      decoration: _dec(),
      borderRadius: BorderRadius.circular(10),
      dropdownColor: Colors.white,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.navy,
      ),
    );
  }

  Widget _subheading(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  // ------------------------- 1. ข้อมูลทั่วไป -------------------------------

  Widget _generalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Grid(
          maxCols: 3,
          children: [
            _field(
              'ชื่อโครงการ',
              _text(
                _nameCtrl,
                hint: 'เช่น Life Sukhumvit 62',
                validator: _required,
              ),
              required: true,
            ),
            _field(
              'ประเภทอสังหาริมทรัพย์',
              _dropdown<String>(
                value: _type,
                items: kProjectTypes,
                hint: 'เลือกประเภท',
                onChanged: (v) => setState(() => _type = v),
                validator: (v) => v == null ? 'กรุณาเลือกประเภท' : null,
              ),
              required: true,
            ),
            _field(
              'บริษัทผู้พัฒนา',
              _text(
                _developerCtrl,
                hint: 'เช่น AP (Thailand)',
                validator: _required,
              ),
              required: true,
            ),
            _field(
              'จังหวัด',
              _AutoField(
                controller: _provinceCtrl,
                options: () => kThaiProvinces,
                decoration: _dec(
                  hint: 'พิมพ์หรือเลือกจังหวัด',
                  suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                onChanged: (v) {
                  final t = v.trim();
                  final next = kThaiProvinces.contains(t) ? t : null;
                  if (next != _province) {
                    setState(() {
                      _province = next;
                      // เปลี่ยนจังหวัด: ล้างอำเภอ/ตำบลเดิม
                      _district = null;
                      _subdistrict = null;
                      _districtCtrl.clear();
                      _subdistrictCtrl.clear();
                    });
                  }
                },
                validator: (_) => _province == null
                    ? 'กรุณาเลือกจังหวัดจากรายการ (77 จังหวัด)'
                    : null,
              ),
              required: true,
            ),
            _field(
              'เขต/อำเภอ',
              _AutoField(
                controller: _districtCtrl,
                enabled: _province != null,
                options: () => _addr?.districts(_province) ?? const [],
                decoration: _dec(
                  hint: _province == null
                      ? 'เลือกจังหวัดก่อน'
                      : 'พิมพ์หรือเลือกเขต/อำเภอ',
                  suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                onChanged: (v) {
                  final t = v.trim();
                  final list = _addr?.districts(_province) ?? const [];
                  final next = list.contains(t) ? t : null;
                  if (next != _district) {
                    setState(() {
                      _district = next;
                      _subdistrict = null;
                      _subdistrictCtrl.clear();
                    });
                  }
                },
                validator: (_) =>
                    _district == null ? 'กรุณาเลือกเขต/อำเภอจากรายการ' : null,
              ),
              required: true,
            ),
            _field(
              'แขวง/ตำบล',
              _AutoField(
                controller: _subdistrictCtrl,
                enabled: _district != null,
                options: () =>
                    _addr?.subdistricts(_province, _district) ?? const [],
                decoration: _dec(
                  hint: _district == null
                      ? 'เลือกเขต/อำเภอก่อน'
                      : 'พิมพ์หรือเลือกแขวง/ตำบล',
                  suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                onChanged: (v) {
                  final t = v.trim();
                  final list =
                      _addr?.subdistricts(_province, _district) ?? const [];
                  final next = list.contains(t) ? t : null;
                  if (next != _subdistrict) {
                    setState(() => _subdistrict = next);
                  }
                },
                validator: (_) => _subdistrict == null
                    ? 'กรุณาเลือกแขวง/ตำบลจากรายการ'
                    : null,
              ),
              required: true,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _field(
          'ที่อยู่โครงการ',
          _text(
            _addressCtrl,
            hint: 'เช่น ถนนสุขุมวิท 62 แขวงบางจาก เขตพระโขนง',
            maxLines: 2,
            validator: _required,
          ),
          required: true,
        ),
        const SizedBox(height: 18),
        _field(
          'ตำแหน่งบนแผนที่',
          MapPinPicker(value: _pin, onChanged: (p) => setState(() => _pin = p)),
          required: true,
        ),
        const SizedBox(height: 24),
        _unitsBlock(),
        const SizedBox(height: 8),
        _subheading('สิ่งอำนวยความสะดวก'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final f in _facilityOptions)
              FilterChip(
                label: Text(f),
                selected: _facilities.contains(f),
                showCheckmark: true,
                checkmarkColor: AppColors.blue,
                selectedColor: AppColors.skyLight,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: _facilities.contains(f)
                      ? AppColors.blue
                      : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (v) => setState(
                  () => v ? _facilities.add(f) : _facilities.remove(f),
                ),
              ),
            for (final f in _customFacilities)
              InputChip(
                label: Text(f),
                selected: true,
                showCheckmark: true,
                checkmarkColor: AppColors.blue,
                selectedColor: AppColors.skyLight,
                side: const BorderSide(color: AppColors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (_) {},
                deleteButtonTooltipMessage: 'ลบ',
                onDeleted: () => setState(() => _customFacilities.remove(f)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: TextField(
              controller: _customFacilityCtrl,
              onSubmitted: (_) => _addCustomFacility(),
              decoration: _dec(
                hint: 'เพิ่มอื่น ๆ เช่น ซาวน่า, Co-working (คั่นด้วย ,)',
                suffixIcon: IconButton(
                  tooltip: 'เพิ่ม',
                  icon: const Icon(
                    Icons.add_circle_rounded,
                    color: AppColors.blue,
                  ),
                  onPressed: _addCustomFacility,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _unitsBlock() {
    final addBtn = OutlinedButton.icon(
      onPressed: () => setState(() => _units.add(_UnitForm())),
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text('เพิ่มยูนิต'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue,
        side: const BorderSide(color: AppColors.blue),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ข้อมูลยูนิต',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'ไม่บังคับ — เพิ่มได้หลายยูนิต',
                    style: TextStyle(color: AppColors.hint, fontSize: 12),
                  ),
                ],
              ),
            ),
            addBtn,
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _units.length; i++) _unitCard(i),
      ],
    );
  }

  Widget _unitCard(int i) {
    final u = _units[i];
    return Container(
      key: ObjectKey(u),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
            decoration: const BoxDecoration(
              color: AppColors.skyLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.door_front_door_outlined,
                  color: AppColors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ยูนิต ${i + 1}',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'ลบยูนิต',
                  onPressed: () => setState(() => _units.removeAt(i).dispose()),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.hint,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _Grid(
              maxCols: 4,
              minItemWidth: 190,
              children: [
                _field(
                  'เลขที่ยูนิต / ห้อง',
                  _text(u.unitNo, hint: 'เช่น A1205'),
                ),
                _field(
                  'ประเภทห้อง',
                  _dropdown<String>(
                    value: u.roomType,
                    items: _roomTypes,
                    hint: 'เลือกประเภท',
                    onChanged: (v) => setState(() => u.roomType = v),
                  ),
                ),
                _field(
                  'ห้องนอน',
                  _dropdown<int>(
                    value: u.bedrooms,
                    items: const [1, 2, 3, 4, 5, 6],
                    hint: 'จำนวน',
                    onChanged: (v) => setState(() => u.bedrooms = v),
                  ),
                ),
                _field(
                  'ห้องน้ำ',
                  _dropdown<int>(
                    value: u.bathrooms,
                    items: const [1, 2, 3, 4, 5],
                    hint: 'จำนวน',
                    onChanged: (v) => setState(() => u.bathrooms = v),
                  ),
                ),
                _field(
                  'พื้นที่ใช้สอย',
                  _text(
                    u.area,
                    hint: 'เช่น 35.5',
                    suffix: 'ตร.ม.',
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    formatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                  ),
                ),
                _field('ชั้น', _text(u.floor, hint: 'เช่น 12')),
                _field(
                  'ขนาดห้อง',
                  _dropdown<String>(
                    value: u.size,
                    items: _roomSizes,
                    hint: 'เลือก (ถ้ามี)',
                    onChanged: (v) => setState(() => u.size = v),
                  ),
                ),
                _field(
                  'ทิศของห้อง',
                  _dropdown<String>(
                    value: u.direction,
                    items: _directions,
                    hint: 'เลือก (ถ้ามี)',
                    onChanged: (v) => setState(() => u.direction = v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------- 2. รูปภาพ ---------------------------------

  Widget _imagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.skyLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _images.length >= _maxImages ? null : _pickImages,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.blue.withValues(alpha: 0.35),
                  width: 1.4,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 44,
                    color: AppColors.blue,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'คลิกเพื่อเลือกรูปภาพจากเครื่อง',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'JPG, PNG ไม่เกิน 5MB ต่อรูป · เลือกได้หลายรูปพร้อมกัน',
                    style: TextStyle(color: AppColors.hint, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [for (var i = 0; i < _images.length; i++) _imageTile(i)],
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'อัปโหลดแล้ว ${_images.length}/$_maxImages รูป · รูปแรกจะเป็นรูปปก (กด ★ เพื่อตั้งรูปอื่นเป็นรูปปก)',
          style: const TextStyle(color: AppColors.hint, fontSize: 12),
        ),
      ],
    );
  }

  Widget _imageTile(int i) {
    Widget roundButton(IconData icon, String tip, VoidCallback onTap) =>
        Tooltip(
          message: tip,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
            ),
          ),
        );

    return SizedBox(
      width: 190,
      height: 140,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_images[i], fit: BoxFit.cover),
          ),
          if (i == 0)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'รูปปก',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: Row(
              children: [
                if (i > 0) ...[
                  roundButton(
                    Icons.star_rounded,
                    'ตั้งเป็นรูปปก',
                    () =>
                        setState(() => _images.insert(0, _images.removeAt(i))),
                  ),
                  const SizedBox(width: 6),
                ],
                roundButton(
                  Icons.close_rounded,
                  'ลบรูป',
                  () => setState(() => _images.removeAt(i)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------- 3. ราคาและค่าใช้จ่าย --------------------------

  Widget _priceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Grid(
          maxCols: 3,
          children: [
            _field(
              'ราคาเริ่มต้น',
              _money(
                _startPriceCtrl,
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', ''));
                  return (n == null || n <= 0) ? 'กรุณากรอกราคา' : null;
                },
              ),
              required: true,
            ),
            _field(
              'ราคาสูงสุด',
              _money(
                _maxPriceCtrl,
                validator: (v) {
                  final max = double.tryParse((v ?? '').replaceAll(',', ''));
                  final min = _num(_startPriceCtrl);
                  return (max != null && min != null && max < min)
                      ? 'ต้องไม่ต่ำกว่าราคาเริ่มต้น'
                      : null;
                },
              ),
            ),
            _field('ราคาหน้าสัญญา', _money(_contractPriceCtrl)),
            _field('เงินจอง', _money(_reservationCtrl)),
            _field('เงินทำสัญญา', _money(_contractFeeCtrl)),
            _field(
              'เงินดาวน์',
              _dropdown<int>(
                value: _downPercent,
                items: _downPercents,
                labelOf: (e) => '$e% ของราคาขาย',
                onChanged: (v) => setState(() => _downPercent = v ?? 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _subheading('ค่าใช้จ่ายเพิ่มเติม'),
        _costRow(
          title: 'ค่าส่วนกลาง',
          on: _commonOn,
          onToggle: (v) => setState(() => _commonOn = v),
          input: Row(
            children: [
              Expanded(
                child: _money(_commonCtrl, suffix: '', enabled: _commonOn),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdown<String>(
                  value: _commonUnit,
                  items: _commonUnits,
                  enabled: _commonOn,
                  onChanged: (v) =>
                      setState(() => _commonUnit = v ?? _commonUnits.first),
                ),
              ),
            ],
          ),
        ),
        _costRow(
          title: 'ค่าบริการอื่น ๆ',
          on: _serviceOn,
          onToggle: (v) => setState(() => _serviceOn = v),
          input: _money(_serviceCtrl, enabled: _serviceOn),
        ),
        _costRow(
          title: 'ค่าใช้จ่ายอื่น (ระบุ)',
          on: _otherOn,
          onToggle: (v) => setState(() => _otherOn = v),
          input: _text(
            _otherCtrl,
            enabled: _otherOn,
            hint: 'เช่น ค่าไฟ, ค่าตอบแทน',
          ),
        ),
        const SizedBox(height: 14),
        _field(
          'โปรโมชั่น / หมายเหตุเกี่ยวกับราคา',
          _text(
            _priceNoteCtrl,
            maxLines: 3,
            hint: 'เช่น ฟรีค่าใช้จ่ายวันโอน, ส่วนลดพิเศษ, เฟอร์นิเจอร์ครบ',
          ),
        ),
      ],
    );
  }

  Widget _costRow({
    required String title,
    required bool on,
    required ValueChanged<bool> onToggle,
    required Widget input,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Row(
          children: [
            Checkbox(
              value: on,
              activeColor: AppColors.blue,
              onChanged: (v) => onToggle(v ?? false),
            ),
            SizedBox(
              width: 150,
              child: InkWell(
                onTap: () => onToggle(!on),
                child: Text(
                  title,
                  style: const TextStyle(color: AppColors.navy, fontSize: 14),
                ),
              ),
            ),
            Expanded(child: input),
          ],
        ),
      ),
    );
  }

  // ---------------------------- 4. ค่าคอมมิชชั่น ----------------------------

  Widget _commissionSection() {
    final dateIcon = const Icon(
      Icons.calendar_today_outlined,
      size: 18,
      color: AppColors.blue,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Grid(
          maxCols: 3,
          children: [
            _field(
              'อัตราค่าคอมมิชชั่น',
              _text(
                _percentCtrl,
                suffix: '%',
                hint: 'เช่น 3',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                formatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null) return 'กรุณากรอกอัตราค่าคอมมิชชั่น';
                  if (n < 0 || n > 100) return 'ต้องอยู่ระหว่าง 0-100';
                  return null;
                },
              ),
              required: true,
            ),
            _field(
              'ค่าคอมมิชชั่น (คำนวณให้อัตโนมัติ)',
              _text(_amountCtrl, readOnly: true, hint: '-', suffix: 'บาท'),
            ),
            _field(
              'ฐานการคำนวณ',
              _dropdown<String>(
                value: _commissionBase,
                items: _commissionBases,
                onChanged: (v) => setState(() {
                  _commissionBase = v ?? _commissionBases.first;
                  _recalcCommission();
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _field(
          'เงื่อนไขการจ่ายค่าคอมมิชชั่น',
          _text(
            _termsCtrl,
            maxLines: 3,
            hint: 'เช่น จ่ายหลังปิดการขาย / แบ่งจ่ายเป็นงวด',
          ),
        ),
        const SizedBox(height: 18),
        _Grid(
          maxCols: 3,
          children: [
            _field(
              'วันที่เริ่มขาย',
              _text(
                _saleStartCtrl,
                readOnly: true,
                hint: 'วว/ดด/ปปปป',
                prefixIcon: dateIcon,
                onTap: () => _pickDate(isStart: true),
              ),
            ),
            _field(
              'วันสิ้นสุดโปรโมชั่น',
              TextFormField(
                controller: _promoEndCtrl,
                readOnly: true,
                onTap: () => _pickDate(isStart: false),
                decoration: _dec(hint: 'วว/ดด/ปปปป', prefixIcon: dateIcon),
                validator: (_) =>
                    (_saleStart != null &&
                        _promoEnd != null &&
                        _promoEnd!.isBefore(_saleStart!))
                    ? 'ต้องไม่ก่อนวันเริ่มขาย'
                    : null,
              ),
            ),
            _field(
              'สถานะโครงการ',
              _dropdown<String>(
                value: _status,
                items: kProjectStatuses,
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------- 5. ติดต่อสอบถาม -----------------------------

  Widget _contactSection() {
    return _Grid(
      maxCols: 3,
      children: [
        _field(
          'ชื่อผู้ติดต่อ',
          _text(
            _contactNameCtrl,
            hint: 'เช่น คุณสมชาย ฝ่ายขาย',
            prefixIcon: const Icon(Icons.person_outline, color: AppColors.blue),
            validator: _required,
          ),
          required: true,
        ),
        _field(
          'เบอร์โทรศัพท์',
          _text(
            _contactPhoneCtrl,
            hint: '081-234-5678',
            keyboard: TextInputType.phone,
            prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.blue),
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\- ]')),
            ],
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              if (digits.isEmpty) return 'กรุณากรอกเบอร์โทรศัพท์';
              if (!RegExp(r'^0\d{8,9}$').hasMatch(digits)) {
                return 'เบอร์โทรศัพท์ไม่ถูกต้อง';
              }
              return null;
            },
          ),
          required: true,
        ),
        _field(
          'อีเมล',
          _text(
            _contactEmailCtrl,
            hint: 'sales@project.co.th',
            keyboard: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.mail_outline, color: AppColors.blue),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return null;
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                  ? null
                  : 'อีเมลไม่ถูกต้อง';
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Small building blocks
// ---------------------------------------------------------------------------

/// วางช่องกรอกเป็นตารางหลายคอลัมน์ตามความกว้างจอ
class _Grid extends StatelessWidget {
  const _Grid({
    required this.children,
    this.maxCols = 3,
    this.minItemWidth = 240,
  });

  final List<Widget> children;
  final int maxCols;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    const gap = 18.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = ((w + gap) / (minItemWidth + gap)).floor().clamp(
          1,
          maxCols,
        );
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: 18,
          children: [
            for (final c in children) SizedBox(width: itemW, child: c),
          ],
        );
      },
    );
  }
}

/// ค่าที่กำลังกรอกของยูนิตหนึ่ง
class _UnitForm {
  final unitNo = TextEditingController();
  final area = TextEditingController();
  final floor = TextEditingController();
  String? roomType;
  int? bedrooms;
  int? bathrooms;
  String? size;
  String? direction;

  ProjectUnit toUnit() => ProjectUnit(
    unitNo: unitNo.text.trim(),
    roomType: roomType ?? '',
    bedrooms: bedrooms,
    bathrooms: bathrooms,
    area: double.tryParse(area.text),
    floor: floor.text.trim(),
    size: size ?? '',
    direction: direction ?? '',
  );

  void dispose() {
    unitNo.dispose();
    area.dispose();
    floor.dispose();
  }
}

/// ช่องพิมพ์ได้ + มีรายการให้เลือก (จังหวัด, เขต/อำเภอ, แขวง/ตำบล)
///
/// คีย์บอร์ด: พิมพ์บางส่วน → ลูกศรขึ้น/ลงเลือก → Enter = เลือกตัวที่ไฮไลต์
/// แล้วข้ามไปช่องถัดไป
class _AutoField extends StatefulWidget {
  const _AutoField({
    required this.controller,
    required this.options,
    required this.decoration,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final TextEditingController controller;
  final List<String> Function() options;
  final InputDecoration decoration;
  final ValueChanged<String> onChanged;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  State<_AutoField> createState() => _AutoFieldState();
}

class _AutoFieldState extends State<_AutoField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Iterable<String> _matches(String text) {
    final q = text.trim();
    final all = widget.options();
    if (q.isEmpty) return all;
    // ขึ้นต้นด้วยคำที่พิมพ์มาก่อน แล้วตามด้วยที่มีคำนั้นอยู่ข้างใน
    return [
      ...all.where((e) => e.startsWith(q)),
      ...all.where((e) => !e.startsWith(q) && e.contains(q)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focus,
        optionsBuilder: (v) => _matches(v.text),
        onSelected: widget.onChanged,
        fieldViewBuilder: (context, ctrl, node, selectHighlighted) =>
            TextFormField(
              controller: ctrl,
              focusNode: node,
              enabled: widget.enabled,
              decoration: widget.decoration,
              validator: widget.validator,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.next,
              // ต้องเลือกค่าก่อนย้ายโฟกัส: ถ้าย้ายก่อน รายการจะปิดแล้วเลือกไม่ได้
              onEditingComplete: () {
                final v = ctrl.text.trim();
                // ช่องว่าง: แค่ข้ามไปช่องถัดไป ไม่เลือกอะไรให้
                if (v.isNotEmpty && !widget.options().contains(v)) {
                  selectHighlighted();
                }
                node.nextFocus();
              },
            ),
        optionsViewBuilder: (context, onSelected, opts) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 280,
                maxWidth: constraints.maxWidth,
              ),
              child: _OptionsList(options: opts, onSelected: onSelected),
            ),
          ),
        ),
      ),
    );
  }
}

/// รายการตัวเลือก: ไฮไลต์ตัวที่จะถูกเลือกเมื่อกด Enter และเลื่อนตามลูกศร
class _OptionsList extends StatefulWidget {
  const _OptionsList({required this.options, required this.onSelected});

  final Iterable<String> options;
  final AutocompleteOnSelected<String> onSelected;

  @override
  State<_OptionsList> createState() => _OptionsListState();
}

class _OptionsListState extends State<_OptionsList> {
  static const _itemExtent = 44.0;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = AutocompleteHighlightedOption.of(context);
    // ให้ตัวที่ไฮไลต์อยู่ในกรอบเสมอเมื่อกดลูกศร
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final top = highlighted * _itemExtent;
      final view = _scroll.position.viewportDimension;
      if (top < _scroll.offset) {
        _scroll.jumpTo(top);
      } else if (top + _itemExtent > _scroll.offset + view) {
        _scroll.jumpTo(top + _itemExtent - view);
      }
    });
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemExtent: _itemExtent,
      itemCount: widget.options.length,
      itemBuilder: (_, i) {
        final o = widget.options.elementAt(i);
        final active = i == highlighted;
        return InkWell(
          onTap: () => widget.onSelected(o),
          child: Container(
            color: active ? AppColors.skyLight : null,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Text(
              o,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.navy,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ใส่ comma คั่นหลักพันอัตโนมัติ เช่น 2490000 -> 2,490,000
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

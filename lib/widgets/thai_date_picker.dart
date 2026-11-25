import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const kThaiMonths = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];
const _daysShort = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
const _daysFull = [
  'อาทิตย์',
  'จันทร์',
  'อังคาร',
  'พุธ',
  'พฤหัสบดี',
  'ศุกร์',
  'เสาร์',
];

/// ตัวเลือกวันที่แบบไทย: ชื่อเดือนภาษาไทย ปี พ.ศ. ปุ่มใหญ่กดง่าย
Future<DateTime?> showThaiDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'เลือกวันที่',
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _ThaiDatePickerDialog(
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
      title: title,
    ),
  );
}

class _ThaiDatePickerDialog extends StatefulWidget {
  const _ThaiDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;

  @override
  State<_ThaiDatePickerDialog> createState() => _ThaiDatePickerDialogState();
}

class _ThaiDatePickerDialogState extends State<_ThaiDatePickerDialog> {
  late DateTime _selected = _dateOnly(widget.initialDate);
  late DateTime _month = DateTime(_selected.year, _selected.month);
  bool _yearMode = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _inRange(DateTime d) =>
      !d.isBefore(_dateOnly(widget.firstDate)) &&
      !d.isAfter(_dateOnly(widget.lastDate));

  bool get _canPrev => DateTime(
    _month.year,
    _month.month,
  ).isAfter(DateTime(widget.firstDate.year, widget.firstDate.month));

  bool get _canNext => DateTime(
    _month.year,
    _month.month,
  ).isBefore(DateTime(widget.lastDate.year, widget.lastDate.month));

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final s = _selected;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // หัว: วันที่ที่เลือก
            Container(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.navy, AppColors.blue],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'วัน${_daysFull[s.weekday % 7]}ที่ ${s.day} ${kThaiMonths[s.month - 1]} ${s.year + 543}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _yearMode = !_yearMode),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${kThaiMonths[_month.month - 1]} ${_month.year + 543}',
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Icon(
                                _yearMode
                                    ? Icons.arrow_drop_up_rounded
                                    : Icons.arrow_drop_down_rounded,
                                color: AppColors.navy,
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!_yearMode) ...[
                        _navButton(
                          Icons.chevron_left_rounded,
                          'เดือนก่อน',
                          _canPrev ? () => _shiftMonth(-1) : null,
                        ),
                        const SizedBox(width: 6),
                        _navButton(
                          Icons.chevron_right_rounded,
                          'เดือนถัดไป',
                          _canNext ? () => _shiftMonth(1) : null,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 340,
                    child: _yearMode ? _yearGrid() : _dayGrid(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      final today = _dateOnly(DateTime.now());
                      if (!_inRange(today)) return;
                      setState(() {
                        _selected = today;
                        _month = DateTime(today.year, today.month);
                        _yearMode = false;
                      });
                    },
                    icon: const Icon(Icons.today_rounded, size: 20),
                    label: const Text('วันนี้'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.hint,
                      minimumSize: const Size(88, 46),
                    ),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(110, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('ตกลง'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, String tip, VoidCallback? onTap) {
    return Material(
      color: onTap == null ? Colors.transparent : AppColors.skyLight,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.navy),
      ),
    );
  }

  Widget _dayGrid() {
    final first = DateTime(_month.year, _month.month);
    final offset = first.weekday % 7; // อาทิตย์ = 0
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final today = _dateOnly(DateTime.now());

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    _daysShort[i],
                    style: TextStyle(
                      color: i == 0 ? const Color(0xFFD84343) : AppColors.hint,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < 6; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _dayCell(row * 7 + col - offset + 1, days, today),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dayCell(int day, int daysInMonth, DateTime today) {
    if (day < 1 || day > daysInMonth) return const SizedBox();
    final date = DateTime(_month.year, _month.month, day);
    final selected = date == _selected;
    final isToday = date == today;
    final enabled = _inRange(date);

    return Center(
      child: SizedBox(
        width: 46,
        height: 46,
        child: Material(
          color: selected ? AppColors.blue : Colors.transparent,
          shape: CircleBorder(
            side: isToday && !selected
                ? const BorderSide(color: AppColors.blue, width: 1.6)
                : BorderSide.none,
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? () => setState(() => _selected = date) : null,
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected || isToday
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: !enabled
                      ? AppColors.border
                      : selected
                      ? Colors.white
                      : isToday
                      ? AppColors.blue
                      : AppColors.navy,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _yearGrid() {
    final years = [
      for (var y = widget.firstDate.year; y <= widget.lastDate.year; y++) y,
    ];
    final index = years.indexOf(_month.year).clamp(0, years.length - 1);
    return GridView.builder(
      // เลื่อนให้เห็นปีที่เลือกอยู่ (แถวละ 4 ปี สูงแถวละ ~56)
      controller: ScrollController(
        initialScrollOffset: ((index ~/ 4) - 1).clamp(0, 999) * 56.0,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisExtent: 48,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: years.length,
      itemBuilder: (_, i) {
        final y = years[i];
        final current = y == _month.year;
        return Material(
          color: current ? AppColors.blue : AppColors.skyLight,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              _month = DateTime(y, _month.month);
              _yearMode = false;
            }),
            child: Center(
              child: Text(
                '${y + 543}',
                style: TextStyle(
                  color: current ? Colors.white : AppColors.navy,
                  fontSize: 16,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

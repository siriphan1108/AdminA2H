import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';

/// แผนที่สำหรับปักหมุดตำแหน่งโครงการ: คลิกบนแผนที่ หรือค้นหาชื่อสถานที่
class MapPinPicker extends StatefulWidget {
  const MapPinPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.height = 380,
  });

  final LatLng? value;
  final ValueChanged<LatLng?> onChanged;
  final double height;

  @override
  State<MapPinPicker> createState() => _MapPinPickerState();
}

class _Place {
  const _Place(this.name, this.point);
  final String name;
  final LatLng point;
}

class _MapPinPickerState extends State<MapPinPicker> {
  static const _bangkok = LatLng(13.7563, 100.5018);

  final _map = MapController();
  final _search = TextEditingController();
  List<_Place> _results = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _results = [];
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'jsonv2',
        'limit': '6',
        'countrycodes': 'th',
        'accept-language': 'th',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final places = [
        for (final e in jsonDecode(res.body) as List)
          _Place(
            e['display_name'] as String,
            LatLng(
              double.parse(e['lat'] as String),
              double.parse(e['lon'] as String),
            ),
          ),
      ];
      if (!mounted) return;
      setState(() {
        _results = places;
        if (places.isEmpty) _error = 'ไม่พบสถานที่ที่ค้นหา';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'ค้นหาไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pick(LatLng p, {bool move = false}) {
    widget.onChanged(p);
    if (move) _map.move(p, 16);
    setState(() {
      _results = [];
      _error = null;
    });
  }

  void _zoom(double delta) {
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(3, 19));
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: pin ?? _bangkok,
                    initialZoom: pin == null ? 11 : 16,
                    onTap: (_, p) => _pick(p),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.a2home.admin_a2h',
                    ),
                    if (pin != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pin,
                            width: 48,
                            height: 48,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFFE53935),
                              size: 48,
                              shadows: [
                                Shadow(color: Colors.black38, blurRadius: 6),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SimpleAttributionWidget(
                      source: Text('OpenStreetMap contributors'),
                    ),
                  ],
                ),
                // ช่องค้นหาสถานที่
                Positioned(
                  top: 12,
                  left: 12,
                  right: 72,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: _searchBox(),
                    ),
                  ),
                ),
                // ปุ่มซูม
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      _mapButton(Icons.add_rounded, 'ซูมเข้า', () => _zoom(1)),
                      const SizedBox(height: 6),
                      _mapButton(
                        Icons.remove_rounded,
                        'ซูมออก',
                        () => _zoom(-1),
                      ),
                      if (pin != null) ...[
                        const SizedBox(height: 6),
                        _mapButton(
                          Icons.my_location_rounded,
                          'ไปที่หมุด',
                          () => _map.move(pin, 16),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              pin == null ? Icons.touch_app_outlined : Icons.place_rounded,
              size: 18,
              color: pin == null ? AppColors.hint : AppColors.blue,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                pin == null
                    ? 'คลิกบนแผนที่ หรือค้นหาสถานที่ เพื่อปักหมุดตำแหน่งโครงการ'
                    : 'พิกัด ${pin.latitude.toStringAsFixed(6)}, ${pin.longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  color: pin == null ? AppColors.hint : AppColors.navy,
                  fontSize: 13,
                ),
              ),
            ),
            if (pin != null)
              TextButton.icon(
                onPressed: () => widget.onChanged(null),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('ล้างหมุด'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _searchBox() {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _doSearch(),
            decoration: InputDecoration(
              hintText: 'ค้นหาสถานที่ เช่น สถานี BTS อ่อนนุช',
              hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.blue,
              ),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'ค้นหา',
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: _doSearch,
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          if (_results.isNotEmpty) ...[
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final p in _results)
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.place_outlined,
                        color: AppColors.blue,
                      ),
                      title: Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _pick(p.point, move: true),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mapButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: AppColors.navy),
        onPressed: onTap,
      ),
    );
  }
}

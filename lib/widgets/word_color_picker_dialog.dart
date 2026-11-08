import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WordColorPickerDialog extends StatefulWidget {
  final int selectedColor;
  const WordColorPickerDialog({super.key, required this.selectedColor});

  @override
  State<WordColorPickerDialog> createState() => _WordColorPickerDialogState();
}

class _WordColorPickerDialogState extends State<WordColorPickerDialog> {
  late int _selected;
  final _hexController = TextEditingController();
  String _hexError = '';

  // ── Renk paleti ───────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _themeColors = [
    // Ad, ana renk, [açık tonlar...], [koyu tonlar...]
    {
      'name': 'Beyaz / Gri',
      'shades': [0xFFFFFFFF, 0xFFF5F5F5, 0xFFE0E0E0, 0xFF9E9E9E, 0xFF616161, 0xFF212121],
    },
    {
      'name': 'Mavi',
      'shades': [0xFFE3F2FD, 0xFFBBDEFB, 0xFF90CAF9, 0xFF42A5F5, 0xFF1976D2, 0xFF0D47A1],
    },
    {
      'name': 'Yeşil',
      'shades': [0xFFE8F5E9, 0xFFC8E6C9, 0xFFA5D6A7, 0xFF66BB6A, 0xFF388E3C, 0xFF1B5E20],
    },
    {
      'name': 'Mor / Leylak',
      'shades': [0xFFF3E5F5, 0xFFE1BEE7, 0xFFCE93D8, 0xFFAB47BC, 0xFF7B1FA2, 0xFF4A148C],
    },
    {
      'name': 'Turuncu / Şeftali',
      'shades': [0xFFFFF3E0, 0xFFFFE0B2, 0xFFFFCC80, 0xFFFF9800, 0xFFE65100, 0xFFBF360C],
    },
    {
      'name': 'Pembe / Gül',
      'shades': [0xFFFCE4EC, 0xFFF8BBD0, 0xFFF48FB1, 0xFFE91E63, 0xFFC2185B, 0xFF880E4F],
    },
    {
      'name': 'Turkuaz / Nane',
      'shades': [0xFFE0F2F1, 0xFFB2DFDB, 0xFF80CBC4, 0xFF26A69A, 0xFF00796B, 0xFF004D40],
    },
    {
      'name': 'Sarı / Limon',
      'shades': [0xFFFFFDE7, 0xFFFFF9C4, 0xFFFFF176, 0xFFFFEE58, 0xFFF9A825, 0xFFF57F17],
    },
  ];

  static const List<Map<String, dynamic>> _standardColors = [
    {'name': 'Kırmızı', 'value': 0xFFFFCDD2},
    {'name': 'Turuncu', 'value': 0xFFFFE0B2},
    {'name': 'Sarı', 'value': 0xFFFFF9C4},
    {'name': 'Yeşil', 'value': 0xFFC8E6C9},
    {'name': 'Mavi', 'value': 0xFFBBDEFB},
    {'name': 'İndigo', 'value': 0xFFC5CAE9},
    {'name': 'Mor', 'value': 0xFFE1BEE7},
    {'name': 'Pembe', 'value': 0xFFF8BBD0},
    {'name': 'Turkuaz', 'value': 0xFFB2EBF2},
    {'name': 'Nane', 'value': 0xFFB2DFDB},
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedColor;
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _applyHex() {
    String hex = _hexController.text.trim().replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) {
      final val = int.tryParse(hex, radix: 16);
      if (val != null) {
        setState(() {
          _selected = 0xFF000000 | val;
          _hexError = '';
        });
        return;
      }
    }
    setState(() => _hexError = 'Geçersiz hex kodu');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: const Row(children: [
        Icon(Icons.palette_rounded, color: Colors.deepPurple),
        SizedBox(width: 8),
        Text('Not Rengi Seç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Beyaz / Varsayılan ──
            GestureDetector(
              onTap: () => setState(() => _selected = 0xFFFFFFFF),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selected == 0xFFFFFFFF ? Colors.deepPurple : Colors.grey.shade300,
                    width: _selected == 0xFFFFFFFF ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  const Icon(Icons.format_color_reset_rounded, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Varsayılan (Beyaz)', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  if (_selected == 0xFFFFFFFF) const Icon(Icons.check_circle_rounded, color: Colors.deepPurple, size: 18),
                ]),
              ),
            ),

            // ── Standart Pastel Renkler ──
            const Text('Standart Renkler', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _standardColors.map((c) {
                final val = c['value'] as int;
                final isSelected = _selected == val;
                return Tooltip(
                  message: c['name'] as String,
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = val),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: Color(val),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.deepPurple) : null,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // ── Tema Renk Tablosu (Word-style grid) ──
            const Text('Tema Renkleri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: Colors.grey.shade200, width: 0.5, borderRadius: BorderRadius.circular(4)),
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1),
                5: FlexColumnWidth(1),
              },
              children: _themeColors.map((theme) {
                final shades = theme['shades'] as List<int>;
                return TableRow(
                  children: shades.map((shade) {
                    final isSelected = _selected == shade;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = shade),
                      child: Tooltip(
                        message: '${theme['name']}',
                        child: Container(
                          height: 28,
                          color: Color(shade),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 14,
                                  color: ThemeData.estimateBrightnessForColor(Color(shade)) == Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // ── Özel Hex Renk ──
            const Text('Özel Renk (Hex Kodu)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _hexController,
                  decoration: InputDecoration(
                    hintText: '#RRGGBB veya RRGGBB',
                    prefixText: '#',
                    errorText: _hexError.isNotEmpty ? _hexError : null,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F#]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _applyHex, child: const Text('Uygula')),
            ]),

            const SizedBox(height: 12),

            // ── Önizleme ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Color(_selected),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(children: [
                const Icon(Icons.sticky_note_2_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Not önizlemesi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ThemeData.estimateBrightnessForColor(Color(_selected)) == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Uygula'),
        ),
      ],
    );
  }
}

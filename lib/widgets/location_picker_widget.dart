import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/note.dart';

/// Basit manuel koordinat girişi ile konum seçici.
/// GPS paketi gerektirmez — koordinatı elle girilebilir veya
/// ileride geolocator ile genişletilebilir.
class LocationPickerDialog extends StatefulWidget {
  final LocationItem? initialLocation;
  const LocationPickerDialog({super.key, this.initialLocation});

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _placeController = TextEditingController();
  final _addressController = TextEditingController();
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      final l = widget.initialLocation!;
      _latController.text = l.latitude.toString();
      _lngController.text = l.longitude.toString();
      _placeController.text = l.placeName ?? '';
      _addressController.text = l.address ?? '';
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _placeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    final lat = double.tryParse(_latController.text.trim().replaceAll(',', '.'));
    final lng = double.tryParse(_lngController.text.trim().replaceAll(',', '.'));

    if (lat == null || lng == null) {
      setState(() => _error = 'Lütfen geçerli enlem ve boylam değerleri girin.');
      return;
    }
    if (lat < -90 || lat > 90) {
      setState(() => _error = 'Enlem -90 ile 90 arasında olmalıdır.');
      return;
    }
    if (lng < -180 || lng > 180) {
      setState(() => _error = 'Boylam -180 ile 180 arasında olmalıdır.');
      return;
    }

    Navigator.pop(
      context,
      LocationItem(
        latitude: lat,
        longitude: lng,
        placeName: _placeController.text.trim().isEmpty ? null : _placeController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.location_on_rounded, color: Colors.green),
        SizedBox(width: 8),
        Text('Konum Bilgisi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Konum koordinatlarını ve opsiyonel yer adını girin.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Hızlı kopyalama notu
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Google Maps\'ten koordinat kopyalayıp yapıştırabilirsiniz.',
                    style: TextStyle(fontSize: 11, color: Colors.green),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Enlem
            TextField(
              controller: _latController,
              decoration: const InputDecoration(
                labelText: 'Enlem (Latitude)',
                hintText: 'Örn: 41.01384',
                prefixIcon: Icon(Icons.my_location_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
            ),
            const SizedBox(height: 10),

            // Boylam
            TextField(
              controller: _lngController,
              decoration: const InputDecoration(
                labelText: 'Boylam (Longitude)',
                hintText: 'Örn: 28.94966',
                prefixIcon: Icon(Icons.explore_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
            ),
            const SizedBox(height: 10),

            // Yer adı
            TextField(
              controller: _placeController,
              decoration: const InputDecoration(
                labelText: 'Yer Adı (Opsiyonel)',
                hintText: 'Örn: Galata Kulesi',
                prefixIcon: Icon(Icons.place_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),

            // Adres
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adres (Opsiyonel)',
                hintText: 'Örn: Bereketzade Mah., Beyoğlu',
                prefixIcon: Icon(Icons.home_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),

            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_error, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],

            const SizedBox(height: 12),

            // Google Maps'te aç butonu (web link)
            OutlinedButton.icon(
              icon: const Icon(Icons.map_outlined, size: 16),
              label: const Text('Google Maps\'i Aç (Koordinat Almak İçin)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 11),
              ),
              onPressed: () async {
                // URL launcher gerekmez, sadece bilgi kopyala
                await Clipboard.setData(const ClipboardData(text: 'https://maps.google.com'));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('maps.google.com tarayıcınıza kopyalandı')),
                  );
                }
              },
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        ElevatedButton.icon(
          icon: const Icon(Icons.location_on_rounded, size: 18),
          label: const Text('Konumu Kaydet'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          onPressed: _save,
        ),
      ],
    );
  }
}

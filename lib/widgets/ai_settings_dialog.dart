import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/note_storage.dart';

class AiSettingsDialog extends StatefulWidget {
  const AiSettingsDialog({super.key});

  @override
  State<AiSettingsDialog> createState() => _AiSettingsDialogState();
}

class _AiSettingsDialogState extends State<AiSettingsDialog> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = true;
  bool _isIndexing = false;
  int _indexedCount = 0;
  int _totalToIndex = 0;
  String _statusMessage = '';
  bool _notesWereUpdated = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadKey() async {
    final key = await AiService.getApiKey();
    if (mounted) {
      setState(() {
        _apiKeyController.text = key ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      await AiService.removeApiKey();
    } else {
      await AiService.setApiKey(key);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yapay zeka anahtarı kaydedildi! ✨')),
      );
    }
  }

  Future<void> _updateOfflineModel() async {
    setState(() => _statusMessage = 'Çevrimdışı model sözlüğü güncelleniyor...');
    final success = await AiService.updateOfflineModel();
    if (mounted) {
      setState(() {
        _statusMessage = success
            ? '✅ Çevrimdışı AI modeli başarıyla güncellendi!'
            : '❌ Güncelleme sırasında hata oluştu.';
      });
    }
  }

  Future<void> _indexAllNotes() async {
    setState(() {
      _isIndexing = true;
      _statusMessage = 'Notlar analiz ediliyor...';
    });

    final notes = await NoteStorage.loadNotes();
    await AiService.indexAllNotes(
      notes: notes,
      onProgress: (current, total) {
        if (mounted) {
          setState(() {
            _indexedCount = current;
            _totalToIndex = total;
          });
        }
      },
    );

    await NoteStorage.saveNotes(notes);
    _notesWereUpdated = true;

    if (mounted) {
      setState(() {
        _isIndexing = false;
        _statusMessage = '✅ Tüm notlar başarıyla yapay zeka ile indekslendi!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 24),
          SizedBox(width: 10),
          Text('Yapay Zeka (AI) Motoru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: _isLoading
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fotoğraflarda nesne tanıma (mavi kazak, çocuk, karpuz vb.), ses çözümleme ve akıllı arama motorunu yönetin.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // ── 1. Google Gemini Flash API Anahtarı ──
                    const Text(
                      '1. Çevrimiçi Gemini Flash (Önerilen & Ücretsiz)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _apiKeyController,
                      decoration: InputDecoration(
                        labelText: 'Gemini API Anahtarı',
                        hintText: 'AIzaSy...',
                        isDense: true,
                        prefixIcon: const Icon(Icons.key_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.save_rounded, color: Colors.deepPurple),
                          tooltip: 'Kaydet',
                          onPressed: _saveKey,
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Google AI Studio\'dan (aistudio.google.com) saniyeler içinde tamamen ücretsiz alabilirsiniz.',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),

                    // ── 2. Çevrimdışı Model Güncelleme ──
                    const Text(
                      '2. Çevrimdışı Yerel Yapay Zeka',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'İnternet veya API anahtarı olmadan yerel olarak fotoğrafları ve içerikleri sınıflandırır.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_download_outlined, size: 18),
                      label: const Text('Çevrimdışı AI Modelini / Sözlüğü Güncelle'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _updateOfflineModel,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),

                    // ── 3. Toplu İndeksleme Butonu ──
                    const Text(
                      '3. Mevcut Notları Tara',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Önceden eklediğiniz tüm fotoğraflı ve sesli notları yapay zekaya taratıp akıllı aramaya hazır hale getirin.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    if (_isIndexing) ...[
                      LinearProgressIndicator(
                        value: _totalToIndex > 0 ? _indexedCount / _totalToIndex : null,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'İşleniyor: $_indexedCount / $_totalToIndex',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                    ] else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Tüm Notları Yapay Zeka ile İndeksle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _indexAllNotes,
                      ),

                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _notesWereUpdated),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

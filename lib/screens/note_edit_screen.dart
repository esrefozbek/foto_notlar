import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../services/note_storage.dart';
import '../widgets/audio_list_widget.dart';
import '../widgets/document_list_widget.dart';
import '../widgets/media_transfer_dialog.dart';
import '../widgets/voice_recorder_dialog.dart';
import '../widgets/video_list_widget.dart';
import '../widgets/word_color_picker_dialog.dart';
import '../widgets/location_picker_widget.dart';

class NoteEditScreen extends StatefulWidget {
  final Note? note;

  const NoteEditScreen({super.key, this.note});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final ImagePicker _picker = ImagePicker();

  final List<String> _imagesBase64 = [];
  final List<Uint8List> _imagesBytes = [];
  final List<AudioItem> _audios = [];
  final List<DocumentItem> _documents = [];
  final List<VideoItem> _videos = [];

  late int _selectedColor;
  late String _selectedFont;
  LocationItem? _location;
  bool _isSaving = false;

  // ── Değişiklik tespiti için orijinal değerler ──
  late String _originalTitle;
  late String _originalContent;
  late int _originalColor;
  late String _originalFont;
  late int _originalImageCount;
  late int _originalAudioCount;
  late int _originalDocCount;
  late int _originalVideoCount;
  late bool _originalHasLocation;

  bool get _hasChanges {
    if (_titleController.text.trim() != _originalTitle) return true;
    if (_contentController.text.trim() != _originalContent) return true;
    if (_selectedColor != _originalColor) return true;
    if (_selectedFont != _originalFont) return true;
    if (_imagesBase64.length != _originalImageCount) return true;
    if (_audios.length != _originalAudioCount) return true;
    if (_documents.length != _originalDocCount) return true;
    if (_videos.length != _originalVideoCount) return true;
    if ((_location != null) != _originalHasLocation) return true;
    return false;
  }

  // Font seçenekleri
  static const List<Map<String, String>> _fontOptions = [
    {'key': 'default', 'label': 'Varsayılan', 'sample': 'Aa'},
    {'key': 'serif', 'label': 'Kitap / Serif', 'sample': 'Aa'},
    {'key': 'monospace', 'label': 'Daktilo / Kod', 'sample': 'Aa'},
    {'key': 'cursive', 'label': 'El Yazısı', 'sample': 'Aa'},
    {'key': 'rounded', 'label': 'Modern', 'sample': 'Aa'},
  ];

  static String? _flutterFontFamily(String key) {
    switch (key) {
      case 'serif':
        return 'Georgia';
      case 'monospace':
        return 'RobotoMono';
      case 'cursive':
        return 'DancingScript';
      case 'rounded':
        return 'Nunito';
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _selectedColor = widget.note?.colorValue ?? 0xFFFFFFFF;
    _selectedFont = widget.note?.fontFamily ?? 'default';
    _location = widget.note?.location;

    if (widget.note != null) {
      for (final b64 in widget.note!.imagesBase64) {
        try {
          _imagesBytes.add(base64Decode(b64));
          _imagesBase64.add(b64);
        } catch (_) {}
      }
      _audios.addAll(widget.note!.audios);
      _documents.addAll(widget.note!.documents);
      _videos.addAll(widget.note!.videos);
    }

    // Orijinal değerleri kaydet
    _originalTitle = _titleController.text.trim();
    _originalContent = _contentController.text.trim();
    _originalColor = _selectedColor;
    _originalFont = _selectedFont;
    _originalImageCount = _imagesBase64.length;
    _originalAudioCount = _audios.length;
    _originalDocCount = _documents.length;
    _originalVideoCount = _videos.length;
    _originalHasLocation = _location != null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ── Değişiklik günlüğü oluştur ──
  List<ChangeLogEntry> _buildChangeLogs() {
    final existing = List<ChangeLogEntry>.from(widget.note?.changeLogs ?? []);
    final changes = <String>[];
    final now = DateTime.now();

    if (_titleController.text.trim() != _originalTitle) changes.add('Başlık değiştirildi');
    if (_contentController.text.trim() != _originalContent) changes.add('İçerik güncellendi');
    if (_selectedColor != _originalColor) changes.add('Renk değiştirildi');
    if (_selectedFont != _originalFont) changes.add('Font değiştirildi');
    if (_imagesBase64.length > _originalImageCount) changes.add('${_imagesBase64.length - _originalImageCount} fotoğraf eklendi');
    if (_imagesBase64.length < _originalImageCount) changes.add('${_originalImageCount - _imagesBase64.length} fotoğraf silindi');
    if (_audios.length > _originalAudioCount) changes.add('${_audios.length - _originalAudioCount} ses eklendi');
    if (_audios.length < _originalAudioCount) changes.add('${_originalAudioCount - _audios.length} ses silindi');
    if (_documents.length > _originalDocCount) changes.add('${_documents.length - _originalDocCount} belge eklendi');
    if (_documents.length < _originalDocCount) changes.add('${_originalDocCount - _documents.length} belge silindi');
    if (_videos.length > _originalVideoCount) changes.add('${_videos.length - _originalVideoCount} video eklendi');
    if (_videos.length < _originalVideoCount) changes.add('${_originalVideoCount - _videos.length} video silindi');
    if ((_location != null) != _originalHasLocation) {
      changes.add(_location != null ? 'Konum eklendi' : 'Konum kaldırıldı');
    }

    if (changes.isNotEmpty) {
      existing.insert(0, ChangeLogEntry(timestamp: now, description: changes.join(', ')));
    }

    // Maksimum 50 kayıt tut
    return existing.take(50).toList();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SES İŞLEMLERİ
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _recordVoiceNote() async {
    final result = await showDialog<VoiceRecordingResult>(
      context: context,
      builder: (_) => const VoiceRecorderDialog(),
    );
    if (result != null) {
      setState(() {
        _audios.add(AudioItem(
          id: 'audio_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Ses Kaydı ${_audios.length + 1}',
          base64Data: result.audioBase64,
          durationSeconds: result.durationSeconds,
        ));
      });
    }
  }

  Future<void> _pickExternalAudioFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'wma', 'flac'],
      );
      if (files.isNotEmpty) {
        for (final file in files) {
          final bytes = await file.readAsBytes();
          setState(() {
            _audios.add(AudioItem(
              id: 'audio_${DateTime.now().millisecondsSinceEpoch}_${file.name}',
              name: file.name,
              base64Data: base64Encode(bytes),
              durationSeconds: 0,
              isExternalFile: true,
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) _showError('Ses dosyası seçilirken hata: $e');
    }
  }

  void _showAudioOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Wrap(children: [
            const ListTile(title: Text('Ses Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            ListTile(
              leading: const Icon(Icons.mic, color: Colors.deepPurple),
              title: const Text('Mikrofonla Yeni Ses Kaydet'),
              onTap: () { Navigator.pop(ctx); _recordVoiceNote(); },
            ),
            ListTile(
              leading: const Icon(Icons.music_note, color: Colors.blueAccent),
              title: const Text('Cihazdan Ses / MP3 Dosyası Seç'),
              subtitle: const Text('Müzik veya harici ses dosyaları'),
              onTap: () { Navigator.pop(ctx); _pickExternalAudioFile(); },
            ),
          ]),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BELGE İŞLEMLERİ
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _pickDocuments() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'csv', 'pptx', 'ppt'],
      );
      if (files.isNotEmpty) {
        for (final file in files) {
          final bytes = await file.readAsBytes();
          final size = (await file.length()) ?? bytes.length;
          final ext = file.extension ?? (file.name.contains('.') ? file.name.split('.').last : 'file');
          setState(() {
            _documents.add(DocumentItem(
              id: 'doc_${DateTime.now().millisecondsSinceEpoch}_${file.name}',
              name: file.name,
              extension: ext.toLowerCase(),
              sizeBytes: size,
              base64Data: base64Encode(bytes),
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) _showError('Belge seçilirken hata: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FOTOĞRAF İŞLEMLERİ
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _pickMultipleImages() async {
    try {
      final pickedFiles = await _picker.pickMultiImage(maxWidth: 1280, maxHeight: 1280, imageQuality: 85);
      if (pickedFiles.isNotEmpty) {
        for (final file in pickedFiles) {
          final bytes = await file.readAsBytes();
          setState(() {
            _imagesBytes.add(bytes);
            _imagesBase64.add(base64Encode(bytes));
          });
        }
      }
    } catch (e) {
      if (mounted) _showError('Fotoğraf seçilirken hata: $e');
    }
  }

  Future<void> _pickCameraImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1280, maxHeight: 1280, imageQuality: 85);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imagesBytes.add(bytes);
          _imagesBase64.add(base64Encode(bytes));
        });
      }
    } catch (e) {
      if (mounted) _showError('Kameradan fotoğraf çekilirken hata: $e');
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Wrap(children: [
            ListTile(
              title: Text(_imagesBytes.isEmpty ? 'Fotoğraf Ekle' : 'Daha Fazla Fotoğraf Ekle',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
              title: const Text('Galeriden Seç (Çoklu Fotoğraf)'),
              onTap: () { Navigator.pop(ctx); _pickMultipleImages(); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.deepOrangeAccent),
              title: const Text('Kamerayla Yeni Çek'),
              onTap: () { Navigator.pop(ctx); _pickCameraImage(); },
            ),
            if (_imagesBytes.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                title: const Text('Tüm Fotoğrafları Kaldır', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() { _imagesBytes.clear(); _imagesBase64.clear(); });
                },
              ),
          ]),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // VİDEO İŞLEMLERİ
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _pickVideoFromGallery() async {
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null) await _addVideoFile(file.path, file.name);
    } catch (e) {
      if (mounted) _showError('Video seçilirken hata: $e');
    }
  }

  Future<void> _pickVideoFromCamera() async {
    try {
      final file = await _picker.pickVideo(source: ImageSource.camera);
      if (file != null) await _addVideoFile(file.path, file.name);
    } catch (e) {
      if (mounted) _showError('Video kaydedilirken hata: $e');
    }
  }

  Future<void> _pickVideoFromFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'],
      );
      if (files.isNotEmpty) {
        for (final f in files) {
          final bytes = await f.readAsBytes();
          final size = (await f.length()) ?? bytes.length;
          setState(() {
            _videos.add(VideoItem(
              id: 'video_${DateTime.now().millisecondsSinceEpoch}_${f.name}',
              name: f.name,
              base64Data: base64Encode(bytes),
              sizeBytes: size,
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) _showError('Video dosyası seçilirken hata: $e');
    }
  }

  Future<void> _addVideoFile(String path, String name) async {
    try {
      if (kIsWeb) {
        _showError('Web\'de doğrudan video kaydı desteklenmez. Dosyadan ekleyebilirsiniz.');
        return;
      }
      final bytes = await XFile(path).readAsBytes();
      setState(() {
        _videos.add(VideoItem(
          id: 'video_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          base64Data: base64Encode(bytes),
          sizeBytes: bytes.length,
        ));
      });
    } catch (e) {
      if (mounted) _showError('Video eklenirken hata: $e');
    }
  }

  void _showVideoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Wrap(children: [
            const ListTile(title: Text('Video Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.redAccent),
                title: const Text('Kamerayla Video Kaydet'),
                onTap: () { Navigator.pop(ctx); _pickVideoFromCamera(); },
              ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.blueAccent),
              title: const Text('Galeriden Video Seç'),
              onTap: () { Navigator.pop(ctx); _pickVideoFromGallery(); },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open, color: Colors.orange),
              title: const Text('Dosyadan Video Ekle (MP4, MOV...)'),
              onTap: () { Navigator.pop(ctx); _pickVideoFromFiles(); },
            ),
          ]),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MEDYA AKTARIMI — BUG DÜZELTİLDİ
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _transferMedia({
    required String mediaType,
    required String mediaName,
    required Function(Note targetNote) onAddToTarget,
    required VoidCallback onRemoveFromCurrent,
  }) async {
    final result = await showDialog<MediaTransferResult>(
      context: context,
      builder: (_) => MediaTransferDialog(
        currentNoteId: widget.note?.id,
        mediaType: mediaType,
        mediaName: mediaName,
      ),
    );

    if (result == null) return;

    // Hedef notu storage'dan taze yükle
    final allNotes = await NoteStorage.loadNotes();
    final targetIndex = allNotes.indexWhere((n) => n.id == result.targetNoteId);

    if (targetIndex == -1) {
      if (mounted) _showError('Hedef not bulunamadı.');
      return;
    }

    final targetNote = allNotes[targetIndex];

    // Önce hedefe ekle
    onAddToTarget(targetNote);
    targetNote.updatedAt = DateTime.now();

    // Kaydet
    await NoteStorage.saveNotes(allNotes);

    // TAŞIMA ise mevcut notta sil (kopyalamada silme!)
    if (result.isMove) {
      setState(onRemoveFromCurrent);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.isMove
            ? '$mediaName → "${targetNote.title}" notuna taşındı.'
            : '$mediaName → "${targetNote.title}" notuna kopyalandı.'),
        backgroundColor: Colors.green.shade700,
      ));
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FOTOĞRAF TAM EKRAN
  // ──────────────────────────────────────────────────────────────────────────
  void _openFullScreenImage(int initialIndex) {
    showDialog(
      context: context,
      builder: (ctx) {
        int currentIndex = initialIndex;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.black.withValues(alpha: 0.95),
              insetPadding: EdgeInsets.zero,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Image.memory(
                      _imagesBytes[currentIndex],
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.drive_file_move_outlined, color: Colors.white, size: 26),
                        tooltip: 'Başka Nota Kopyala / Taşı',
                        onPressed: () {
                          Navigator.pop(ctx);
                          final b64 = _imagesBase64[currentIndex];
                          _transferMedia(
                            mediaType: 'Fotoğraf',
                            mediaName: 'Fotoğraf ${currentIndex + 1}',
                            onAddToTarget: (t) => t.imagesBase64.add(b64),
                            onRemoveFromCurrent: () {
                              final idx = _imagesBase64.indexOf(b64);
                              if (idx != -1) {
                                _imagesBase64.removeAt(idx);
                                _imagesBytes.removeAt(idx);
                              }
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ]),
                  ),
                  Positioned(
                    top: 30,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${currentIndex + 1} / ${_imagesBytes.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (currentIndex > 0)
                    Positioned(
                      left: 10,
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white, size: 40),
                        onPressed: () => setDialogState(() => currentIndex--),
                      ),
                    ),
                  if (currentIndex < _imagesBytes.length - 1)
                    Positioned(
                      right: 10,
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white, size: 40),
                        onPressed: () => setDialogState(() => currentIndex++),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FONT SEÇİCİ
  // ──────────────────────────────────────────────────────────────────────────
  void _showFontPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Yazı Tipi Seç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              ..._fontOptions.map((opt) {
                final isSelected = _selectedFont == opt['key'];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.deepPurple : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      opt['sample']!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontFamily: _flutterFontFamily(opt['key']!),
                      ),
                    ),
                  ),
                  title: Text(
                    opt['label']!,
                    style: TextStyle(
                      fontFamily: _flutterFontFamily(opt['key']!),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.deepPurple : Colors.black87,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.deepPurple) : null,
                  onTap: () {
                    setState(() => _selectedFont = opt['key']!);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // KONUM
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _pickLocation() async {
    final result = await showDialog<LocationItem>(
      context: context,
      builder: (_) => LocationPickerDialog(initialLocation: _location),
    );
    if (result != null) {
      setState(() => _location = result);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // KAYDET — sadece değişiklik varsa updatedAt güncellenir
  // ──────────────────────────────────────────────────────────────────────────
  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty && _imagesBase64.isEmpty &&
        _audios.isEmpty && _documents.isEmpty && _videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Boş not kaydedilemez!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final changed = _hasChanges;

    final noteToSave = Note(
      id: widget.note?.id ?? now.millisecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'Başlıksız Not' : title,
      content: content,
      createdAt: widget.note?.createdAt ?? now,
      // Değişiklik yoksa eski tarihi koru
      updatedAt: changed ? now : (widget.note?.updatedAt ?? now),
      imagesBase64: _imagesBase64,
      audios: _audios,
      documents: _documents,
      videos: _videos,
      colorValue: _selectedColor,
      fontFamily: _selectedFont,
      isPinned: widget.note?.isPinned ?? false,
      orderIndex: widget.note?.orderIndex ?? 0,
      location: _location,
      changeLogs: changed ? _buildChangeLogs() : (widget.note?.changeLogs ?? []),
    );

    Navigator.pop(context, noteToSave);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DEĞİŞİKLİK GÜNLÜĞÜ DİALOGU
  // ──────────────────────────────────────────────────────────────────────────
  void _showChangeLog() {
    final logs = widget.note?.changeLogs ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.history_rounded, color: Colors.deepPurple),
          SizedBox(width: 8),
          Text('Değişiklik Geçmişi', style: TextStyle(fontSize: 17)),
        ]),
        content: SizedBox(
          width: 350,
          child: logs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Henüz kayıtlı değişiklik yok.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final log = logs[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              DateFormat('d MMM yyyy, HH:mm', 'tr_TR').format(log.timestamp),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(log.description, style: const TextStyle(fontSize: 13)),
                          ]),
                        ),
                      ]),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final backgroundColor = Color(_selectedColor);
    final isDark = ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white60 : Colors.black45;
    final fontFamily = _flutterFontFamily(_selectedFont);

    final dateText = widget.note != null
        ? 'Son düzenleme: ${DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(widget.note!.updatedAt)}'
        : 'Oluşturulma: ${DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now())}';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
        title: Text(
          widget.note == null ? 'Yeni Not' : 'Notu Düzenle',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Konum
          IconButton(
            icon: Icon(
              _location != null ? Icons.location_on_rounded : Icons.location_off_outlined,
              color: _location != null ? Colors.green : null,
            ),
            tooltip: _location != null ? 'Konumu Düzenle / Kaldır' : 'Konum Ekle',
            onPressed: _pickLocation,
          ),
          // Geçmiş
          if (widget.note != null)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Değişiklik Geçmişi',
              onPressed: _showChangeLog,
            ),
          // Video
          IconButton(
            icon: Icon(Icons.videocam_outlined,
                color: _videos.isNotEmpty ? Colors.red.shade700 : null),
            tooltip: 'Video Ekle',
            onPressed: _showVideoOptions,
          ),
          // Belge
          IconButton(
            icon: const Icon(Icons.attach_file_rounded),
            tooltip: 'Belge Ekle (PDF, Word, Excel...)',
            onPressed: _pickDocuments,
          ),
          // Ses
          IconButton(
            icon: Icon(
              _audios.isNotEmpty ? Icons.graphic_eq_rounded : Icons.mic_none_outlined,
              color: _audios.isNotEmpty ? Colors.deepPurple : null,
            ),
            tooltip: 'Ses Kaydı & Müzik Ekle',
            onPressed: _showAudioOptions,
          ),
          // Fotoğraf
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Fotoğraf Ekle (Çoklu)',
            onPressed: _showImagePickerOptions,
          ),
          // Kaydet
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, size: 28),
            tooltip: 'Kaydet',
            onPressed: _isSaving ? null : _saveNote,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Ana içerik
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Fotoğraf Şeridi ──
                    if (_imagesBytes.isNotEmpty) ...[
                      SizedBox(
                        height: 210,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imagesBytes.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            if (index == _imagesBytes.length) {
                              return InkWell(
                                onTap: _showImagePickerOptions,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 140,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.withValues(alpha: 0.4), width: 1.5),
                                  ),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Icon(Icons.add_a_photo_outlined, size: 36, color: hintColor),
                                    const SizedBox(height: 8),
                                    Text('Fotoğraf Ekle', style: TextStyle(fontSize: 12, color: hintColor, fontWeight: FontWeight.bold)),
                                  ]),
                                ),
                              );
                            }
                            final imageBytes = _imagesBytes[index];
                            return Stack(
                              children: [
                                GestureDetector(
                                  onTap: () => _openFullScreenImage(index),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.memory(imageBytes, width: 210, height: 210, fit: BoxFit.cover),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8, left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(12)),
                                    child: Text('${index + 1} / ${_imagesBytes.length}',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                Positioned(
                                  top: 8, right: 8,
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Container(
                                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                                      child: IconButton(
                                        icon: const Icon(Icons.drive_file_move_outlined, color: Colors.white, size: 16),
                                        tooltip: 'Başka Nota Aktar',
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          final b64 = _imagesBase64[index];
                                          _transferMedia(
                                            mediaType: 'Fotoğraf',
                                            mediaName: 'Fotoğraf ${index + 1}',
                                            onAddToTarget: (t) => t.imagesBase64.add(b64),
                                            onRemoveFromCurrent: () {
                                              final idx = _imagesBase64.indexOf(b64);
                                              if (idx != -1) {
                                                _imagesBase64.removeAt(idx);
                                                _imagesBytes.removeAt(idx);
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                        tooltip: 'Bu Fotoğrafı Sil',
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () => setState(() {
                                          _imagesBytes.removeAt(index);
                                          _imagesBase64.removeAt(index);
                                        }),
                                      ),
                                    ),
                                  ]),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Ses Kayıtları ──
                    if (_audios.isNotEmpty) ...[
                      AudioListWidget(
                        audios: _audios,
                        onDelete: (idx) => setState(() => _audios.removeAt(idx)),
                        onRename: (idx, newName) => setState(() => _audios[idx].name = newName),
                        onTransfer: (idx) {
                          final item = _audios[idx];
                          _transferMedia(
                            mediaType: 'Ses Dosyası',
                            mediaName: item.name,
                            onAddToTarget: (t) => t.audios.add(item.copyWith()),
                            onRemoveFromCurrent: () => _audios.removeAt(idx),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Belgeler ──
                    if (_documents.isNotEmpty) ...[
                      DocumentListWidget(
                        documents: _documents,
                        onDelete: (idx) => setState(() => _documents.removeAt(idx)),
                        onTransfer: (idx) {
                          final doc = _documents[idx];
                          _transferMedia(
                            mediaType: 'Belge',
                            mediaName: doc.name,
                            onAddToTarget: (t) => t.documents.add(doc.copyWith()),
                            onRemoveFromCurrent: () => _documents.removeAt(idx),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Videolar ──
                    if (_videos.isNotEmpty) ...[
                      VideoListWidget(
                        videos: _videos,
                        onDelete: (idx) => setState(() => _videos.removeAt(idx)),
                        onRename: (idx, newName) => setState(() => _videos[idx].name = newName),
                        onTransfer: (idx) {
                          final vid = _videos[idx];
                          _transferMedia(
                            mediaType: 'Video',
                            mediaName: vid.name,
                            onAddToTarget: (t) => t.videos.add(vid.copyWith()),
                            onRemoveFromCurrent: () => _videos.removeAt(idx),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Konum Kartı ──
                    if (_location != null) ...[
                      _buildLocationCard(),
                      const SizedBox(height: 16),
                    ],

                    // ── Tarih + Geçmiş ──
                    Row(
                      children: [
                        Expanded(child: Text(dateText, style: TextStyle(fontSize: 12, color: hintColor))),
                        if (widget.note != null && (widget.note!.changeLogs.isNotEmpty))
                          GestureDetector(
                            onTap: _showChangeLog,
                            child: Row(children: [
                              Icon(Icons.history_rounded, size: 14, color: hintColor),
                              const SizedBox(width: 3),
                              Text(
                                '${widget.note!.changeLogs.length} değişiklik',
                                style: TextStyle(fontSize: 11, color: hintColor, decoration: TextDecoration.underline),
                              ),
                            ]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Başlık ──
                    TextField(
                      controller: _titleController,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor, fontFamily: fontFamily),
                      decoration: InputDecoration(
                        hintText: 'Başlık',
                        hintStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: hintColor),
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 24, thickness: 1),

                    // ── İçerik ──
                    TextField(
                      controller: _contentController,
                      maxLines: null,
                      style: TextStyle(fontSize: 16, height: 1.6, color: textColor, fontFamily: fontFamily),
                      decoration: InputDecoration(
                        hintText: 'Notunuzu buraya yazın...',
                        hintStyle: TextStyle(fontSize: 16, color: hintColor),
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Alt Araç Çubuğu: Font + Renk ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  // Font seçici butonu
                  InkWell(
                    onTap: _showFontPicker,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.text_fields_rounded, size: 18, color: Colors.deepPurple),
                        const SizedBox(width: 4),
                        Text(
                          _fontOptions.firstWhere((f) => f['key'] == _selectedFont)['label']!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Renk paleti butonu (Word-style)
                  InkWell(
                    onTap: () async {
                      final picked = await showDialog<int>(
                        context: context,
                        builder: (_) => WordColorPickerDialog(selectedColor: _selectedColor),
                      );
                      if (picked != null) setState(() => _selectedColor = picked);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.palette_outlined, size: 18, color: Colors.grey),
                        const SizedBox(width: 6),
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: Color(_selectedColor),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Konum Kartı Widget ──
  Widget _buildLocationCard() {
    final loc = _location!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(loc.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.edit_location_alt_outlined, size: 20, color: Colors.green),
          onPressed: _pickLocation,
          tooltip: 'Konumu Düzenle',
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
          onPressed: () => setState(() => _location = null),
          tooltip: 'Konumu Kaldır',
        ),
      ]),
    );
  }
}

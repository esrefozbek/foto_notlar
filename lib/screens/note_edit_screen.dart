import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../widgets/voice_player_widget.dart';
import '../widgets/voice_recorder_dialog.dart';

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

  String? _audioBase64;
  int? _audioDurationSeconds;

  late int _selectedColor;
  bool _isSaving = false;

  final List<int> _availableColors = const [
    0xFFFFFFFF, // Beyaz
    0xFFFFF9C4, // Yumuşak Sarı
    0xFFFFE0B2, // Şeftali
    0xFFFFCDD2, // Gül Kurusu
    0xFFE1BEE7, // Leylak
    0xFFC5CAE9, // Mavi / İndigo
    0xFFB2EBF2, // Turkuaz
    0xFFC8E6C9, // Nane Yeşili
    0xFFD7CCC8, // Sıcak Gri / Bej
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _selectedColor = widget.note?.colorValue ?? 0xFFFFFFFF;
    _audioBase64 = widget.note?.audioBase64;
    _audioDurationSeconds = widget.note?.audioDurationSeconds;

    if (widget.note != null && widget.note!.imagesBase64.isNotEmpty) {
      for (final b64 in widget.note!.imagesBase64) {
        try {
          final bytes = base64Decode(b64);
          _imagesBytes.add(bytes);
          _imagesBase64.add(b64);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _recordVoiceNote() async {
    final result = await showDialog<VoiceRecordingResult>(
      context: context,
      builder: (_) => const VoiceRecorderDialog(),
    );

    if (result != null) {
      setState(() {
        _audioBase64 = result.audioBase64;
        _audioDurationSeconds = result.durationSeconds;
      });
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraflar seçilirken hata oluştu: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickCameraImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imagesBytes.add(bytes);
          _imagesBase64.add(base64Encode(bytes));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kameradan fotoğraf çekilirken hata oluştu: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(
              children: [
                ListTile(
                  title: Text(
                    _imagesBytes.isEmpty ? 'Fotoğraf Ekle' : 'Daha Fazla Fotoğraf Ekle',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
                  title: const Text('Galeriden Seç (Çoklu Fotoğraf)'),
                  subtitle: const Text('Birden fazla fotoğrafı aynı anda seçebilirsiniz'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickMultipleImages();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.deepOrangeAccent),
                  title: const Text('Kamerayla Yeni Çek'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickCameraImage();
                  },
                ),
                if (_imagesBytes.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                    title: const Text('Tüm Fotoğrafları Kaldır', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _imagesBytes.clear();
                        _imagesBase64.clear();
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

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
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  Positioned(
                    top: 30,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                        onPressed: () {
                          setDialogState(() => currentIndex--);
                        },
                      ),
                    ),
                  if (currentIndex < _imagesBytes.length - 1)
                    Positioned(
                      right: 10,
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white, size: 40),
                        onPressed: () {
                          setDialogState(() => currentIndex++);
                        },
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

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty && _imagesBase64.isEmpty && _audioBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Boş not kaydedilemez!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final noteToSave = Note(
      id: widget.note?.id ?? now.millisecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'Başlıksız Not' : title,
      content: content,
      createdAt: widget.note?.createdAt ?? now,
      updatedAt: now,
      imagesBase64: _imagesBase64,
      audioBase64: _audioBase64,
      audioDurationSeconds: _audioDurationSeconds,
      colorValue: _selectedColor,
    );

    Navigator.pop(context, noteToSave);
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Color(_selectedColor);
    final isDarkBackground = ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark;
    final textColor = isDarkBackground ? Colors.white : Colors.black87;
    final hintColor = isDarkBackground ? Colors.white60 : Colors.black45;

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
          IconButton(
            icon: Icon(
              _audioBase64 != null ? Icons.mic : Icons.mic_none_outlined,
              color: _audioBase64 != null ? Colors.deepPurple : null,
            ),
            tooltip: _audioBase64 != null ? 'Ses Kaydını Yenile' : 'Ses Kaydet',
            onPressed: _recordVoiceNote,
          ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Fotoğraf Ekle (Çoklu)',
            onPressed: _showImagePickerOptions,
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Çoklu Fotoğraf Şeridi (Varsa)
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
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined, size: 36, color: hintColor),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Fotoğraf Ekle',
                                        style: TextStyle(fontSize: 12, color: hintColor, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
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
                                    child: Image.memory(
                                      imageBytes,
                                      width: 210,
                                      height: 210,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${index + 1} / ${_imagesBytes.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                      tooltip: 'Bu Fotoğrafı Sil',
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() {
                                          _imagesBytes.removeAt(index);
                                          _imagesBase64.removeAt(index);
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Ses Kaydı Oynatıcı (Varsa)
                    if (_audioBase64 != null) ...[
                      VoicePlayerWidget(
                        audioBase64: _audioBase64!,
                        durationSeconds: _audioDurationSeconds,
                        accentColor: Colors.deepPurple,
                        onDelete: () {
                          setState(() {
                            _audioBase64 = null;
                            _audioDurationSeconds = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Tarih Bilgisi
                    Text(
                      dateText,
                      style: TextStyle(fontSize: 12, color: hintColor),
                    ),
                    const SizedBox(height: 12),

                    // Başlık Alanı
                    TextField(
                      controller: _titleController,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Başlık',
                        hintStyle: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: hintColor,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 24, thickness: 1),

                    // İçerik Alanı
                    TextField(
                      controller: _contentController,
                      maxLines: null,
                      style: TextStyle(fontSize: 16, height: 1.5, color: textColor),
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

            // Alt Renk Seçim Çubuğu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.palette_outlined, size: 20, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableColors.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final colorVal = _availableColors[index];
                          final isSelected = _selectedColor == colorVal;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = colorVal),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Color(colorVal),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.deepPurple : Colors.grey.shade400,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 18, color: Colors.deepPurple)
                                  : null,
                            ),
                          );
                        },
                      ),
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
}

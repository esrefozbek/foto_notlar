import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../services/note_storage.dart';
import '../services/security_service.dart';
import '../widgets/voice_recorder_dialog.dart';
import 'lock_screen.dart';
import 'note_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> _allNotes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = true;
  bool _isGridView = true;
  bool _isReorderMode = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final notes = await NoteStorage.loadNotes();
    _sortNotes(notes);
    setState(() {
      _allNotes = notes;
      _applyFilter();
      _isLoading = false;
    });
  }

  /// Sıralama: pinliler üstte → orderIndex → güncellenme tarihi
  void _sortNotes(List<Note> notes) {
    notes.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      if (a.orderIndex != b.orderIndex) return a.orderIndex.compareTo(b.orderIndex);
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  void _applyFilter() {
    if (_searchQuery.trim().isEmpty) {
      _filteredNotes = List.from(_allNotes);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredNotes = _allNotes.where((note) {
        return note.title.toLowerCase().contains(q) ||
            note.content.toLowerCase().contains(q) ||
            note.documents.any((d) => d.name.toLowerCase().contains(q)) ||
            note.audios.any((a) => a.name.toLowerCase().contains(q)) ||
            note.videos.any((v) => v.name.toLowerCase().contains(q)) ||
            (note.location?.displayName.toLowerCase().contains(q) ?? false);
      }).toList();
    }
  }

  Future<void> _addNewNote() async {
    final newNote = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (context) => const NoteEditScreen()),
    );
    if (newNote != null) {
      newNote.orderIndex = 0;
      // Mevcut sıralamaları kaydır
      for (final n in _allNotes) {
        n.orderIndex++;
      }
      setState(() {
        _allNotes.insert(0, newNote);
        _sortNotes(_allNotes);
        _applyFilter();
      });
      await NoteStorage.saveNotes(_allNotes);
    }
  }

  Future<void> _editNote(Note note) async {
    final updatedNote = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (context) => NoteEditScreen(note: note)),
    );

    if (updatedNote != null) {
      final index = _allNotes.indexWhere((n) => n.id == updatedNote.id);
      if (index != -1) {
        // orderIndex ve isPinned'i koru
        updatedNote.orderIndex = _allNotes[index].orderIndex;
        updatedNote.isPinned = _allNotes[index].isPinned;
        setState(() {
          _allNotes[index] = updatedNote;
          _sortNotes(_allNotes);
          _applyFilter();
        });
        await NoteStorage.saveNotes(_allNotes);
      }
    } else {
      // Medya aktarımı yapılmış olabilir
      _loadNotes();
    }
  }

  Future<void> _togglePin(Note note) async {
    setState(() {
      note.isPinned = !note.isPinned;
      _sortNotes(_allNotes);
      _applyFilter();
    });
    await NoteStorage.saveNotes(_allNotes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(note.isPinned ? '📌 Not sabitlendi' : 'Sabitleme kaldırıldı'),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  Future<void> _deleteNote(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notu Sil'),
        content: Text('"${note.title}" başlıklı notu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _allNotes.removeWhere((n) => n.id == note.id);
        _applyFilter();
      });
      await NoteStorage.saveNotes(_allNotes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not silindi.')));
      }
    }
  }

  // ── Sürükle-bırak sıralama ───────────────────────────────────────────────
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final note = _filteredNotes.removeAt(oldIndex);
      _filteredNotes.insert(newIndex, note);
      // orderIndex güncelle
      for (int i = 0; i < _filteredNotes.length; i++) {
        _filteredNotes[i].orderIndex = i;
      }
      // _allNotes'u da senkronize et
      _allNotes = List.from(_filteredNotes);
    });
    NoteStorage.saveNotes(_allNotes);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HIZLI EYLEMLER
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _quickVoiceNote() async {
    final result = await showDialog<VoiceRecordingResult>(
      context: context,
      builder: (_) => const VoiceRecorderDialog(),
    );
    if (result != null) {
      final now = DateTime.now();
      final dateStr = DateFormat('d MMMM, HH:mm', 'tr_TR').format(now);
      final newNote = Note(
        id: now.millisecondsSinceEpoch.toString(),
        title: 'Sesli Not - $dateStr',
        content: '',
        createdAt: now,
        updatedAt: now,
        audios: [AudioItem(id: 'audio_${now.millisecondsSinceEpoch}', name: 'Ses Kaydı 1', base64Data: result.audioBase64, durationSeconds: result.durationSeconds)],
        colorValue: 0xFFE1BEE7,
      );
      await _insertQuickNote(newNote);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hızlı sesli not oluşturuldu!')));
    }
  }

  Future<void> _quickPhotoNote() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(children: [
              const ListTile(title: Text('Hızlı Fotoğraf Çek / Seç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.deepOrangeAccent),
                title: const Text('Kamerayla Yeni Çek'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
                title: const Text('Galeriden Seç'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ]),
          ),
        ),
      );
      if (source == null) return;
      final XFile? file = await _picker.pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 85);
      if (file != null) {
        final bytes = await file.readAsBytes();
        final now = DateTime.now();
        final dateStr = DateFormat('d MMMM, HH:mm', 'tr_TR').format(now);
        final newNote = Note(
          id: now.millisecondsSinceEpoch.toString(),
          title: 'Fotoğraf Notu - $dateStr',
          content: '',
          createdAt: now,
          updatedAt: now,
          imagesBase64: [base64Encode(bytes)],
          colorValue: 0xFFFFF9C4,
        );
        await _insertQuickNote(newNote);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraflı hızlı not oluşturuldu!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fotoğraf eklenirken hata: $e')));
    }
  }

  Future<void> _quickVideoNote() async {
    try {
      final source = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(children: [
              const ListTile(title: Text('Hızlı Video Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.redAccent),
                  title: const Text('Kamerayla Video Kaydet'),
                  onTap: () => Navigator.pop(ctx, 'camera'),
                ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.blueAccent),
                title: const Text('Galeriden Video Seç'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open, color: Colors.orange),
                title: const Text('Dosyadan Ekle (MP4, MOV...)'),
                onTap: () => Navigator.pop(ctx, 'file'),
              ),
            ]),
          ),
        ),
      );

      if (source == null) return;

      XFile? videoFile;
      List<int>? fileBytes;
      String? fileName;

      if (source == 'camera') {
        videoFile = await _picker.pickVideo(source: ImageSource.camera);
      } else if (source == 'gallery') {
        videoFile = await _picker.pickVideo(source: ImageSource.gallery);
      } else {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'webm'],
        );
        if (files.isNotEmpty) {
          final f = files.first;
          fileBytes = (await f.readAsBytes()).toList();
          fileName = f.name;
        }
      }

      List<int>? bytes = fileBytes;
      String? name = fileName;

      if (videoFile != null) {
        bytes = (await videoFile.readAsBytes()).toList();
        name = videoFile.name;
      }

      if (bytes != null && name != null) {
        final now = DateTime.now();
        final dateStr = DateFormat('d MMMM, HH:mm', 'tr_TR').format(now);
        final newNote = Note(
          id: now.millisecondsSinceEpoch.toString(),
          title: 'Video Notu - $dateStr',
          content: '',
          createdAt: now,
          updatedAt: now,
          videos: [VideoItem(id: 'video_${now.millisecondsSinceEpoch}', name: name, base64Data: base64Encode(bytes), sizeBytes: bytes.length)],
          colorValue: 0xFFFFCDD2,
        );
        await _insertQuickNote(newNote);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video notu oluşturuldu!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video eklenirken hata: $e')));
    }
  }

  Future<void> _quickDocumentNote() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'csv', 'pptx'],
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final size = (await file.length()) ?? bytes.length;
        final now = DateTime.now();
        final ext = file.extension ?? (file.name.contains('.') ? file.name.split('.').last : 'file');
        final newNote = Note(
          id: now.millisecondsSinceEpoch.toString(),
          title: file.name,
          content: '',
          createdAt: now,
          updatedAt: now,
          documents: [DocumentItem(id: 'doc_${now.millisecondsSinceEpoch}', name: file.name, extension: ext.toLowerCase(), sizeBytes: size, base64Data: base64Encode(bytes))],
          colorValue: 0xFFE0F2F1,
        );
        await _insertQuickNote(newNote);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Belge notu oluşturuldu!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Belge eklenirken hata: $e')));
    }
  }

  Future<void> _insertQuickNote(Note note) async {
    setState(() {
      _allNotes.insert(0, note);
      _sortNotes(_allNotes);
      _applyFilter();
    });
    await NoteStorage.saveNotes(_allNotes);
  }

  // ── Güvenlik ──────────────────────────────────────────────────────────────
  Future<void> _showSecuritySettings() async {
    final isPinSet = await SecurityService.isPinSet();
    final hasBiometrics = await SecurityService.isBiometricsAvailable();
    bool biometricsEnabled = await SecurityService.isBiometricsEnabled();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(children: [
              const ListTile(
                leading: Icon(Icons.shield_outlined, color: Colors.deepPurple, size: 28),
                title: Text('Güvenlik & Kilit Ayarları', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const Divider(),
              if (isPinSet) ...[
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: Colors.blueAccent),
                  title: const Text('PIN Kodunu Değiştir'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const LockScreen(mode: LockScreenMode.changePin, canCancel: true),
                    ));
                  },
                ),
                if (hasBiometrics)
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint, color: Colors.deepPurple),
                    title: const Text('Parmak İzi ile Giriş'),
                    value: biometricsEnabled,
                    onChanged: (val) async {
                      await SecurityService.setBiometricsEnabled(val);
                      setModalState(() => biometricsEnabled = val);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: Colors.orangeAccent),
                  title: const Text('Uygulamayı Hemen Kilitle'),
                  onTap: () { Navigator.pop(ctx); _lockApp(); },
                ),
                ListTile(
                  leading: const Icon(Icons.no_encryption_outlined, color: Colors.redAccent),
                  title: const Text('PIN Kilidini Kaldır', style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('PIN Kilidini Kaldır'),
                        content: const Text('PIN kilidini kaldırmak istediğinize emin misiniz?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Kaldır', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) await SecurityService.removePin();
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: Colors.deepPurple),
                  title: const Text('PIN Kilidi Oluştur'),
                  subtitle: const Text('Notlarınızı korumak için 4 haneli şifre belirleyin'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const LockScreen(mode: LockScreenMode.setup, canCancel: true),
                    ));
                  },
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  void _lockApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LockScreen(
          mode: LockScreenMode.unlock,
          onSuccess: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notlarım', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Sırala modu
          IconButton(
            icon: Icon(_isReorderMode ? Icons.check_circle_rounded : Icons.swap_vert_rounded,
                color: _isReorderMode ? Colors.green : null),
            tooltip: _isReorderMode ? 'Sıralamayı Bitir' : 'Sürükleyerek Sırala',
            onPressed: () => setState(() => _isReorderMode = !_isReorderMode),
          ),
          // Grid/List toggle
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            tooltip: _isGridView ? 'Liste Görünümü' : 'Izgara Görünümü',
            onPressed: () => setState(() { _isGridView = !_isGridView; _isReorderMode = false; }),
          ),
          // Güvenlik
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Güvenlik Ayarları',
            onPressed: _showSecuritySettings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama çubuğu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Notlarda ara...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() { _searchQuery = ''; _applyFilter(); }); })
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onChanged: (v) => setState(() { _searchQuery = v; _applyFilter(); }),
            ),
          ),

          // Notlar
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotes.isEmpty
                    ? _buildEmptyState()
                    : _isReorderMode
                        ? _buildReorderList()
                        : (_isGridView ? _buildGridView() : _buildListView()),
          ),
        ],
      ),

      // Alt Hızlı Eylem Paneli
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -3))],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickButton(icon: Icons.mic_rounded, label: 'Ses', color: Colors.purple.shade700, onTap: _quickVoiceNote),
              _buildQuickButton(icon: Icons.camera_alt_rounded, label: 'Foto', color: Colors.orange.shade800, onTap: _quickPhotoNote),
              _buildQuickButton(icon: Icons.videocam_rounded, label: 'Video', color: Colors.red.shade700, onTap: _quickVideoNote),
              _buildQuickButton(icon: Icons.attach_file_rounded, label: 'Belge', color: Colors.blue.shade700, onTap: _quickDocumentNote),
              // Yeni Not butonu
              InkWell(
                onTap: _addNewNote,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.deepPurple.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text('Yeni Not', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isSearching ? Icons.search_off_rounded : Icons.note_add_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            isSearching ? 'Eşleşen not bulunamadı' : 'Henüz not eklemediniz',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching ? 'Farklı bir arama terimi deneyebilirsiniz.' : 'Aşağıdaki panelden anında ses, foto veya belge ekleyerek başlayın!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ]),
      ),
    );
  }

  // ── Sürükle-bırak ─────────────────────────────────────────────────────────
  Widget _buildReorderList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredNotes.length,
      onReorderItem: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex),
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        return Padding(
          key: ValueKey(note.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            color: Color(note.colorValue),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Icon(note.isPinned ? Icons.push_pin_rounded : Icons.drag_handle_rounded,
                  color: note.isPinned ? Colors.deepPurple : Colors.grey),
              title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(note.content, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.drag_indicator_rounded, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  // ── Grid ──────────────────────────────────────────────────────────────────
  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.76,
          ),
          itemCount: _filteredNotes.length,
          itemBuilder: (context, index) => _buildNoteCard(_filteredNotes[index]),
        );
      },
    );
  }

  // ── List ──────────────────────────────────────────────────────────────────
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: _buildNoteCard(_filteredNotes[index], isCompact: true),
      ),
    );
  }

  // ── Not Kartı ─────────────────────────────────────────────────────────────
  Widget _buildNoteCard(Note note, {bool isCompact = false}) {
    Uint8List? imageBytes;
    final firstImg = note.firstImage;
    if (firstImg != null && firstImg.isNotEmpty) {
      try { imageBytes = base64Decode(firstImg); } catch (_) {}
    }

    final cardColor = Color(note.colorValue);
    final isDark = ThemeData.estimateBrightnessForColor(cardColor) == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    // Medya rozetleri
    Widget buildBadges() => Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        if (note.hasAudio) _badge(Icons.graphic_eq_rounded, '${note.audios.length} Ses', Colors.purple),
        if (note.hasDocuments) _badge(Icons.attach_file_rounded, '${note.documents.length} Belge', Colors.blue),
        if (note.hasVideos) _badge(Icons.videocam_rounded, '${note.videos.length} Video', Colors.red),
        if (note.hasLocation) _badge(Icons.location_on_rounded, 'Konum', Colors.green),
      ],
    );

    return GestureDetector(
      onLongPress: () => _showNoteOptions(note),
      child: Card(
        color: cardColor,
        elevation: note.isPinned ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: note.isPinned ? Colors.deepPurple.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.2),
            width: note.isPinned ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _editNote(note),
          child: isCompact
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (imageBytes != null)
                    SizedBox(
                      width: 100, height: 100,
                      child: Stack(fit: StackFit.expand, children: [
                        Image.memory(imageBytes, fit: BoxFit.cover),
                        if (note.imagesBase64.length > 1)
                          Positioned(
                            bottom: 4, right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(8)),
                              child: Text('+${note.imagesBase64.length - 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ]),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          if (note.isPinned) ...[const Icon(Icons.push_pin_rounded, size: 14, color: Colors.deepPurple), const SizedBox(width: 4)],
                          Expanded(child: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor))),
                        ]),
                        if (note.hasAudio || note.hasDocuments || note.hasVideos || note.hasLocation) ...[
                          const SizedBox(height: 4), buildBadges(),
                        ],
                        const SizedBox(height: 4),
                        Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: secondaryTextColor)),
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(DateFormat('d MMM yyyy, HH:mm', 'tr_TR').format(note.updatedAt),
                              style: TextStyle(fontSize: 11, color: secondaryTextColor)),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 18, color: secondaryTextColor),
                            onPressed: () => _deleteNote(note),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (imageBytes != null)
                    Expanded(
                      flex: 4,
                      child: Stack(fit: StackFit.expand, children: [
                        Image.memory(imageBytes, fit: BoxFit.cover),
                        if (note.isPinned)
                          Positioned(top: 6, left: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: Colors.deepPurple.withValues(alpha: 0.85), shape: BoxShape.circle),
                                child: const Icon(Icons.push_pin_rounded, size: 12, color: Colors.white),
                              )),
                        if (note.imagesBase64.length > 1)
                          Positioned(bottom: 6, right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(10)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.photo_library, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text('+${note.imagesBase64.length - 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ]),
                              )),
                      ]),
                    ),

                  Expanded(
                    flex: imageBytes != null ? 3 : 5,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          if (note.isPinned && imageBytes == null) ...[
                            const Icon(Icons.push_pin_rounded, size: 14, color: Colors.deepPurple),
                            const SizedBox(width: 4),
                          ],
                          Expanded(child: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor))),
                        ]),
                        if (note.hasAudio || note.hasDocuments || note.hasVideos || note.hasLocation) ...[
                          const SizedBox(height: 3), buildBadges(),
                        ],
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(note.content, maxLines: imageBytes != null ? 2 : 4, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: secondaryTextColor)),
                        ),
                        const SizedBox(height: 4),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(DateFormat('d MMM yyyy', 'tr_TR').format(note.updatedAt),
                              style: TextStyle(fontSize: 10, color: secondaryTextColor)),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 18, color: secondaryTextColor),
                            onPressed: () => _deleteNote(note),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color.shade700),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color.shade700)),
      ]),
    );
  }

  // ── Uzun basınca seçenekler ───────────────────────────────────────────────
  void _showNoteOptions(Note note) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.deepPurple),
              title: const Text('Düzenle'),
              onTap: () { Navigator.pop(ctx); _editNote(note); },
            ),
            ListTile(
              leading: Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  color: Colors.deepPurple),
              title: Text(note.isPinned ? 'Sabitlik Kaldır' : 'En Üste Sabitle'),
              onTap: () { Navigator.pop(ctx); _togglePin(note); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
              onTap: () { Navigator.pop(ctx); _deleteNote(note); },
            ),
          ]),
        ),
      ),
    );
  }
}

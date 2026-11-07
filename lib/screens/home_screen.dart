import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../services/note_storage.dart';
import '../services/security_service.dart';
import 'lock_screen.dart';
import 'note_edit_screen.dart';
import '../widgets/voice_recorder_dialog.dart';

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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
    // En yeni not en üstte olacak şekilde sırala
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    setState(() {
      _allNotes = notes;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    if (_searchQuery.trim().isEmpty) {
      _filteredNotes = List.from(_allNotes);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredNotes = _allNotes.where((note) {
        return note.title.toLowerCase().contains(q) ||
            note.content.toLowerCase().contains(q);
      }).toList();
    }
  }

  Future<void> _addNewNote() async {
    final newNote = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (context) => const NoteEditScreen()),
    );

    if (newNote != null) {
      setState(() {
        _allNotes.insert(0, newNote);
        _applyFilter();
      });
      await NoteStorage.saveNotes(_allNotes);
    }
  }

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
        audioBase64: result.audioBase64,
        audioDurationSeconds: result.durationSeconds,
        colorValue: 0xFFE1BEE7,
      );

      setState(() {
        _allNotes.insert(0, newNote);
        _applyFilter();
      });
      await NoteStorage.saveNotes(_allNotes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hızlı sesli not kaydedildi!')),
        );
      }
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
        setState(() {
          _allNotes[index] = updatedNote;
          // Güncellenen notu başa al
          _allNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          _applyFilter();
        });
        await NoteStorage.saveNotes(_allNotes);
      }
    }
  }

  Future<void> _deleteNote(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notu Sil'),
        content: Text('"${note.title}" başlıklı notu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not silindi.')),
        );
      }
    }
  }

  Future<void> _showSecuritySettings() async {
    final isPinSet = await SecurityService.isPinSet();
    final hasBiometrics = await SecurityService.isBiometricsAvailable();
    bool biometricsEnabled = await SecurityService.isBiometricsEnabled();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(
              children: [
                const ListTile(
                  leading: Icon(Icons.shield_outlined, color: Colors.deepPurple, size: 28),
                  title: Text(
                    'Güvenlik & Kilit Ayarları',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const Divider(),
                if (isPinSet) ...[
                  ListTile(
                    leading: const Icon(Icons.lock_reset, color: Colors.blueAccent),
                    title: const Text('PIN Kodunu Değiştir'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LockScreen(
                            mode: LockScreenMode.changePin,
                            canCancel: true,
                          ),
                        ),
                      );
                    },
                  ),
                  if (hasBiometrics)
                    SwitchListTile(
                      secondary: const Icon(Icons.fingerprint, color: Colors.deepPurple),
                      title: const Text('Parmak İzi ile Giriş'),
                      subtitle: const Text('Uygulama açılırken parmak izini kullan'),
                      value: biometricsEnabled,
                      onChanged: (val) async {
                        await SecurityService.setBiometricsEnabled(val);
                        setModalState(() => biometricsEnabled = val);
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Colors.orangeAccent),
                    title: const Text('Uygulamayı Hemen Kilitle'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _lockApp();
                    },
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
                          content: const Text('PIN kilidini kaldırmak istediğinize emin misiniz? Herkes notlarınıza doğrudan erişebilecek.'),
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
                      if (confirm == true) {
                        await SecurityService.removePin();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PIN kilidi kaldırıldı.')),
                          );
                        }
                      }
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Colors.deepPurple),
                    title: const Text('PIN Kilidi Oluştur'),
                    subtitle: const Text('Notlarınızı korumak için 4 haneli şifre belirleyin'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LockScreen(
                            mode: LockScreenMode.setup,
                            canCancel: true,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.photo_library_outlined, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text(
              'Fotoğraflı Notlar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded),
            tooltip: _isGridView ? 'Liste Görünümü' : 'Izgara Görünümü',
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Güvenlik & Kilit Ayarları',
            onPressed: _showSecuritySettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Arama Çubuğu
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _applyFilter();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Notlarda ara...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _applyFilter();
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),

                // Not Listesi veya Boş Durum
                Expanded(
                  child: _filteredNotes.isEmpty
                      ? _buildEmptyState()
                      : (_isGridView ? _buildGridView() : _buildListView()),
                ),
              ],
            ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'quick_voice_btn',
            onPressed: _quickVoiceNote,
            backgroundColor: Colors.deepPurple.shade100,
            foregroundColor: Colors.deepPurple,
            tooltip: 'Hızlı Sesli Not Al',
            child: const Icon(Icons.mic),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'add_note_btn',
            onPressed: _addNewNote,
            icon: const Icon(Icons.add),
            label: const Text('Not Ekle'),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSearching ? Icons.search_off_rounded : Icons.note_add_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                isSearching ? 'Eşleşen not bulunamadı' : 'Henüz not eklemediniz',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSearching
                    ? 'Farklı bir arama terimi deneyebilirsiniz.'
                    : 'Aşağıdaki "Not Ekle" butonuna dokunarak fotoğraflı ilk notunuzu oluşturun!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Geniş ekranlarda (örn. web tarayıcısı tam ekran) kolon sayısını otomatik ayarla
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 3
                : 2;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: _filteredNotes.length,
          itemBuilder: (context, index) {
            final note = _filteredNotes[index];
            return _buildNoteCard(note);
          },
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildNoteCard(note, isCompactList: true),
        );
      },
    );
  }

  Widget _buildNoteCard(Note note, {bool isCompactList = false}) {
    Uint8List? imageBytes;
    final firstImg = note.firstImage;
    if (firstImg != null && firstImg.isNotEmpty) {
      try {
        imageBytes = base64Decode(firstImg);
      } catch (_) {
        imageBytes = null;
      }
    }

    final cardColor = Color(note.colorValue);
    final isDark = ThemeData.estimateBrightnessForColor(cardColor) == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editNote(note),
        child: isCompactList
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageBytes != null)
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            imageBytes,
                            fit: BoxFit.cover,
                          ),
                          if (note.imagesBase64.length > 1)
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '+${note.imagesBase64.length - 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          if (note.hasAudio) ...[
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mic, size: 13, color: textColor),
                                const SizedBox(width: 3),
                                Text(
                                  note.audioDurationSeconds != null
                                      ? '${(note.audioDurationSeconds! ~/ 60).toString().padLeft(2, '0')}:${(note.audioDurationSeconds! % 60).toString().padLeft(2, '0')}'
                                      : 'Ses Kaydı',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            note.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: secondaryTextColor),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('d MMM yyyy, HH:mm', 'tr_TR').format(note.updatedAt),
                                style: TextStyle(fontSize: 11, color: secondaryTextColor),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 18, color: secondaryTextColor),
                                onPressed: () => _deleteNote(note),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fotoğraf Varsa
                  if (imageBytes != null)
                    Expanded(
                      flex: 4,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            imageBytes,
                            fit: BoxFit.cover,
                          ),
                          if (note.imagesBase64.length > 1)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.photo_library, size: 12, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${note.imagesBase64.length - 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Metin İçeriği
                  Expanded(
                    flex: imageBytes != null ? 3 : 5,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          if (note.hasAudio) ...[
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mic, size: 13, color: textColor),
                                const SizedBox(width: 3),
                                Text(
                                  note.audioDurationSeconds != null
                                      ? '${(note.audioDurationSeconds! ~/ 60).toString().padLeft(2, '0')}:${(note.audioDurationSeconds! % 60).toString().padLeft(2, '0')}'
                                      : 'Ses Kaydı',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              note.content,
                              maxLines: imageBytes != null ? 2 : 5,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: secondaryTextColor),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('d MMM yyyy', 'tr_TR').format(note.updatedAt),
                                style: TextStyle(fontSize: 10, color: secondaryTextColor),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 18, color: secondaryTextColor),
                                onPressed: () => _deleteNote(note),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

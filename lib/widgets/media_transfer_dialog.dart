import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../services/note_storage.dart';

class MediaTransferResult {
  final String targetNoteId;
  final bool isMove; // true: Taşı (orijinalden sil), false: Kopyala (orijinalde kalsın)

  MediaTransferResult({
    required this.targetNoteId,
    required this.isMove,
  });
}

class MediaTransferDialog extends StatefulWidget {
  final String? currentNoteId;
  final String mediaType; // "Fotoğraf", "Ses Kaydı", "Belge"
  final String mediaName;

  const MediaTransferDialog({
    super.key,
    this.currentNoteId,
    required this.mediaType,
    required this.mediaName,
  });

  @override
  State<MediaTransferDialog> createState() => _MediaTransferDialogState();
}

class _MediaTransferDialogState extends State<MediaTransferDialog> {
  List<Note> _availableNotes = [];
  bool _isLoading = true;
  String? _selectedNoteId;
  bool _isMove = false; // Varsayılan Kopyala
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOtherNotes();
  }

  Future<void> _loadOtherNotes() async {
    final allNotes = await NoteStorage.loadNotes();
    final filtered = allNotes.where((n) => n.id != widget.currentNoteId).toList();
    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (mounted) {
      setState(() {
        _availableNotes = filtered;
        _isLoading = false;
        if (filtered.isNotEmpty) {
          _selectedNoteId = filtered.first.id;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _searchQuery.isEmpty
        ? _availableNotes
        : _availableNotes
            .where((n) =>
                n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                n.content.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.drive_file_move_outlined, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.mediaType} Aktar',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: _isLoading
            ? const Center(child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ))
            : _availableNotes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Text(
                      'Aktarma yapabileceğiniz başka bir kayıtlı not bulunamadı. Lütfen önce başka bir not oluşturun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seçilen: ${widget.mediaName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),

                      // İşlem Türü (Kopyala mı Taşı mı?)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isMove = false),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !_isMove ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: !_isMove
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Kopyala',
                                    style: TextStyle(
                                      fontWeight: !_isMove ? FontWeight.bold : FontWeight.normal,
                                      color: !_isMove ? Colors.deepPurple : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isMove = true),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isMove ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: _isMove
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Taşı (Buradan Sil)',
                                    style: TextStyle(
                                      fontWeight: _isMove ? FontWeight.bold : FontWeight.normal,
                                      color: _isMove ? Colors.deepOrange : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text('Hedef Notu Seçin:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),

                      // Arama
                      if (_availableNotes.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Not ara...',
                              isDense: true,
                              prefixIcon: const Icon(Icons.search, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),

                      // Not Listesi
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredList.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final note = filteredList[index];
                            final isSelected = note.id == _selectedNoteId;
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              selected: isSelected,
                              selectedTileColor: Colors.deepPurple.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              title: Text(
                                note.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.deepPurple : Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat('d MMM yyyy, HH:mm', 'tr_TR').format(note.updatedAt),
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: Colors.deepPurple, size: 20)
                                  : const Icon(Icons.radio_button_unchecked, size: 20, color: Colors.grey),
                              onTap: () => setState(() => _selectedNoteId = note.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Vazgeç'),
        ),
        if (_availableNotes.isNotEmpty)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isMove ? Colors.deepOrange : Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _selectedNoteId != null
                ? () {
                    Navigator.pop(
                      context,
                      MediaTransferResult(
                        targetNoteId: _selectedNoteId!,
                        isMove: _isMove,
                      ),
                    );
                  }
                : null,
            child: Text(_isMove ? 'Taşı' : 'Kopyala'),
          ),
      ],
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/note.dart';

class VideoListWidget extends StatefulWidget {
  final List<VideoItem> videos;
  final Function(int index) onDelete;
  final Function(int index, String newName) onRename;
  final Function(int index)? onTransfer;

  const VideoListWidget({
    super.key,
    required this.videos,
    required this.onDelete,
    required this.onRename,
    this.onTransfer,
  });

  @override
  State<VideoListWidget> createState() => _VideoListWidgetState();
}

class _VideoListWidgetState extends State<VideoListWidget> {

  void _showRenameDialog(int index) {
    final ctrl = TextEditingController(text: widget.videos[index].name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Video Adını Değiştir'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Video Adı')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) widget.onRename(index, v);
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _openVideoPlayer(VideoItem video) {
    showDialog(
      context: context,
      builder: (ctx) => _VideoPlayerDialog(video: video),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.videocam_rounded, size: 18, color: Colors.red),
          const SizedBox(width: 6),
          Text(
            'Videolar (${widget.videos.length})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ]),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.videos.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final video = widget.videos[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                // Thumbnail / Play icon
                InkWell(
                  onTap: () => _openVideoPlayer(video),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(width: 12),

                // Bilgi
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      video.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('VİDEO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
                      ),
                      const SizedBox(width: 6),
                      Text(_formatSize(video.sizeBytes), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      if (video.durationSeconds > 0) ...[
                        const SizedBox(width: 6),
                        Text(_formatDuration(video.durationSeconds), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ]),
                  ]),
                ),

                // Menü
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'play') {
                      _openVideoPlayer(video);
                    } else if (val == 'rename') {
                      _showRenameDialog(index);
                    } else if (val == 'transfer') {
                      widget.onTransfer?.call(index);
                    } else if (val == 'delete') {
                      widget.onDelete(index);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'play', child: Row(children: [Icon(Icons.play_arrow_rounded, size: 18), SizedBox(width: 8), Text('Oynat')])),
                    const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Yeniden Adlandır')])),
                    if (widget.onTransfer != null)
                      const PopupMenuItem(value: 'transfer', child: Row(children: [Icon(Icons.drive_file_move_outlined, size: 18), SizedBox(width: 8), Text('Başka Nota Kopyala / Taşı')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), SizedBox(width: 8), Text('Sil', style: TextStyle(color: Colors.redAccent))])),
                  ],
                ),
              ]),
            );
          },
        ),
      ],
    );
  }
}

// ── Video Oynatıcı Dialog ─────────────────────────────────────────────────────
class _VideoPlayerDialog extends StatefulWidget {
  final VideoItem video;
  const _VideoPlayerDialog({required this.video});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  bool _isLoading = true;
  String? _errorMsg;
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _prepareVideo();
  }

  Future<void> _prepareVideo() async {
    try {
      if (kIsWeb) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Web\'de video oynatma için harici player gereklidir.';
        });
        return;
      }

      final bytes = base64Decode(widget.video.base64Data);
      final dir = Directory.systemTemp;
      final cleanName = widget.video.name.replaceAll(RegExp(r'[\\/:"*?<>|]'), '_');
      final f = File('${dir.path}/tmp_$cleanName');
      await f.writeAsBytes(bytes);
      setState(() {
        _tempFile = f;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Video hazırlanamadı: $e';
      });
    }
  }

  @override
  void dispose() {
    _tempFile?.delete().catchError((_) => _tempFile!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.video.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Colors.white))
            else if (_errorMsg != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(_errorMsg!, style: const TextStyle(color: Colors.orangeAccent), textAlign: TextAlign.center),
              )
            else ...[
              const Icon(Icons.movie_rounded, size: 80, color: Colors.white54),
              const SizedBox(height: 12),
              const Text('Video dosyası hazır.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Sistem Oynatıcısında Aç'),
                onPressed: () async {
                  if (_tempFile != null) {
                    // open_filex ile açmaya çalış
                    try {
                      // ignore: depend_on_referenced_packages
                      Navigator.pop(context);
                    } catch (_) {}
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../models/note.dart';

class VideoListWidget extends StatelessWidget {
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

  void _showRenameDialog(BuildContext context, int index) {
    final ctrl = TextEditingController(text: videos[index].name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Video Adını Değiştir'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Video Adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) onRename(index, v);
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _openVideoPlayer(BuildContext context, VideoItem video) {
    showDialog(
      context: context,
      builder: (ctx) => VideoPlayerDialog(video: video),
    );
  }

  Future<void> _openInSystemPlayer(BuildContext context, VideoItem video) async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web ortamında sistem oynatıcısı desteklenmez, dahili oynatıcıyı kullanın.')),
        );
        return;
      }
      final bytes = base64Decode(video.base64Data);
      final tempDir = await getTemporaryDirectory();
      final cleanName = video.name.replaceAll(RegExp(r'[\\/:"*?<>|]'), '_');
      final ext = cleanName.contains('.') ? '' : '.mp4';
      final file = File('${tempDir.path}/video_${video.id}_$cleanName$ext');
      if (!await file.exists() || await file.length() != bytes.length) {
        await file.writeAsBytes(bytes);
      }
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video açılamadı: ${result.message}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video açılırken hata: $e')),
        );
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.videocam_rounded, size: 20, color: Colors.red),
          const SizedBox(width: 6),
          Text(
            'Videolar (${videos.length})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ]),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: videos.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final video = videos[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                // Oynat butonu
                InkWell(
                  onTap: () => _openVideoPlayer(context, video),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(width: 12),

                // Bilgiler
                Expanded(
                  child: InkWell(
                    onTap: () => _openVideoPlayer(context, video),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 3),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('MP4 / VİDEO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
                          ),
                          if (video.sizeBytes > 0) ...[
                            const SizedBox(width: 6),
                            Text(_formatSize(video.sizeBytes), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ]),
                      ],
                    ),
                  ),
                ),

                // Menü
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'play') {
                      _openVideoPlayer(context, video);
                    } else if (val == 'open_system') {
                      _openInSystemPlayer(context, video);
                    } else if (val == 'rename') {
                      _showRenameDialog(context, index);
                    } else if (val == 'transfer') {
                      onTransfer?.call(index);
                    } else if (val == 'delete') {
                      onDelete(index);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'play',
                      child: Row(children: [Icon(Icons.play_arrow_rounded, size: 18, color: Colors.red), SizedBox(width: 8), Text('Uygulamada Oynat')]),
                    ),
                    if (!kIsWeb)
                      const PopupMenuItem(
                        value: 'open_system',
                        child: Row(children: [Icon(Icons.open_in_new_rounded, size: 18), SizedBox(width: 8), Text('Cihaz Oynatıcısında Aç')]),
                      ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Yeniden Adlandır')]),
                    ),
                    if (onTransfer != null)
                      const PopupMenuItem(
                        value: 'transfer',
                        child: Row(children: [Icon(Icons.drive_file_move_outlined, size: 18), SizedBox(width: 8), Text('Başka Nota Kopyala / Taşı')]),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), SizedBox(width: 8), Text('Sil', style: TextStyle(color: Colors.redAccent))]),
                    ),
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

// ── Gerçek Video Oynatıcı Dialog ─────────────────────────────────────────────
class VideoPlayerDialog extends StatefulWidget {
  final VideoItem video;
  const VideoPlayerDialog({super.key, required this.video});

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _errorMsg;
  String? _cachedFilePath;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
  }

  Future<void> _initVideoPlayer() async {
    try {
      final bytes = base64Decode(widget.video.base64Data);

      if (kIsWeb) {
        final uri = Uri.dataFromBytes(bytes, mimeType: 'video/mp4');
        _controller = VideoPlayerController.networkUrl(uri);
      } else {
        final tempDir = await getTemporaryDirectory();
        final cleanName = widget.video.name.replaceAll(RegExp(r'[\\/:"*?<>|]'), '_');
        final ext = cleanName.contains('.') ? '' : '.mp4';
        final file = File('${tempDir.path}/play_${widget.video.id}_$cleanName$ext');
        if (!await file.exists() || await file.length() != bytes.length) {
          await file.writeAsBytes(bytes);
        }
        _cachedFilePath = file.path;
        _controller = VideoPlayerController.file(file);
      }

      await _controller!.initialize();
      _controller!.addListener(_onControllerUpdate);
      _controller!.play();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Video yüklenirken hata oluştu: $e';
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _openExternal() async {
    if (_cachedFilePath != null) {
      await OpenFilex.open(_cachedFilePath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasController = _controller != null && _controller!.value.isInitialized;
    final isPlaying = hasController && _controller!.value.isPlaying;
    final position = hasController ? _controller!.value.position : Duration.zero;
    final duration = hasController ? _controller!.value.duration : Duration.zero;

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık Çubuğu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black87,
            child: Row(children: [
              const Icon(Icons.videocam_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.video.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!kIsWeb && _cachedFilePath != null)
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20),
                  tooltip: 'Cihaz Oynatıcısında Aç',
                  onPressed: _openExternal,
                ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // Video Alanı
          if (_isLoading)
            const SizedBox(
              height: 250,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.redAccent),
                    SizedBox(height: 12),
                    Text('Video yükleniyor...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            )
          else if (_errorMsg != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(_errorMsg!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  if (!kIsWeb && _cachedFilePath != null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Yine de Dış Oynatıcıda Dene'),
                      onPressed: _openExternal,
                    ),
                ],
              ),
            )
          else if (hasController) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio > 0 ? _controller!.value.aspectRatio : 16 / 9,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller!),
                    // Ortadaki oynat/duraklat tıklama katmanı
                    GestureDetector(
                      onTap: () {
                        if (isPlaying) {
                          _controller!.pause();
                        } else {
                          _controller!.play();
                        }
                      },
                      child: Container(
                        color: Colors.transparent,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: isPlaying ? 0.0 : 0.8,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.play_arrow_rounded, size: 48, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Kontrol Paneli
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // İlerleme Çubuğu
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: Colors.redAccent,
                      thumbColor: Colors.redAccent,
                      inactiveTrackColor: Colors.white24,
                    ),
                    child: Slider(
                      value: duration.inMilliseconds > 0
                          ? position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble()
                          : 0.0,
                      max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                      onChanged: (val) {
                        _controller!.seekTo(Duration(milliseconds: val.toInt()));
                      },
                    ),
                  ),

                  // Alt Kontrol Butonları & Süre
                  Row(
                    children: [
                      // Oynat / Duraklat
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            _controller!.pause();
                          } else {
                            _controller!.play();
                          }
                        },
                      ),

                      // Yeniden Başlat
                      IconButton(
                        icon: const Icon(Icons.replay_rounded, color: Colors.white70, size: 22),
                        tooltip: 'Başa Sar',
                        onPressed: () {
                          _controller!.seekTo(Duration.zero);
                          _controller!.play();
                        },
                      ),

                      // Ses Aç / Kapa
                      IconButton(
                        icon: Icon(
                          _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            _isMuted = !_isMuted;
                            _controller!.setVolume(_isMuted ? 0.0 : 1.0);
                          });
                        },
                      ),

                      const Spacer(),

                      // Süre: 00:15 / 01:23
                      Text(
                        '${_formatDuration(position)} / ${_formatDuration(duration)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

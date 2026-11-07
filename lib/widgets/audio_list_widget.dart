import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/note.dart';

class AudioListWidget extends StatefulWidget {
  final List<AudioItem> audios;
  final Function(int index) onDelete;
  final Function(int index, String newName) onRename;
  final Function(int index)? onTransfer;
  final Color? accentColor;

  const AudioListWidget({
    super.key,
    required this.audios,
    required this.onDelete,
    required this.onRename,
    this.onTransfer,
    this.accentColor,
  });

  @override
  State<AudioListWidget> createState() => _AudioListWidgetState();
}

class _AudioListWidgetState extends State<AudioListWidget> {
  late AudioPlayer _audioPlayer;
  String? _currentlyPlayingId;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
          _currentlyPlayingId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause(AudioItem audio) async {
    if (_currentlyPlayingId == audio.id && _playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else if (_currentlyPlayingId == audio.id && _playerState == PlayerState.paused) {
      await _audioPlayer.resume();
    } else {
      await _audioPlayer.stop();
      try {
        final bytes = base64Decode(audio.base64Data);
        setState(() {
          _currentlyPlayingId = audio.id;
          _position = Duration.zero;
          if (audio.durationSeconds > 0) {
            _duration = Duration(seconds: audio.durationSeconds);
          }
        });
        await _audioPlayer.play(BytesSource(bytes));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ses çalınamadı: $e')),
          );
        }
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showRenameDialog(int index, AudioItem audio) {
    final controller = TextEditingController(text: audio.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeniden Adlandır'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Ses Adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                widget.onRename(index, newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audios.isEmpty) return const SizedBox.shrink();

    final color = widget.accentColor ?? Colors.deepPurple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.graphic_eq_rounded, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              'Ses Kayıtları & Müzikler (${widget.audios.length})',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.audios.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final audio = widget.audios[index];
            final isCurrent = _currentlyPlayingId == audio.id;
            final isPlaying = isCurrent && _playerState == PlayerState.playing;

            final displayDuration = isCurrent
                ? _duration
                : Duration(seconds: audio.durationSeconds);
            final displayPosition = isCurrent ? _position : Duration.zero;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrent ? color.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent ? color.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Play / Pause Butonu
                      InkWell(
                        onTap: () => _playPause(audio),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Başlık & İkon
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  audio.isExternalFile ? Icons.music_note_rounded : Icons.mic_rounded,
                                  size: 14,
                                  color: color,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    audio.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isCurrent
                                  ? '${_formatDuration(displayPosition)} / ${_formatDuration(displayDuration)}'
                                  : (audio.durationSeconds > 0
                                      ? _formatDuration(Duration(seconds: audio.durationSeconds))
                                      : (audio.isExternalFile ? 'Ses Dosyası' : 'Ses Kaydı')),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),

                      // Menü (⋮)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                        onSelected: (val) async {
                          if (val == 'rename') {
                            _showRenameDialog(index, audio);
                          } else if (val == 'transfer') {
                            widget.onTransfer?.call(index);
                          } else if (val == 'delete') {
                            if (isCurrent) await _audioPlayer.stop();
                            widget.onDelete(index);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Yeniden Adlandır'),
                              ],
                            ),
                          ),
                          if (widget.onTransfer != null)
                            const PopupMenuItem(
                              value: 'transfer',
                              child: Row(
                                children: [
                                  Icon(Icons.drive_file_move_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Başka Nota Kopyala / Taşı'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text('Sil', style: TextStyle(color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Oynatılıyorsa İlerleme Çubuğu
                  if (isCurrent)
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: color,
                        thumbColor: color,
                        inactiveTrackColor: color.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _duration.inMilliseconds > 0
                            ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                            : 0.0,
                        onChanged: (val) {
                          final newPos = Duration(milliseconds: (val * _duration.inMilliseconds).round());
                          _audioPlayer.seek(newPos);
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

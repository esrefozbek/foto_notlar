import 'dart:async';
import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecordingResult {
  final String audioBase64;
  final int durationSeconds;

  VoiceRecordingResult({
    required this.audioBase64,
    required this.durationSeconds,
  });
}

class VoiceRecorderDialog extends StatefulWidget {
  const VoiceRecorderDialog({super.key});

  @override
  State<VoiceRecorderDialog> createState() => _VoiceRecorderDialogState();
}

class _VoiceRecorderDialogState extends State<VoiceRecorderDialog> with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _seconds = 0;
  Timer? _timer;
  String _statusText = 'Kayıt Başlatılıyor...';
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _statusText = 'Mikrofon izni verilmedi.';
          });
        }
        return;
      }

      String path = '';
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _statusText = 'Ses Kaydediliyor...';
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _seconds++);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = 'Kayıt başlatılamadı: $e';
        });
      }
    }
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    try {
      final path = await _recorder.stop();
      if (path != null) {
        final xFile = XFile(path);
        final bytes = await xFile.readAsBytes();
        final base64String = base64Encode(bytes);

        if (mounted) {
          Navigator.pop(
            context,
            VoiceRecordingResult(
              audioBase64: base64String,
              durationSeconds: _seconds > 0 ? _seconds : 1,
            ),
          );
        }
      } else {
        if (mounted) Navigator.pop(context, null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ses kaydedilirken hata oluştu: $e')),
        );
        Navigator.pop(context, null);
      }
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    try {
      await _recorder.cancel();
    } catch (_) {}
    if (mounted) Navigator.pop(context, null);
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _statusText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Kırmızı Dalgalanan Mikrofon İkonu
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final scale = _isRecording ? (1.0 + (_animController.value * 0.15)) : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.redAccent : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      boxShadow: _isRecording
                          ? [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.4),
                                blurRadius: 18,
                                spreadRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Sayaç
            Text(
              _formatTime(_seconds),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),

            // Butonlar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _cancelRecording,
                  icon: const Icon(Icons.close, color: Colors.grey),
                  label: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
                ),
                if (_isRecording)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onPressed: _stopAndSave,
                    icon: const Icon(Icons.check),
                    label: const Text('Kaydı Bitir'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

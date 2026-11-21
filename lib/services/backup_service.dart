import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import 'note_storage.dart';

/// Yedekleme / Geri Yükleme Sonuç Modeli
class BackupResult {
  final bool success;
  final String message;
  final int? noteCount;

  const BackupResult({
    required this.success,
    required this.message,
    this.noteCount,
  });
}

/// Yedekleme servisi — JSON tabanlı dışa/içe aktarma
class BackupService {
  static const String _backupVersionKey = 'backup_version';
  static const int _currentBackupVersion = 1;

  // ──────────────────────────────────────────────────────────────────────────
  // DIŞA AKTAR (Export)
  // ──────────────────────────────────────────────────────────────────────────

  /// Tüm notları JSON olarak hazırlar ve dosya olarak kaydeder.
  /// Web: tarayıcıda dosya indir diyaloğu açılır.
  /// Mobil/Desktop: FilePicker ile kayıt konumu seçilir.
  static Future<BackupResult> exportNotes(List<Note> notes) async {
    try {
      if (notes.isEmpty) {
        return const BackupResult(
          success: false,
          message: 'Dışa aktarılacak not bulunamadı.',
        );
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'fotonotlar_yedek_$timestamp.json';

      final backupMap = {
        _backupVersionKey: _currentBackupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'noteCount': notes.length,
        'notes': notes.map((n) => n.toMap()).toList(),
      };

      final jsonBytes = utf8.encode(jsonEncode(backupMap));

      if (kIsWeb) {
        // Web: FilePicker saveFile desteklenmiyor — bytes döndür, caller halleder
        return BackupResult(
          success: true,
          message: '${notes.length} not yedeklendi.',
          noteCount: notes.length,
        );
      }

      // Mobil / Desktop: kayıt konumu seç
      final saveUri = await FilePicker.saveFile(
        dialogTitle: 'Yedeği Kaydet',
        fileName: fileName,
        bytes: Uint8List.fromList(jsonBytes),
      );

      if (saveUri == null) {
        return const BackupResult(
          success: false,
          message: 'Kayıt iptal edildi.',
        );
      }

      return BackupResult(
        success: true,
        message: '${notes.length} not başarıyla dışa aktarıldı.',
        noteCount: notes.length,
      );
    } catch (e) {
      debugPrint('Export hatası: $e');
      return BackupResult(
        success: false,
        message: 'Dışa aktarma hatası: $e',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // İÇE AKTAR (Import)
  // ──────────────────────────────────────────────────────────────────────────

  /// Kullanıcının seçtiği JSON dosyasını okur, mevcut notlarla birleştirir.
  /// Aynı ID'li notlar: içe aktarılan (daha yeni) versiyonla güncellenir.
  static Future<BackupResult> importNotes() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Yedek Dosyası Seç',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isEmpty) {
        return const BackupResult(
          success: false,
          message: 'Dosya seçilmedi.',
        );
      }

      final fileBytes = await files.first.readAsBytes();
      if (fileBytes.isEmpty) {
        return const BackupResult(
          success: false,
          message: 'Dosya okunamadı veya boş.',
        );
      }

      final jsonString = utf8.decode(fileBytes);
      final dynamic decoded = jsonDecode(jsonString);

      if (decoded is! Map<String, dynamic>) {
        return const BackupResult(
          success: false,
          message: 'Geçersiz yedek dosyası formatı.',
        );
      }

      final version = decoded[_backupVersionKey] as int? ?? 0;
      if (version < 1) {
        return const BackupResult(
          success: false,
          message: 'Bu yedek dosyası desteklenmeyen bir versiyona ait.',
        );
      }

      final noteList = decoded['notes'];
      if (noteList is! List) {
        return const BackupResult(
          success: false,
          message: 'Yedek dosyasında not listesi bulunamadı.',
        );
      }

      final importedNotes = noteList
          .whereType<Map<String, dynamic>>()
          .map((m) => Note.fromMap(m))
          .toList();

      if (importedNotes.isEmpty) {
        return const BackupResult(
          success: false,
          message: 'Yedek dosyasında hiç not yok.',
        );
      }

      // Mevcut notlarla birleştir (ID bazlı — yenisi kazanır)
      final existing = await NoteStorage.loadNotes();
      final existingMap = {for (final n in existing) n.id: n};

      for (final imported in importedNotes) {
        final current = existingMap[imported.id];
        if (current == null || imported.updatedAt.isAfter(current.updatedAt)) {
          existingMap[imported.id] = imported;
        }
      }

      final merged = existingMap.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      await NoteStorage.saveNotes(merged);

      return BackupResult(
        success: true,
        message: '${importedNotes.length} not içe aktarıldı, toplam ${merged.length} not.',
        noteCount: importedNotes.length,
      );
    } catch (e) {
      debugPrint('Import hatası: $e');
      return BackupResult(
        success: false,
        message: 'İçe aktarma hatası: $e',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // OTOMATİK YEDEK BİLGİSİ
  // ──────────────────────────────────────────────────────────────────────────

  /// Son otomatik yedek tarihini SharedPreferences'a yazar
  static Future<void> setLastAutoBackupTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_auto_backup', time.toIso8601String());
  }

  /// Son otomatik yedek tarihini okur
  static Future<DateTime?> getLastAutoBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('last_auto_backup');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}

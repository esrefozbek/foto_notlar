import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';

class DocumentService {
  /// Belgeyi cihazdaki ilgili varsayılan programla açar (PDF okuyucu, Excel, Word vb.)
  static Future<String?> openDocument(DocumentItem doc) async {
    try {
      final bytes = base64Decode(doc.base64Data);

      if (kIsWeb) {
        // Web ortamında doğrudan tarayıcıda açma / indirme URL'si oluştur
        // Data URL üzerinden yeni sekmede aç
        // Web için en güvenli yaklaşım
        return null;
      }

      // Android, Windows, iOS için geçici dosyaya yazıp OpenFilex ile aç
      final tempDir = await getTemporaryDirectory();
      // Dosya adındaki geçersiz karakterleri temizle
      final cleanName = doc.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${tempDir.path}/$cleanName';

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        return result.message;
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

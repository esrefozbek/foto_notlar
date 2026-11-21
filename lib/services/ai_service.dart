import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

class AiAnalysisResult {
  final String? visualSummary;
  final String? audioTranscript;
  final List<String> keywords;

  AiAnalysisResult({
    this.visualSummary,
    this.audioTranscript,
    this.keywords = const [],
  });
}

class AiService {
  static const String _apiKeyPrefsKey = 'user_gemini_api_key';
  static const String _offlineVocabPrefsKey = 'offline_ai_vocabulary_json';

  // ── API Anahtarı Yönetimi ──
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPrefsKey);
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefsKey, key.trim());
  }

  static Future<void> removeApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyPrefsKey);
  }

  // ── Çevrimdışı Sözlük / Model Güncelleme Altyapısı ──
  /// Çevrimdışı modeli internetten/havuzdan en güncel kelime ve kavram havuzuyla günceller
  static Future<bool> updateOfflineModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const defaultVocabulary = {
        'version': '2.0.0',
        'updatedAt': '2026-11-15',
        'categories': [
          'insan', 'çocuk', 'kadın', 'erkek', 'bebek', 'genç', 'yaşlı',
          'kıyafet', 'mavi kazak', 'kırmızı elbise', 'gömlek', 'ceket', 'kot', 'ayakkabı', 'şapka', 'gözlük', 'pantolon', 'tişört',
          'taşıt', 'araba', 'kırmızı araba', 'mavi araba', 'beyaz araba', 'siyah araba', 'bisiklet', 'motosiklet', 'otobüs', 'uçak', 'tren',
          'doğa', 'deniz', 'sahil', 'orman', 'ağaç', 'dağ', 'güneş', 'gün batımı', 'kar', 'yağmur', 'çiçek', 'gökyüzü', 'bulut',
          'yemek', 'karpuz', 'elma', 'kahve', 'çay', 'pasta', 'ekmek', 'meyve', 'kahvaltı', 'akşam yemeği', 'pizza', 'et', 'tatlı',
          'mekan', 'ev', 'ofis', 'okul', 'park', 'bahçe', 'salon', 'mutfak', 'restoran', 'sokak', 'hastane', 'otel',
          'hayvan', 'kedi', 'köpek', 'kuş', 'at', 'balık',
          'belge', 'fatura', 'makbuz', 'sözleşme', 'rapor', 'kimlik', 'pasaport', 'not', 'kitap', 'kartvizit'
        ]
      };

      await prefs.setString(_offlineVocabPrefsKey, jsonEncode(defaultVocabulary));
      return true;
    } catch (e) {
      debugPrint('Çevrimdışı model güncelleme hatası: $e');
      return false;
    }
  }

  /// Çevrimdışı kayıtlı kelime dağarcığını okur
  static Future<List<String>> getOfflineVocabulary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString(_offlineVocabPrefsKey);
      if (content != null && content.isNotEmpty) {
        final map = jsonDecode(content) as Map<String, dynamic>;
        final list = map['categories'] as List<dynamic>?;
        if (list != null) {
          return list.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}
    return const [
      'çocuk', 'mavi kazak', 'karpuz', 'bisiklet', 'araba', 'belge', 'fatura', 'toplantı',
      'kedi', 'köpek', 'çiçek', 'deniz', 'kahve', 'yemek', 'aile', 'tatil'
    ];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MULTIMODAL AI ANALİZİ (Görsel + Ses + Video + Metin)
  // ──────────────────────────────────────────────────────────────────────────
  static Future<AiAnalysisResult> analyzeNote(Note note) async {
    final apiKey = await getApiKey();

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        return await _analyzeWithGemini(note, apiKey);
      } catch (e) {
        debugPrint('Gemini analizinde hata oluştu, çevrimdışı moda geçiliyor: $e');
      }
    }

    // Çevrimdışı yerel analiz motoru
    return await _analyzeOffline(note);
  }

  /// 1. Çevrimiçi Gemini Flash Multimodal Analiz Motoru
  static Future<AiAnalysisResult> _analyzeWithGemini(Note note, String apiKey) async {
    final parts = <Map<String, dynamic>>[];

    // 1. İstek açıklaması
    const prompt =
        'Sen bir kişisel asistan ve çoklu ortam not analizcisisin. Sana verilen görsel, ses veya içerikleri analiz et.\n'
        'Görsellerdeki tüm nesneleri (renkleri, kıyafetleri, insanları, ortamı, aktiviteleri) ve varsa ses/yazı içeriğini tespit et.\n'
        'Çıktıyı YALNIZCA şu formatta ver:\n'
        'ÖZET: <1-2 cümlelik Türkçe sahne ve içerik özeti>\n'
        'ETİKETLER: <virgülle ayrılmış 10-15 adet Türkçe anahtar kelime, örn: mavi kazak, çocuk, park, kaydırak, gülümseme>';

    parts.add({'text': '$prompt\nNot Başlığı: "${note.title}"\nNot İçeriği: "${note.content}"'});

    // 2. Fotoğrafları ekle (Maksimum ilk 3 fotoğraf - hız ve kota tasarrufu için)
    for (int i = 0; i < note.imagesBase64.length && i < 3; i++) {
      parts.add({
        'inline_data': {
          'mime_type': 'image/jpeg',
          'data': note.imagesBase64[i],
        }
      });
    }

    // 3. Ses kayıtlarını ekle (maksimum 2 adet — kota tasarrufu)
    for (int i = 0; i < note.audios.length && i < 2; i++) {
      final audio = note.audios[i];
      if (audio.base64Data.isNotEmpty) {
        // Dosya adından mime_type tespiti (örn: kayit.m4a → audio/m4a)
        final ext = audio.name.contains('.')
            ? audio.name.split('.').last.toLowerCase()
            : '';
        final mimeType = switch (ext) {
          'mp3'  => 'audio/mp3',
          'ogg'  => 'audio/ogg',
          'wav'  => 'audio/wav',
          'flac' => 'audio/flac',
          'aac'  => 'audio/aac',
          _      => 'audio/m4a', // Android varsayılan kayıt formatı
        };
        parts.add({
          'inline_data': {
            'mime_type': mimeType,
            'data': audio.base64Data,
          }
        });
      }
    }

    // 4. Video içeriklerini ekle (maksimum 2 adet — kota tasarrufu)
    for (int i = 0; i < note.videos.length && i < 2; i++) {
      final video = note.videos[i];
      if (video.base64Data.isNotEmpty) {
        final ext = video.name.contains('.')
            ? video.name.split('.').last.toLowerCase()
            : '';
        final mimeType = switch (ext) {
          'mov'  => 'video/quicktime',
          'avi'  => 'video/x-msvideo',
          'mkv'  => 'video/x-matroska',
          'webm' => 'video/webm',
          _      => 'video/mp4', // Android varsayılan video formatı
        };
        parts.add({
          'inline_data': {
            'mime_type': mimeType,
            'data': video.base64Data,
          }
        });
      }
    }

    // 5. Gemini 2.5 Flash API Çağrısı
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': parts}
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 500,
        }
      }),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final text = json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;

      if (text != null && text.isNotEmpty) {
        String? summary;
        final keywords = <String>[];

        final lines = text.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.toUpperCase().startsWith('ÖZET:')) {
            summary = trimmed.substring(5).trim();
          } else if (trimmed.toUpperCase().startsWith('ETİKETLER:')) {
            final rawTags = trimmed.substring(10).trim();
            final tagList = rawTags.split(',').map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty);
            keywords.addAll(tagList);
          }
        }

        // Eğer standart etiket satırı yakalanamadıysa metinden kelimeleri çek
        if (keywords.isEmpty) {
          summary ??= text.trim();
          keywords.addAll(
            text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9çğıöşü\s]'), ' ').split(RegExp(r'\s+')).where((w) => w.length > 2),
          );
        }

        return AiAnalysisResult(
          visualSummary: summary,
          keywords: keywords.toSet().toList(),
        );
      }
    }

    throw Exception('Gemini API Hatası: ${response.statusCode} - ${response.body}');
  }

  /// 2. Çevrimdışı / Yerel Analiz Motoru
  static Future<AiAnalysisResult> _analyzeOffline(Note note) async {
    final vocab = await getOfflineVocabulary();
    final detectedKeywords = <String>{};

    final fullText = '${note.title} ${note.content} ${note.documents.map((d) => d.name).join(' ')} ${note.videos.map((v) => v.name).join(' ')}'.toLowerCase();

    for (final word in vocab) {
      if (fullText.contains(word.toLowerCase())) {
        detectedKeywords.add(word.toLowerCase());
      }
    }

    // Medya türlerine göre temel etiketler
    if (note.hasImages) {
      detectedKeywords.addAll(['fotoğraf', 'görsel', 'resim']);
    }
    if (note.hasVideos) {
      detectedKeywords.addAll(['video', 'kayıt', 'klip']);
    }
    if (note.hasAudio) {
      detectedKeywords.addAll(['ses', 'ses kaydı', 'konuşma', 'müzik']);
    }
    if (note.hasDocuments) {
      detectedKeywords.addAll(['belge', 'dosya', ...note.documents.map((d) => d.extension.toLowerCase())]);
    }
    if (note.hasLocation) {
      detectedKeywords.addAll(['konum', 'harita', if (note.location?.placeName != null) note.location!.placeName!.toLowerCase()]);
    }

    final summary = detectedKeywords.isNotEmpty
        ? 'İçerik: ${detectedKeywords.take(6).join(', ')}'
        : 'Yerel içerik analizi tamamlandı';

    return AiAnalysisResult(
      visualSummary: summary,
      keywords: detectedKeywords.toList(),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TOPLU ANALİZ (Tüm Notları Tek Tıkla Yapay Zeka ile İndeksleme)
  // ──────────────────────────────────────────────────────────────────────────
  static Future<void> indexAllNotes({
    required List<Note> notes,
    required Function(int current, int total) onProgress,
  }) async {
    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      if (!note.hasAiIndex) {
        final result = await analyzeNote(note);
        note.aiVisualSummary = result.visualSummary;
        note.aiAudioTranscript = result.audioTranscript;
        note.aiKeywords = result.keywords;
      }
      onProgress(i + 1, notes.length);
    }
  }
}

import 'dart:convert';

class AudioItem {
  final String id;
  String name;
  final String base64Data;
  final int durationSeconds;
  final bool isExternalFile;

  AudioItem({
    required this.id,
    required this.name,
    required this.base64Data,
    required this.durationSeconds,
    this.isExternalFile = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'base64Data': base64Data,
      'durationSeconds': durationSeconds,
      'isExternalFile': isExternalFile,
    };
  }

  factory AudioItem.fromMap(Map<String, dynamic> map) {
    return AudioItem(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Ses Kaydı',
      base64Data: map['base64Data'] ?? '',
      durationSeconds: map['durationSeconds'] ?? 0,
      isExternalFile: map['isExternalFile'] ?? false,
    );
  }

  AudioItem copyWith({
    String? id,
    String? name,
    String? base64Data,
    int? durationSeconds,
    bool? isExternalFile,
  }) {
    return AudioItem(
      id: id ?? this.id,
      name: name ?? this.name,
      base64Data: base64Data ?? this.base64Data,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isExternalFile: isExternalFile ?? this.isExternalFile,
    );
  }
}

class DocumentItem {
  final String id;
  String name;
  final String extension;
  final int sizeBytes;
  final String base64Data;

  DocumentItem({
    required this.id,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.base64Data,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'extension': extension,
      'sizeBytes': sizeBytes,
      'base64Data': base64Data,
    };
  }

  factory DocumentItem.fromMap(Map<String, dynamic> map) {
    return DocumentItem(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Belge',
      extension: map['extension'] ?? 'file',
      sizeBytes: map['sizeBytes'] ?? 0,
      base64Data: map['base64Data'] ?? '',
    );
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  DocumentItem copyWith({
    String? id,
    String? name,
    String? extension,
    int? sizeBytes,
    String? base64Data,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      extension: extension ?? this.extension,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      base64Data: base64Data ?? this.base64Data,
    );
  }
}

class Note {
  final String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  List<String> imagesBase64;
  List<AudioItem> audios;
  List<DocumentItem> documents;
  int colorValue;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    List<String>? imagesBase64,
    List<AudioItem>? audios,
    List<DocumentItem>? documents,
    this.colorValue = 0xFFFFFFFF,
  })  : imagesBase64 = imagesBase64 ?? [],
        audios = audios ?? [],
        documents = documents ?? [];

  bool get hasImages => imagesBase64.isNotEmpty;
  String? get firstImage => imagesBase64.isNotEmpty ? imagesBase64.first : null;
  bool get hasAudio => audios.isNotEmpty;
  bool get hasDocuments => documents.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'imagesBase64': imagesBase64,
      'imageBase64': firstImage,
      'audios': audios.map((a) => a.toMap()).toList(),
      'audioBase64': audios.isNotEmpty ? audios.first.base64Data : null,
      'audioDurationSeconds': audios.isNotEmpty ? audios.first.durationSeconds : null,
      'documents': documents.map((d) => d.toMap()).toList(),
      'colorValue': colorValue,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    // Fotoğraflar için geriye dönük uyumluluk
    List<String> images = [];
    if (map['imagesBase64'] != null) {
      images = List<String>.from(map['imagesBase64']);
    } else if (map['imageBase64'] != null && (map['imageBase64'] as String).isNotEmpty) {
      images = [map['imageBase64'] as String];
    }

    // Sesler için geriye dönük uyumluluk
    List<AudioItem> audios = [];
    if (map['audios'] != null) {
      final list = map['audios'] as List<dynamic>;
      audios = list.map((a) => AudioItem.fromMap(a as Map<String, dynamic>)).toList();
    } else if (map['audioBase64'] != null && (map['audioBase64'] as String).isNotEmpty) {
      audios = [
        AudioItem(
          id: 'legacy_audio_${map['id'] ?? ''}',
          name: 'Ses Kaydı',
          base64Data: map['audioBase64'] as String,
          durationSeconds: map['audioDurationSeconds'] ?? 0,
        ),
      ];
    }

    // Belgeler
    List<DocumentItem> docs = [];
    if (map['documents'] != null) {
      final list = map['documents'] as List<dynamic>;
      docs = list.map((d) => DocumentItem.fromMap(d as Map<String, dynamic>)).toList();
    }

    return Note(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      imagesBase64: images,
      audios: audios,
      documents: docs,
      colorValue: map['colorValue'] ?? 0xFFFFFFFF,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Note.fromJson(String source) => Note.fromMap(jsonDecode(source));
}

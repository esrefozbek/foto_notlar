import 'dart:convert';

class Note {
  final String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  List<String> imagesBase64;
  String? audioBase64;
  int? audioDurationSeconds;
  int colorValue;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    List<String>? imagesBase64,
    this.audioBase64,
    this.audioDurationSeconds,
    this.colorValue = 0xFFFFFFFF,
  }) : imagesBase64 = imagesBase64 ?? [];

  bool get hasImages => imagesBase64.isNotEmpty;
  String? get firstImage => imagesBase64.isNotEmpty ? imagesBase64.first : null;
  bool get hasAudio => audioBase64 != null && audioBase64!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'imagesBase64': imagesBase64,
      'imageBase64': firstImage,
      'audioBase64': audioBase64,
      'audioDurationSeconds': audioDurationSeconds,
      'colorValue': colorValue,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    List<String> images = [];
    if (map['imagesBase64'] != null) {
      images = List<String>.from(map['imagesBase64']);
    } else if (map['imageBase64'] != null && (map['imageBase64'] as String).isNotEmpty) {
      images = [map['imageBase64'] as String];
    }

    return Note(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      imagesBase64: images,
      audioBase64: map['audioBase64'],
      audioDurationSeconds: map['audioDurationSeconds'],
      colorValue: map['colorValue'] ?? 0xFFFFFFFF,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Note.fromJson(String source) => Note.fromMap(jsonDecode(source));
}

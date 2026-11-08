import 'dart:convert';

// ─── AudioItem ────────────────────────────────────────────────────────────────
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

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'base64Data': base64Data,
        'durationSeconds': durationSeconds,
        'isExternalFile': isExternalFile,
      };

  factory AudioItem.fromMap(Map<String, dynamic> map) => AudioItem(
        id: map['id'] ?? '',
        name: map['name'] ?? 'Ses Kaydı',
        base64Data: map['base64Data'] ?? '',
        durationSeconds: map['durationSeconds'] ?? 0,
        isExternalFile: map['isExternalFile'] ?? false,
      );

  AudioItem copyWith({
    String? id,
    String? name,
    String? base64Data,
    int? durationSeconds,
    bool? isExternalFile,
  }) =>
      AudioItem(
        id: id ?? this.id,
        name: name ?? this.name,
        base64Data: base64Data ?? this.base64Data,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        isExternalFile: isExternalFile ?? this.isExternalFile,
      );
}

// ─── DocumentItem ─────────────────────────────────────────────────────────────
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

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'extension': extension,
        'sizeBytes': sizeBytes,
        'base64Data': base64Data,
      };

  factory DocumentItem.fromMap(Map<String, dynamic> map) => DocumentItem(
        id: map['id'] ?? '',
        name: map['name'] ?? 'Belge',
        extension: map['extension'] ?? 'file',
        sizeBytes: map['sizeBytes'] ?? 0,
        base64Data: map['base64Data'] ?? '',
      );

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
  }) =>
      DocumentItem(
        id: id ?? this.id,
        name: name ?? this.name,
        extension: extension ?? this.extension,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        base64Data: base64Data ?? this.base64Data,
      );
}

// ─── VideoItem ────────────────────────────────────────────────────────────────
class VideoItem {
  final String id;
  String name;
  final String base64Data;
  final int sizeBytes;
  final int durationSeconds;

  VideoItem({
    required this.id,
    required this.name,
    required this.base64Data,
    required this.sizeBytes,
    this.durationSeconds = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'base64Data': base64Data,
        'sizeBytes': sizeBytes,
        'durationSeconds': durationSeconds,
      };

  factory VideoItem.fromMap(Map<String, dynamic> map) => VideoItem(
        id: map['id'] ?? '',
        name: map['name'] ?? 'Video',
        base64Data: map['base64Data'] ?? '',
        sizeBytes: map['sizeBytes'] ?? 0,
        durationSeconds: map['durationSeconds'] ?? 0,
      );

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  VideoItem copyWith({
    String? id,
    String? name,
    String? base64Data,
    int? sizeBytes,
    int? durationSeconds,
  }) =>
      VideoItem(
        id: id ?? this.id,
        name: name ?? this.name,
        base64Data: base64Data ?? this.base64Data,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );
}

// ─── LocationItem ─────────────────────────────────────────────────────────────
class LocationItem {
  final double latitude;
  final double longitude;
  final String? placeName;
  final String? address;

  LocationItem({
    required this.latitude,
    required this.longitude,
    this.placeName,
    this.address,
  });

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'placeName': placeName,
        'address': address,
      };

  factory LocationItem.fromMap(Map<String, dynamic> map) => LocationItem(
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
        placeName: map['placeName'] as String?,
        address: map['address'] as String?,
      );

  String get displayName => placeName ?? address ?? '$latitude, $longitude';
}

// ─── ChangeLogEntry ───────────────────────────────────────────────────────────
class ChangeLogEntry {
  final DateTime timestamp;
  final String description;

  ChangeLogEntry({required this.timestamp, required this.description});

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.toIso8601String(),
        'description': description,
      };

  factory ChangeLogEntry.fromMap(Map<String, dynamic> map) => ChangeLogEntry(
        timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
        description: map['description'] ?? '',
      );
}

// ─── Note ─────────────────────────────────────────────────────────────────────
class Note {
  final String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  List<String> imagesBase64;
  List<AudioItem> audios;
  List<DocumentItem> documents;
  List<VideoItem> videos;
  int colorValue;
  String fontFamily;
  bool isPinned;
  int orderIndex;
  LocationItem? location;
  List<ChangeLogEntry> changeLogs;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    List<String>? imagesBase64,
    List<AudioItem>? audios,
    List<DocumentItem>? documents,
    List<VideoItem>? videos,
    this.colorValue = 0xFFFFFFFF,
    this.fontFamily = 'default',
    this.isPinned = false,
    this.orderIndex = 0,
    this.location,
    List<ChangeLogEntry>? changeLogs,
  })  : imagesBase64 = imagesBase64 ?? [],
        audios = audios ?? [],
        documents = documents ?? [],
        videos = videos ?? [],
        changeLogs = changeLogs ?? [];

  bool get hasImages => imagesBase64.isNotEmpty;
  String? get firstImage => imagesBase64.isNotEmpty ? imagesBase64.first : null;
  bool get hasAudio => audios.isNotEmpty;
  bool get hasDocuments => documents.isNotEmpty;
  bool get hasVideos => videos.isNotEmpty;
  bool get hasLocation => location != null;

  Map<String, dynamic> toMap() => {
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
        'videos': videos.map((v) => v.toMap()).toList(),
        'colorValue': colorValue,
        'fontFamily': fontFamily,
        'isPinned': isPinned,
        'orderIndex': orderIndex,
        'location': location?.toMap(),
        'changeLogs': changeLogs.map((c) => c.toMap()).toList(),
      };

  factory Note.fromMap(Map<String, dynamic> map) {
    // Fotoğraflar — geriye dönük uyumluluk
    List<String> images = [];
    if (map['imagesBase64'] != null) {
      images = List<String>.from(map['imagesBase64']);
    } else if (map['imageBase64'] != null && (map['imageBase64'] as String).isNotEmpty) {
      images = [map['imageBase64'] as String];
    }

    // Sesler — geriye dönük uyumluluk
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

    // Videolar
    List<VideoItem> videos = [];
    if (map['videos'] != null) {
      final list = map['videos'] as List<dynamic>;
      videos = list.map((v) => VideoItem.fromMap(v as Map<String, dynamic>)).toList();
    }

    // Konum
    LocationItem? location;
    if (map['location'] != null) {
      location = LocationItem.fromMap(map['location'] as Map<String, dynamic>);
    }

    // Değişiklik geçmişi
    List<ChangeLogEntry> changeLogs = [];
    if (map['changeLogs'] != null) {
      final list = map['changeLogs'] as List<dynamic>;
      changeLogs = list.map((c) => ChangeLogEntry.fromMap(c as Map<String, dynamic>)).toList();
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
      videos: videos,
      colorValue: map['colorValue'] ?? 0xFFFFFFFF,
      fontFamily: map['fontFamily'] ?? 'default',
      isPinned: map['isPinned'] ?? false,
      orderIndex: map['orderIndex'] ?? 0,
      location: location,
      changeLogs: changeLogs,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory Note.fromJson(String source) => Note.fromMap(jsonDecode(source));
}

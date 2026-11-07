import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

class NoteStorage {
  static const String _storageKey = 'saved_photo_notes';

  static Future<List<Note>> loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJsonString = prefs.getString(_storageKey);
      if (notesJsonString == null || notesJsonString.isEmpty) {
        return [];
      }
      final List<dynamic> decodedList = jsonDecode(notesJsonString);
      return decodedList.map((item) => Note.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> saveNotes(List<Note> notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mappedList = notes.map((note) => note.toMap()).toList();
      final jsonString = jsonEncode(mappedList);
      return await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      return false;
    }
  }
}

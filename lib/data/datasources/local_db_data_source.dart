import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client_model.dart';
import '../models/event_model.dart';

/// החוזה (Interface) שמגדיר את פעולות השמירה המקומית במכשיר.
/// מפריד את הלוגיקה העסקית מטכנולוגיית השמירה הספציפית.
abstract class LocalDbDataSource {
  Future<void> saveClients(List<ClientModel> clients);
  Future<List<ClientModel>> getClients();
  Future<void> saveEvents(List<EventModel> events);
  Future<List<EventModel>> getEvents();
  Future<void> clearAllLocalData();
}

/// המימוש בפועל של השמירה המקומית באמצעות SharedPreferences.
/// המידע נשמר בצורת מחרוזת JSON מוצפנת קלות/מובנית על המכשיר.
class LocalDbDataSourceImpl implements LocalDbDataSource {
  final SharedPreferences _sharedPreferences;

  // מפתחות ייחודיים לשמירה בתוך ה-Storage של המכשיר
  static const String _clientsKey = 'local_cached_clients';
  static const String _eventsKey = 'local_cached_events';

  LocalDbDataSourceImpl(this._sharedPreferences);

  @override
  Future<void> saveClients(List<ClientModel> clients) async {
    // הפיכת רשימת האובייקטים לרשימה של מפות (Maps)
    final List<List<dynamic>> rawRows = clients.map((client) => client.toSheetsRow()).toList();
    // קידוד למחרוזת טקסט אחת (JSON String)
    final String jsonString = jsonEncode(rawRows);
    // שמירה מקומית במכשיר
    await _sharedPreferences.setString(_clientsKey, jsonString);
  }

  @override
  Future<List<ClientModel>> getClients() async {
    final String? jsonString = _sharedPreferences.getString(_clientsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decodedList = jsonDecode(jsonString);
      return decodedList.map((row) => ClientModel.fromSheetsRow(row as List<dynamic>)).toList();
    } catch (e) {
      // במקרה של שגיאה בפענוח, נחזיר רשימה ריקה כדי לא לתקוע את האפליקציה
      return [];
    }
  }

  @override
  Future<void> saveEvents(List<EventModel> events) async {
    final List<List<dynamic>> rawRows = events.map((event) => event.toSheetsRow()).toList();
    final String jsonString = jsonEncode(rawRows);
    await _sharedPreferences.setString(_eventsKey, jsonString);
  }

  @override
  Future<List<EventModel>> getEvents() async {
    final String? jsonString = _sharedPreferences.getString(_eventsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decodedList = jsonDecode(jsonString);
      return decodedList.map((row) => EventModel.fromSheetsRow(row as List<dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> clearAllLocalData() async {
    await _sharedPreferences.remove(_clientsKey);
    await _sharedPreferences.remove(_eventsKey);
  }
}

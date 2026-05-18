import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/client_model.dart';
import '../models/event_model.dart';

abstract class LocalDbDataSource {
  Future<void> saveClients(List<ClientModel> clients);
  Future<List<ClientModel>> getClients();
  Future<void> saveEvents(List<EventModel> events);
  Future<List<EventModel>> getEvents();
}

class LocalDbDataSourceImpl implements LocalDbDataSource {
  final SharedPreferences _prefs;
  static const String _clientsKey = 'cached_clients_json';
  static const String _eventsKey = 'cached_events_json';

  LocalDbDataSourceImpl(this._prefs);

  @override
  Future<void> saveClients(List<ClientModel> clients) async {
    // המרה של כל רשימת הלקוחות למבנה מאובטח של מחרוזת JSON
    final List<Map<String, dynamic>> jsonList = clients.map((c) => c.toJson()).toList();
    await _prefs.setString(_clientsKey, json.encode(jsonList));
  }

  @override
  Future<List<ClientModel>> getClients() async {
    final String? cachedData = _prefs.getString(_clientsKey);
    if (cachedData == null || cachedData.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decodedList = json.decode(cachedData);
      return decodedList.map((item) => ClientModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('שגיאה בפענוח לקוחות מה-Local DB: $e');
      return [];
    }
  }

  @override
  Future<void> saveEvents(List<EventModel> events) async {
    // המרה של כל רשימת האירועים למבנה מאובטח של מחרוזת JSON
    final List<Map<String, dynamic>> jsonList = events.map((e) => e.toJson()).toList();
    await _prefs.setString(_eventsKey, json.encode(jsonList));
  }

  @override
  Future<List<EventModel>> getEvents() async {
    final String? cachedData = _prefs.getString(_eventsKey);
    if (cachedData == null || cachedData.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decodedList = json.decode(cachedData);
      return decodedList.map((item) => EventModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('שגיאה בפענוח אירועים מה-Local DB: $e');
      return [];
    }
  }
}

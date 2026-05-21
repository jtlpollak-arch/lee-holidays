import 'dart:math';
import '../datasources/google_calendar_api.dart';
import '../datasources/google_sheets_data_source.dart';
import '../datasources/local_db_data_source.dart';
import '../models/event_model.dart';

abstract class EventRepository {
  Future<List<EventModel>> getAllEvents(String spreadsheetId, {bool forceRefresh = false});
  Future<void> addEvent(String spreadsheetId, EventModel event);
  Future<void> addNewEvent(String spreadsheetId, EventModel event, String clientName);
  Future<void> updateEvent(String spreadsheetId, EventModel event);
  Future<void> deleteEventSoft(String spreadsheetId, EventModel event);
}

class EventRepositoryImpl implements EventRepository {
  final GoogleSheetsDataSource _googleSheetsDataSource;
  final LocalDbDataSource _localDbDataSource;
  final GoogleCalendarApi _googleCalendarApi;

  EventRepositoryImpl({required GoogleSheetsDataSource googleSheetsDataSource, required LocalDbDataSource localDbDataSource, required GoogleCalendarApi googleCalendarApi}) : _googleSheetsDataSource = googleSheetsDataSource, _localDbDataSource = localDbDataSource, _googleCalendarApi = googleCalendarApi;

  /// פונקציית עזר פנימית לייצור מזהה ייחודי קשיח מבוסס זמן ורכיב אקראי עבור האירוע
  String _generateUniqueId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(100);
    return 'evt_${timestamp}_$random';
  }

  @override
  Future<List<EventModel>> getAllEvents(String spreadsheetId, {bool forceRefresh = false}) async {
    if (forceRefresh) {
      final cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);
      if (cloudEvents.isNotEmpty) {
        await _localDbDataSource.saveEvents(cloudEvents);
      }
      return cloudEvents;
    }
    final localEvents = await _localDbDataSource.getEvents();
    if (localEvents.isNotEmpty) {
      return localEvents;
    }
    final cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);
    if (cloudEvents.isNotEmpty) {
      await _localDbDataSource.saveEvents(cloudEvents);
    }
    return cloudEvents;
  }

  @override
  Future<void> addEvent(String spreadsheetId, EventModel event) async {
    final eventWithId = event.id.isEmpty ? event.copyWith(id: _generateUniqueId()) : event;

    await _googleSheetsDataSource.appendEvent(spreadsheetId, eventWithId);

    final currentLocal = await _localDbDataSource.getEvents();
    currentLocal.add(eventWithId);
    await _localDbDataSource.saveEvents(currentLocal);
  }

  @override
  Future<void> addNewEvent(String spreadsheetId, EventModel event, String clientName) async {
    final eventWithId = event.id.isEmpty ? event.copyWith(id: _generateUniqueId()) : event;

    await _googleSheetsDataSource.appendEvent(spreadsheetId, eventWithId);

    final currentLocal = await _localDbDataSource.getEvents();
    currentLocal.add(eventWithId);
    await _localDbDataSource.saveEvents(currentLocal);

    try {
      // שימוש בחתימה המקורית והמדויקת של ה-Calendar API שלך ללא שום שינוי
      await _googleCalendarApi.insertGreetingReminderEvent(title: '$clientName - ${eventWithId.eventType}', date: eventWithId.date, description: eventWithId.notes, isRecurring: eventWithId.eventType == 'יום הולדת');
    } catch (e) {
      print('שגיאה בסנכרון האירוע מול Google Calendar: $e');
    }
  }

  @override
  Future<void> updateEvent(String spreadsheetId, EventModel event) async {
    final cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);
    final cloudIndex = cloudEvents.indexWhere((e) => e.id == event.id);
    if (cloudIndex != -1) {
      final int sheetRowNumber = cloudIndex + 2;
      await _googleSheetsDataSource.updateEventRow(spreadsheetId, sheetRowNumber, event);
    }

    final currentLocal = await _localDbDataSource.getEvents();
    final localIndex = currentLocal.indexWhere((e) => e.id == event.id);
    if (localIndex != -1) {
      currentLocal[localIndex] = event;
      await _localDbDataSource.saveEvents(currentLocal);
    }
  }

  @override
  Future<void> deleteEventSoft(String spreadsheetId, EventModel event) async {
    final cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);
    final cloudIndex = cloudEvents.indexWhere((e) => e.id == event.id);

    if (cloudIndex != -1) {
      final targetEvent = cloudEvents[cloudIndex];
      final updatedEvent = targetEvent.copyWith(status: 'מחוק');

      final int sheetRowNumber = cloudIndex + 2;
      await _googleSheetsDataSource.updateEventRow(spreadsheetId, sheetRowNumber, updatedEvent);

      final currentLocal = await _localDbDataSource.getEvents();
      final localIndex = currentLocal.indexWhere((e) => e.id == event.id);
      if (localIndex != -1) {
        currentLocal[localIndex] = updatedEvent;
        await _localDbDataSource.saveEvents(currentLocal);
      }
    }
  }
}

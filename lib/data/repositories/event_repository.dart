import '../datasources/google_calendar_api.dart';
import '../datasources/google_sheets_data_source.dart';
import '../datasources/local_db_data_source.dart';
import '../models/event_model.dart';

abstract class EventRepository {
  Future<List<EventModel>> getAllEvents(String spreadsheetId);
  Future<void> addEvent(String spreadsheetId, EventModel event);
  Future<void> addNewEvent(String spreadsheetId, EventModel event, String clientName);
  Future<void> updateEvent(String spreadsheetId, EventModel event);
  Future<void> deleteEventSoft(String spreadsheetId, String phone, String eventType); // שונה מ-clientId למחרוזת phone
}

class EventRepositoryImpl implements EventRepository {
  final GoogleSheetsDataSource _googleSheetsDataSource;
  final LocalDbDataSource _localDbDataSource;
  final GoogleCalendarApi _googleCalendarApi;

  EventRepositoryImpl({required GoogleSheetsDataSource googleSheetsDataSource, required LocalDbDataSource localDbDataSource, required GoogleCalendarApi googleCalendarApi}) : _googleSheetsDataSource = googleSheetsDataSource, _localDbDataSource = localDbDataSource, _googleCalendarApi = googleCalendarApi;

  @override
  Future<List<EventModel>> getAllEvents(String spreadsheetId) async {
    try {
      final List<EventModel> cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);
      if (cloudEvents.isNotEmpty) {
        await _localDbDataSource.saveEvents(cloudEvents);
        return cloudEvents.where((e) => e.isActive).toList();
      }
      final local = await _localDbDataSource.getEvents();
      return local.where((e) => e.isActive).toList();
    } catch (e) {
      final local = await _localDbDataSource.getEvents();
      return local.where((e) => e.isActive).toList();
    }
  }

  @override
  Future<void> addEvent(String spreadsheetId, EventModel event) async {
    // קריאה לפונקציית היצירה עם שם לקוח דיפולטיבי, השם משמש רק לכותרת ביומן גוגל
    await addNewEvent(spreadsheetId, event, 'לקוח מערכת');
  }

  @override
  Future<void> addNewEvent(String spreadsheetId, EventModel event, String clientName) async {
    final List<EventModel> currentLocalEvents = await _localDbDataSource.getEvents();
    currentLocalEvents.add(event);
    await _localDbDataSource.saveEvents(currentLocalEvents);

    await _googleSheetsDataSource.appendEvent(spreadsheetId, event);

    final bool isBirthday = event.eventType == 'יום הולדת';
    final String eventTitle = 'לשלוח ברכת ${event.eventType} ל-$clientName';
    final String eventDescription = 'אירוע אוטומטי מאפליקציית הנדל"ן.\\nהערות: ${event.notes}';

    await _googleCalendarApi.insertGreetingReminderEvent(title: eventTitle, date: event.date, description: eventDescription, isRecurring: isBirthday);
  }

  @override
  Future<void> updateEvent(String spreadsheetId, EventModel event) async {
    final currentLocal = await _localDbDataSource.getEvents();
    // התאמת החיפוש המקומי לפי טלפון הלקוח וסוג האירוע
    final index = currentLocal.indexWhere((e) => e.clientPhone == event.clientPhone && e.eventType == event.eventType);
    if (index != -1) {
      currentLocal[index] = event;
      await _localDbDataSource.saveEvents(currentLocal);
    }

    final cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);
    // התאמת החיפוש בענן לפי טלפון הלקוח וסוג האירוע
    final cloudIndex = cloudEvents.indexWhere((e) => e.clientPhone == event.clientPhone && e.eventType == event.eventType);
    if (cloudIndex != -1) {
      final int sheetRowNumber = cloudIndex + 2;
      await _googleSheetsDataSource.updateEventRow(spreadsheetId, sheetRowNumber, event);
    }
  }

  @override
  Future<void> deleteEventSoft(String spreadsheetId, String phone, String eventType) async {
    final cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);
    // איתור האירוע בענן על פי מספר הטלפון המקשר וסוג האירוע
    final cloudIndex = cloudEvents.indexWhere((e) => e.clientPhone == phone && e.eventType == eventType);

    if (cloudIndex != -1) {
      final targetEvent = cloudEvents[cloudIndex];
      final updatedEvent = EventModel(clientPhone: targetEvent.clientPhone, date: targetEvent.date, eventType: targetEvent.eventType, address: targetEvent.address, notes: targetEvent.notes, status: 'מחוק');

      final int sheetRowNumber = cloudIndex + 2;
      await _googleSheetsDataSource.updateEventRow(spreadsheetId, sheetRowNumber, updatedEvent);

      final currentLocal = await _localDbDataSource.getEvents();
      // איתור ועדכון ב-Cache המקומי על פי מספר הטלפון וסוג האירוע
      final localIndex = currentLocal.indexWhere((e) => e.clientPhone == phone && e.eventType == eventType);
      if (localIndex != -1) {
        currentLocal[localIndex] = updatedEvent;
        await _localDbDataSource.saveEvents(currentLocal);
      }
    }
  }
}

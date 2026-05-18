import 'dart:io';
import '../datasources/google_calendar_api.dart';
import '../datasources/google_sheets_data_source.dart';
import '../datasources/local_db_data_source.dart';
import '../models/event_model.dart';

/// החוזה (Interface) של שכבת ה-Repository עבור ניהול אירועים ותזכורות.
abstract class EventRepository {
  Future<List<EventModel>> getAllEvents(String spreadsheetId);
  Future<void> addNewEvent(String spreadsheetId, EventModel event, String clientName);
}

/// המימוש בפועל המנהל את הלוגיקה המורכבת של מיזוג המידע הדו-כיווני (גישה 2)
/// וסנכרון מול יומן גוגל.
class EventRepositoryImpl implements EventRepository {
  final GoogleSheetsDataSource _googleSheetsDataSource;
  final LocalDbDataSource _localDbDataSource;
  final GoogleCalendarApi _googleCalendarApi;

  EventRepositoryImpl({required GoogleSheetsDataSource googleSheetsDataSource, required LocalDbDataSource localDbDataSource, required GoogleCalendarApi googleCalendarApi}) : _googleSheetsDataSource = googleSheetsDataSource, _localDbDataSource = localDbDataSource, _googleCalendarApi = googleCalendarApi;

  @override
  Future<List<EventModel>> getAllEvents(String spreadsheetId) async {
    try {
      // 1. משיכת אירועים אך ורק מהענן (Google Sheets) האמיתי
      final List<EventModel> cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);

      // 2. עדכון בסיס הנתונים המקומי במידע האמיתי מהענן כדי לשמור על סנכרון (מנקה מידע פיקטיבי)
      await _localDbDataSource.saveEvents(cloudEvents);

      return cloudEvents;
    } catch (e) {
      print('שגיאה במשיכת אירועים מהענן ב-EventRepository: $e');
      // במקרה של שגיאת תקשורת חמורה בלבד, נחזור למה ששמור מקומית כדי למנוע קריסה
      return await _localDbDataSource.getEvents();
    }
  }

  @override
  Future<void> addNewEvent(String spreadsheetId, EventModel event, String clientName) async {
    try {
      // 1. שמירה מיידית בבסיס הנתונים המקומי בטלפון
      final List<EventModel> currentLocalEvents = await _localDbDataSource.getEvents();
      currentLocalEvents.add(event);
      await _localDbDataSource.saveEvents(currentLocalEvents);

      // 2. העלאת השורה החדשה לענן (Google Sheets) בזמן אמת
      await _googleSheetsDataSource.appendEvent(spreadsheetId, event);

      // 3. יצירת אירוע ממוקד ביומן גוגל (Google Calendar) באמצעות המתודה המקורית שלך
      final String eventTitle = 'לשלוח ברכת ${event.eventType} ל-$clientName';
      final String eventDescription = 'אירוע אוטומטי מאפליקציית הנדל"ן.\nהערות: ${event.notes}';

      await _googleCalendarApi.insertGreetingReminderEvent(title: eventTitle, date: event.date, description: eventDescription);
    } catch (e) {
      print('שגיאה בהוספת אירוע ב-EventRepository: $e');
    }
  }
}

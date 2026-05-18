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

/// המימוש בפועל המנהל את הלוגיקה המורכבת של מיזוג המידע הדו-כיווני
/// וסנכרון מול יומן גוגל.
class EventRepositoryImpl implements EventRepository {
  final GoogleSheetsDataSource _googleSheetsDataSource;
  final LocalDbDataSource _localDbDataSource;
  final GoogleCalendarApi _googleCalendarApi;

  EventRepositoryImpl({required GoogleSheetsDataSource googleSheetsDataSource, required LocalDbDataSource localDbDataSource, required GoogleCalendarApi googleCalendarApi}) : _googleSheetsDataSource = googleSheetsDataSource, _localDbDataSource = localDbDataSource, _googleCalendarApi = googleCalendarApi;

  @override
  Future<List<EventModel>> getAllEvents(String spreadsheetId) async {
    try {
      // 1. משיכת אירועים מהענן (Google Sheets) ומבסיס הנתונים המקומי
      final List<EventModel> cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);

      if (cloudEvents.isNotEmpty) {
        // עדכון זיכרון מקומי לגיבוי
        await _localDbDataSource.saveEvents(cloudEvents);
        return cloudEvents;
      }

      return await _localDbDataSource.getEvents();
    } catch (e) {
      // הגנה במקרה של שגיאה - שימוש במידע המקומי
      final List<EventModel> localEvents = await _localDbDataSource.getEvents();
      if (localEvents.isNotEmpty) {
        return localEvents;
      }
      rethrow;
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

      // 3. בדיקה האם מדובר באירוע יום הולדת שצריך לחזור כל שנה
      final bool isBirthday = event.eventType == 'יום הולדת';

      // 4. יצירת אירוע ממוקד של 5 דקות ביומן גוגל (Google Calendar)
      final String eventTitle = 'לשלוח ברכת ${event.eventType} ל-$clientName';
      final String eventDescription = 'אירוע אוטומטי מאפליקציית הנדל"ן.\\nהערות: ${event.notes}';

      await _googleCalendarApi.insertGreetingReminderEvent(
        title: eventTitle,
        date: event.date,
        description: eventDescription,
        isRecurring: isBirthday, // העברת הדגל השנתי ליומן גוגל
      );
    } catch (e) {
      print('שגיאה במהלך הוספת אירוע חדש ברפוזיטורי: $e');
      rethrow;
    }
  }
}

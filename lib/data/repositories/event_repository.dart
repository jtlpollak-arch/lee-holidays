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
      // 1. משיכת אירועים מהענן (Google Sheets) ומבסיס הנתונים המקומי
      final List<EventModel> remoteEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);
      final List<EventModel> localEvents = await _localDbDataSource.getEvents();

      // 2. ביצוע מיזוג חכם (Merge) מאחורי הקלעים:
      // נשתמש בסט (Set) מבוסס מפתח ייחודי (ID + תאריך + סוג) כדי למנוע כפילויות
      final Map<String, EventModel> mergedEventsMap = {};

      // הכנסת האירועים המקומיים קודם
      for (var event in localEvents) {
        final String key = '${event.clientId}_${event.date.millisecondsSinceEpoch}_${event.eventType}';
        mergedEventsMap[key] = event;
      }

      // הכנסת אירועי הענן (אם יש אירוע זהה, הענן מעדכן/מנצח)
      for (var event in remoteEvents) {
        final String key = '${event.clientId}_${event.date.millisecondsSinceEpoch}_${event.eventType}';
        mergedEventsMap[key] = event;
      }

      final List<EventModel> mergedList = mergedEventsMap.values.toList();

      // 3. עדכון ה-Cache המקומי בטלפון בתוצאה הממוזגת והסופית
      await _localDbDataSource.saveEvents(mergedList);

      return mergedList;
    } on SocketException {
      // במצב Offline - החזרת המידע הקיים במכשיר ללא הפרעה למשתמשת
      return await _localDbDataSource.getEvents();
    } catch (e) {
      // הגנה במקרה של שגיאה אחרת - שימוש במידע המקומי
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
      // 1. שמירה מיידית בבסיס הנתונים המקומי בטלפון (כדי שהמשתמשת תראה את זה מיד)
      final List<EventModel> currentLocalEvents = await _localDbDataSource.getEvents();
      currentLocalEvents.add(event);
      await _localDbDataSource.saveEvents(currentLocalEvents);

      // 2. העלאת השורה החדשה לענן (Google Sheets) בזמן אמת
      await _googleSheetsDataSource.appendEvent(spreadsheetId, event);

      // 3. יצירת אירוע ממוקד של 5 דקות ביומן גוגל (Google Calendar) של הסוכנת
      final String eventTitle = 'לשלוח ברכת ${event.eventType} ל-$clientName';
      final String eventDescription = 'אירוע אוטומטי מאפליקציית הנדל"ן.\nהערות: ${event.notes}';

      await _googleCalendarApi.insertGreetingReminderEvent(title: eventTitle, date: event.date, description: eventDescription);
    } on SocketException {
      // במצב Offline אמיתי, נכשלנו בהעלאה לענן/יומן אך המידע נשמר מקומית בטלפון.
      // בשלבים מתקדמים נוכל להוסיף כאן "תור משימות" לסנכרון אוטומטי כשחוזר האינטרנט.
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
}

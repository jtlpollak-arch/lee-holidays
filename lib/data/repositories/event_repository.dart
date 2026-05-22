import 'dart:math';
import '../datasources/google_calendar_api.dart';
import '../datasources/google_sheets_data_source.dart';
import '../datasources/local_db_data_source.dart';
import '../models/event_model.dart';

abstract class EventRepository {
  Future<List<EventModel>> getAllEvents(String spreadsheetId, {bool forceRefresh = false});
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
    if (!forceRefresh) {
      final localEvents = await _localDbDataSource.getEvents();
      if (localEvents.isNotEmpty) {
        return localEvents;
      }
    }

    try {
      final cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);
      await _localDbDataSource.saveEvents(cloudEvents);
      return cloudEvents;
    } catch (e) {
      print('שגיאה במשיכת אירועים מהענן, מחזיר מידע מקומי מה-Cache במידה וקיים: $e');
      return await _localDbDataSource.getEvents();
    }
  }

  @override
  Future<void> addNewEvent(String spreadsheetId, EventModel event, String clientName) async {
    final String uniqueEventId = event.id.isEmpty ? _generateUniqueId() : event.id;

    String calendarId = '';
    try {
      // יצירת הכותרת הרשמית עבור יומן גוגל (שם הלקוח + סוג האירוע)
      final String calendarTitle = '$clientName - ${event.eventType}';
      // יצירת תיאור האירוע המבוסס על הכתובת וההערות שנקלטו
      final String calendarDescription = 'כתובת נכס: ${event.address}\nהערות: ${event.notes}';

      // קריאה לשירות של גוגל קלנדר - כל האירועים מוגדרים כמחזוריים שנתיים קבועים
      calendarId = await _googleCalendarApi.insertGreetingReminderEvent(title: calendarTitle, date: event.date, description: calendarDescription, isRecurring: true);
    } catch (e) {
      print('אזהרה: נכשלה יצירת אירוע ב-Google Calendar: $e. האירוע יישמר בשיטס ללא מזהה קלנדר.');
    }

    // יצירת האובייקט הסופי שכולל את מזהה האירוע הפנימי ואת מזהה הקלנדר שקיבלנו מגוגל
    final finalEvent = event.copyWith(id: uniqueEventId, calendarEventId: calendarId);

    await _googleSheetsDataSource.appendEvent(spreadsheetId, finalEvent);

    final currentLocal = await _localDbDataSource.getEvents();
    currentLocal.add(finalEvent);
    await _localDbDataSource.saveEvents(currentLocal);
  }

  @override
  Future<void> updateEvent(String spreadsheetId, EventModel event) async {
    String newCalendarId = event.calendarEventId;

    // שלב המחיקה והיצירה מחדש בקלנדר לצורך עדכון נקי ומניעת באגים של חוקי מחזוריות
    try {
      // 1. אם קיים מזהה קלנדר ישן, נמחק אותו קודם מהיומן של גוגל
      if (event.calendarEventId.isNotEmpty) {
        print('נמצא מזהה קלנדר ישן (${event.calendarEventId}), מוחק את הסדרה הישנה מהיומן...');
        await _googleCalendarApi.deleteEventSeries(event.calendarEventId);
      }

      // 2. נמשוך את שם הלקוח המעודכן מהרשימה המקומית או נבנה תיאור מעודכן
      final String calendarTitle = '${event.eventType} (מעודכן)';
      final String calendarDescription = 'כתובת נכס: ${event.address}\nהערות: ${event.notes}';

      // 3. ניצור אירוע מחזורי שנתי חדש ונקי לחלוטין ביומן גוגל
      newCalendarId = await _googleCalendarApi.insertGreetingReminderEvent(title: calendarTitle, date: event.date, description: calendarDescription, isRecurring: true);
    } catch (e) {
      print('שגיאה בתהליך עדכון האירוע מול Google Calendar: $e. ממשיך בעדכון הנתונים בגיליון.');
    }

    // הצמדת מזהה הקלנדר החדש (או הישן במידה והתהליך נכשל) לאובייקט האירוע
    final updatedEvent = event.copyWith(calendarEventId: newCalendarId);

    final cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);
    final cloudIndex = cloudEvents.indexWhere((e) => e.id == updatedEvent.id);
    if (cloudIndex != -1) {
      final int sheetRowNumber = cloudIndex + 2;
      await _googleSheetsDataSource.updateEventRow(spreadsheetId, sheetRowNumber, updatedEvent);
    }

    final currentLocal = await _localDbDataSource.getEvents();
    final localIndex = currentLocal.indexWhere((e) => e.id == updatedEvent.id);
    if (localIndex != -1) {
      currentLocal[localIndex] = updatedEvent;
      await _localDbDataSource.saveEvents(currentLocal);
    }
  }

  @override
  Future<void> deleteEventSoft(String spreadsheetId, EventModel event) async {
    // מחיקת האירוע המחזורי לחלוטין מיומן גוגל ברגע שהמשתמשת מוחקת אותו מהאפליקציה
    if (event.calendarEventId.isNotEmpty) {
      try {
        print('מוחק את הסדרה מהיומן של גוגל בעקבות מחיקה רכה באפליקציה (ID: ${event.calendarEventId})...');
        await _googleCalendarApi.deleteEventSeries(event.calendarEventId);
      } catch (e) {
        print('שגיאה במחיקת האירוע מ-Google Calendar: $e');
      }
    }

    final cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);
    final cloudIndex = cloudEvents.indexWhere((e) => e.id == event.id);

    if (cloudIndex != -1) {
      final targetEvent = cloudEvents[cloudIndex];
      // שמירה על האירוע כ-'מחוק' בגיליון, אך מאפסים את ה-calendarEventId שכן הוא כבר לא קיים בגוגל
      final updatedEvent = targetEvent.copyWith(status: 'מחוק', calendarEventId: '');

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

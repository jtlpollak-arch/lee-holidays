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
  Future<List<String>> deleteEventsPermanentlyByClient(String spreadsheetId, String clientId);
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

    // לשליפת המצב הקיים מה-DB המקומי לצורך השוואת תאריכים
    final currentLocal = await _localDbDataSource.getEvents();
    final localIndex = currentLocal.indexWhere((e) => e.id == event.id);

    EventModel? existingLocalEvent;
    if (localIndex != -1) {
      existingLocalEvent = currentLocal[localIndex];
    }

    // בדיקה האם נדרש עדכון בקלנדר: רק אם התאריך השתנה, או אם אין עדיין מזהה קלנדר בכלל
    final bool isDateChanged = existingLocalEvent != null && event.date != existingLocalEvent.date;
    final bool hasNoCalendarId = event.calendarEventId.isEmpty;

    if (isDateChanged || hasNoCalendarId) {
      // שלב המחיקה והיצירה מחדש בקלנדר לצורך עדכון נקי ומניעת באגים של חוקי מחזוריות
      try {
        // 1. אם קיים מזהה קלנדר ישן, נמחק אותו קודם מהיומן של גוגל
        if (event.calendarEventId.isNotEmpty) {
          print('נמצא מזהה קלנדר ישן (${event.calendarEventId}), והתאריך השתנה. מוחק את הסדרה הישנה מהיומן...');
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
    } else {
      print('עדכון פנימי שאינו כולל שינוי תאריך. מדלג על עדכון Google Calendar כדי למנוע כפילויות.');
    }

    // הצמדת מזהה הקלנדר החדש (או הישן במידה והתהליך נכשל או דולג) לאובייקט האירוע
    final updatedEvent = event.copyWith(calendarEventId: newCalendarId);

    // עדכון בגיליון הענן של גוגל שיטס
    final cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);
    final cloudIndex = cloudEvents.indexWhere((e) => e.id == updatedEvent.id);
    if (cloudIndex != -1) {
      final int sheetRowNumber = cloudIndex + 2;
      await _googleSheetsDataSource.updateEventRow(spreadsheetId, sheetRowNumber, updatedEvent);
    }

    // עדכון סופי בבסיס הנתונים המקומי
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

  @override
  Future<List<String>> deleteEventsPermanentlyByClient(String spreadsheetId, String clientId) async {
    print('מתחיל איסוף ואריזת אירועי הלקוח $clientId לפקודת Batch אחת מרוכזת...');

    // 1. משיכת רשימת האירועים העדכנית ביותר מהענן
    final cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);

    final List<String> googleCalendarIdsToClean = [];
    final List<int> targetRowNumbers = [];

    // 2. מיפוי כל השורות הפיזיות ומזהי היומן של הלקוח
    for (int i = 0; i < cloudEvents.length; i++) {
      if (cloudEvents[i].clientId == clientId) {
        targetRowNumbers.add(i + 2); // חישוב השורה הפיזית בגיליון (+2)
        if (cloudEvents[i].calendarEventId.trim().isNotEmpty) {
          googleCalendarIdsToClean.add(cloudEvents[i].calendarEventId);
        }
      }
    }

    if (targetRowNumbers.isEmpty) {
      print('לא נמצאו אירועים המשויכים ללקוח זה בגיליון.');
      return [];
    }

    // 3. מיון מספרי השורות בסדר יורד (מהסוף להתחלה) בתוך ה-List
    // גוגל יעבד את פקודות ה-Batch לפי הסדר שנשלח לו, ולכן המיון היורד כאן מונע תזוזה מוקדמת של שורות!
    targetRowNumbers.sort((a, b) => b.compareTo(a));

    print('שולח פקודת Batch אחת מרוכזת למחיקת השורות הבאות (בסדר יורד): $targetRowNumbers');

    // 4. שליחת בקשת ה-Batch המרוכזת הבודדת לענן
    await _googleSheetsDataSource.deleteRowsBatch(spreadsheetId, 'events', targetRowNumbers);

    // 5. ניקוי ה-Cache המקומי של האירועים במכשיר
    final currentLocal = await _localDbDataSource.getEvents();
    currentLocal.removeWhere((e) => e.clientId == clientId);
    await _localDbDataSource.saveEvents(currentLocal);

    print('כל שורות האירועים של הלקוח נמחקו וצומצמו בהצלחה בענן וב-Cache באמצעות Batch Update.');

    return googleCalendarIdsToClean;
  }
}

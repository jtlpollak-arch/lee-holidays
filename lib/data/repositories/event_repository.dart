import 'dart:math';
import 'package:holidays/data/repositories/client_repository.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;

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
  Future<void> freezeEventsByClient(String spreadsheetId, String clientId);
  Future<void> unfreezeEventsByClient(String spreadsheetId, String clientId, String clientFullName);
}

class EventRepositoryImpl implements EventRepository {
  final GoogleSheetsDataSource _googleSheetsDataSource;
  final LocalDbDataSource _localDbDataSource;
  final GoogleCalendarApi _googleCalendarApi;
  final ClientRepository _clientRepository;

  EventRepositoryImpl({required GoogleSheetsDataSource googleSheetsDataSource, required LocalDbDataSource localDbDataSource, required GoogleCalendarApi googleCalendarApi, required ClientRepository clientRepository}) : _googleSheetsDataSource = googleSheetsDataSource, _localDbDataSource = localDbDataSource, _googleCalendarApi = googleCalendarApi, _clientRepository = clientRepository;

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

        // 2. משיכת רשימת הלקוחות מה-Cache, איתור הלקוח הספציפי ושליפת השם המלא שלו
        final clients = await _clientRepository.getAllClients(spreadsheetId);

        // חיפוש הלקוח ברשימה ללא יצירת אובייקט חדש
        String clientName = 'לקוח כללי';
        for (final c in clients) {
          if (c.id == event.clientId) {
            clientName = c.fullName;
            break;
          }
        }

        // בניית כותרת ותיאור מעודכנים ונקיים המכילים את שם הלקוח האמיתי
        final String calendarTitle = '$clientName - ${event.eventType}';
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

  @override
  Future<void> freezeEventsByClient(String spreadsheetId, String clientId) async {
    print('CbvEventRepo: מתחיל תהליך הקפאת אירועים מרוכזת (Batch) עבור לקוח: $clientId');

    // 1. משיכת כל האירועים הקיימים מהענן כדי לאתר את השורות המדויקות
    final List<EventModel> cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);

    final List<String> googleCalendarIdsToClean = [];
    final List<sheets.ValueRange> sheetsUpdateBatch = [];
    final List<EventModel> updatedLocalEvents = [];

    // 2. מעבר על האירועים ומיפוי השורות הפיזיות לצורך בניית ה-Batch
    for (int i = 0; i < cloudEvents.length; i++) {
      final event = cloudEvents[i];

      if (event.clientId == clientId) {
        final int sheetRowNumber = i + 2; // חישוב השורה הפיזית בגיליון (+2)

        // א. חילוץ מזהה הקלנדר במידה וקיים
        if (event.calendarEventId.trim().isNotEmpty) {
          googleCalendarIdsToClean.add(event.calendarEventId);
        }

        // ב. בניית אובייקט עדכון הטווח עבור טור I (calendarEventId) בגיליון Events
        final sheets.ValueRange valueRange = sheets.ValueRange(
          range: 'Events!I$sheetRowNumber:I$sheetRowNumber',
          values: [
            [''], // איפוס התא למחרוזת ריקה
          ],
        );
        sheetsUpdateBatch.add(valueRange);
      }
    }

    if (sheetsUpdateBatch.isEmpty) {
      print('CbvEventRepo: לא נמצאו אירועים לשיונוי או הקפאה עבור לקוח זה.');
      return;
    }

    // 3. ביצוע מחיקת Batch אטומי מול Google Calendar (קריאת רשת אחת)
    if (googleCalendarIdsToClean.isNotEmpty) {
      print('CbvEventRepo: מוחק ${googleCalendarIdsToClean.length} סדרות אירועים מיומן גוגל ב-Batch...');
      await _googleCalendarApi.deleteMultipleEventSeries(googleCalendarIdsToClean);
    }

    // 4. ביצוע איפוס מרוכז (Batch Update) של התאים בתוך Google Sheets (קריאת רשת אחת)
    print('CbvEventRepo: מאפס תאי מזהי קלנדר בגיליון שיטס ב-Batch עבור שורות הלקוח...');
    await _googleSheetsDataSource.updateValuesBatch(spreadsheetId, sheetsUpdateBatch);

    // 5. עדכון ה-Cache המקומי במכשיר לשמירה על אחידות הנתונים
    print('CbvEventRepo: מעדכן את בסיס הנתונים המקומי (Local Cache)...');
    final List<EventModel> currentLocal = await _localDbDataSource.getEvents();

    for (int i = 0; i < currentLocal.length; i++) {
      if (currentLocal[i].clientId == clientId) {
        currentLocal[i] = currentLocal[i].copyWith(calendarEventId: '');
      }
    }

    await _localDbDataSource.saveEvents(currentLocal);
    print('CbvEventRepo: תהליך הקפאת אירועי הלקוח הסתיים בהצלחה מלאה.');
  }

  @override
  Future<void> unfreezeEventsByClient(String spreadsheetId, String clientId, String clientFullName) async {
    print('CbvEventRepo: מתחיל תהליך שחזור אקטיבי (Unfreeze Batch) עבור לקוח: $clientFullName ($clientId)');

    // 1. משיכת כל האירועים הקיימים מהענן כדי לאתר את השורות והאירועים של הלקוח
    final List<EventModel> cloudEvents = await _googleSheetsDataSource.getEvents(spreadsheetId);

    final List<Map<String, dynamic>> calendarEventsToCreate = [];
    final List<int> targetSheetRowNumbers = [];
    final List<EventModel> clientEventsToUpdate = [];

    // 2. מיפוי ובניית המידע עבור ה-Batch של הקלנדר
    for (int i = 0; i < cloudEvents.length; i++) {
      final event = cloudEvents[i];

      if (event.clientId == clientId) {
        final int sheetRowNumber = i + 2; // חישוב השורה הפיזית בגיליון (+2)
        targetSheetRowNumbers.add(sheetRowNumber);
        clientEventsToUpdate.add(event);

        // בניית כותרת האירוע: שם מלא + סוג האירוע
        final String eventTitle = '$clientFullName - ${event.eventType}';

        // בניית גוף האירוע: כתובת הנכס + הערות
        final StringBuffer descBuilder = StringBuffer();
        if (event.address.trim().isNotEmpty) {
          descBuilder.writeln('כתובת הנכס: ${event.address}');
        }
        if (event.notes.trim().isNotEmpty) {
          descBuilder.writeln('הערות: ${event.notes}');
        }

        descBuilder.writeln(GoogleCalendarApiImpl.appSignature);

        calendarEventsToCreate.add({
          'title': eventTitle,
          'description': descBuilder.toString().trim(),
          'date': event.date, // העברת אובייקט ה-DateTime שמחזיק את היום והחודש
        });
      }
    }

    if (calendarEventsToCreate.isEmpty) {
      print('CbvEventRepo: לא נמצאו שורות אירועים לשחזור עבור לקוח זה.');
      return;
    }

    // 3. ביצוע יצירת Batch אטומי מול Google Calendar (קריאת רשת אחת לכל האירועים)
    print('CbvEventRepo: מקים מחדש ${calendarEventsToCreate.length} אירועים מחזוריים ביומן גוגל ב-Batch...');
    final List<String> newCalendarIds = await _googleCalendarApi.insertMultipleEventSeries(calendarEventsToCreate);

    if (newCalendarIds.length != calendarEventsToCreate.length) {
      throw Exception('שגיאה בסנכרון ה-Batch: כמות המזהים שחזרה מגוגל קלנדר (${newCalendarIds.length}) אינה תואמת לכמות האירועים שנשלחה (${calendarEventsToCreate.length})');
    }

    // 4. בניית רשימת אובייקטי ה-Batch לשיטס לצורך עדכון מזהי היומן החדשים בטור I
    final List<sheets.ValueRange> sheetsUpdateBatch = [];
    for (int i = 0; i < targetSheetRowNumbers.length; i++) {
      final int rowNumber = targetSheetRowNumbers[i];
      final String newId = newCalendarIds[i];

      final sheets.ValueRange valueRange = sheets.ValueRange(
        range: 'Events!I$rowNumber:I$rowNumber',
        values: [
          [newId], // השתלת מזהה היומן החדש בתא
        ],
      );
      sheetsUpdateBatch.add(valueRange);
    }

    // 5. ביצוע עדכון מרוכז (Batch Update) ב-Google Sheets (קריאת רשת אחת)
    print('CbvEventRepo: מעדכן מזהי יומן חדשים בגיליון שיטס ב-Batch...');
    await _googleSheetsDataSource.updateValuesBatch(spreadsheetId, sheetsUpdateBatch);

    // 6. עדכון ה-Cache המקומי במכשיר לשמירה על אחידות וסנכרון הנתונים
    print('CbvEventRepo: מעדכן את בסיס הנתונים המקומי (Local Cache) עם המזהים החדשים...');
    final List<EventModel> currentLocal = await _localDbDataSource.getEvents();

    for (int i = 0; i < currentLocal.length; i++) {
      if (currentLocal[i].clientId == clientId) {
        // מציאת האינדקס התואם ברשימה המקומית לפי מזהה השורה הייחודי (id)
        final int matchIndex = clientEventsToUpdate.indexWhere((e) => e.id == currentLocal[i].id);
        if (matchIndex != -1) {
          currentLocal[i] = currentLocal[i].copyWith(calendarEventId: newCalendarIds[matchIndex]);
        }
      }
    }

    await _localDbDataSource.saveEvents(currentLocal);
    print('CbvEventRepo: תהליך שחזור אקטיבי של אירועי הלקוח הסתיים בהצלחה מלאה.');
  }
}

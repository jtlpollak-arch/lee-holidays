import 'dart:convert';

import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;

/// החוזה (Interface) לעבודה מול Google Calendar API
abstract class GoogleCalendarApi {
  void updateAuthenticatedClient(http.Client client);

  /// יוצר תזכורת ביומן ומחזיר את ה-ID הייחודי של האירוע שנוצר
  Future<String> insertGreetingReminderEvent({required String title, required DateTime date, required String description, bool isRecurring = false});

  Future<void> deleteMultipleEventSeries(List<String> eventIds);

  Future<List<String>> insertMultipleEventSeries(List<Map<String, dynamic>> eventsData);

  /// מוחק סדרת אירועים שלמה (או אירוע בודד שאינו מחזורי) לפי ה-ID שלו
  Future<void> deleteEventSeries(String eventId);
}

/// המימוש בפועל של יצירת ותחזוקת תזכורות ביומן גוגל
class GoogleCalendarApiImpl implements GoogleCalendarApi {
  http.Client? _authenticatedClient;

  // נשתמש ביומן הראשי והברירת מחדל של המשתמשת
  static const String _primaryCalendarId = 'primary';

  GoogleCalendarApiImpl([this._authenticatedClient]);

  @override
  void updateAuthenticatedClient(http.Client client) {
    _authenticatedClient = client;
  }

  calendar.CalendarApi _getCalendarApi() {
    if (_authenticatedClient == null) {
      throw StateError('ה-Authenticated Client לא אותחל. יש להתחבר קודם.');
    }
    return calendar.CalendarApi(_authenticatedClient!);
  }

  @override
  Future<String> insertGreetingReminderEvent({required String title, required DateTime date, required String description, bool isRecurring = false}) async {
    final calendar.CalendarApi api = _getCalendarApi();

    // תיקון: הגדרת אובייקט ה-DateTime מראש כ-UTC בשעה 05:00
    final DateTime startDateTime = DateTime.utc(date.year, date.month, date.day, 5, 0);
    // הגדרת זמן סיום ל-05:15 UTC (אירוע ממוקד של 15 דקות)
    final DateTime endDateTime = startDateTime.add(const Duration(minutes: 15));

    // בניית אובייקט האירוע לפי המפרט של גוגל
    final calendar.Event event = calendar.Event(
      summary: title,
      description: description,
      start: calendar.EventDateTime(
        dateTime: startDateTime, // תיקון: מעבירים את ה-DateTime כפי שהוא, הוא כבר ב-UTC
        timeZone: 'UTC', // עבודה ב-UTC מונעת בעיות של שעון קיץ/חורף במכשירים שונים
      ),
      end: calendar.EventDateTime(
        dateTime: endDateTime, // תיקון: מעבירים את ה-DateTime כפי שהוא, הוא כבר ב-UTC
        timeZone: 'UTC',
      ),
      // אם מדובר ביום הולדת, נוסיף חוק מחזוריות שנתי ליומן
      recurrence: isRecurring ? ['RRULE:FREQ=YEARLY'] : null,
      // הגדרת התראה אקטיבית שתקפוץ על המסך בטלפון ברגע תחילת האירוע
      reminders: calendar.EventReminders(
        useDefault: false,
        overrides: [
          calendar.EventReminder(
            method: 'popup',
            minutes: 0, // התראה בדיוק בזמן תחילת האירוע
          ),
        ],
      ),
    );

    // שליחת הבקשה ליצירת האירוע ביומן הראשי
    final calendar.Event createdEvent = await api.events.insert(event, _primaryCalendarId);

    // החזרת ה-ID של האירוע שנוצר כדי שנוכל לשמור אותו במסד הנתונים לצורך מחיקה/עדכון בעתיד
    if (createdEvent.id == null) {
      throw Exception('נכשלה קבלת מזהה אירוע מ-Google Calendar');
    }

    return createdEvent.id!;
  }

  @override
  Future<void> deleteEventSeries(String eventId) async {
    final calendar.CalendarApi api = _getCalendarApi();

    try {
      // קריאה למחיקה של האירוע לפי ה-ID שלו.
      // אם מדובר באירוע מחזורי (Recurring), מחיקה של אב-הטיפוס מוחקת את כל הסדרה מהעבר ומהעתיד.
      await api.events.delete(_primaryCalendarId, eventId);
    } catch (e) {
      // טיפול בשגיאה במקרה שהאירוע כבר נמחק ידנית ביומן או שה-ID לא תקין
      throw Exception('נכשל ניסיון מחיקת האירוע מ-Google Calendar: $e');
    }
  }

  @override
  Future<void> deleteMultipleEventSeries(List<String> eventIds) async {
    print('CbvCalendarBatch: מתחיל תהליך מחיקת Batch אטומי של ${eventIds.length} אירועים מהיומן...');

    // סינון מזהים ריקים
    final validIds = eventIds.where((id) => id.trim().isNotEmpty).toList();

    if (validIds.isEmpty) {
      print('CbvCalendarBatch: לא נמצאו מזהי יומן תקינים למחיקת Batch.');
      return;
    }

    if (_authenticatedClient == null) {
      throw StateError('ה-Authenticated Client לא אותחל ב-DataSource.');
    }

    // 1. הגדרת נקודת הקצה הרשמית של גוגל ל-Batch בקלנדר
    final Uri batchUrl = Uri.parse('https://www.googleapis.com/batch/calendar/v3');

    // 2. יצירת בקשת HTTP גולמית מסוג POST (כדי שנוכל לשלוט על ה-Bytes של ה-body באופן מלא)
    final http.Request request = http.Request('POST', batchUrl);

    // 3. הגדרת ה-Headers הנדרשים עם ה-boundary המדויק
    request.headers['Content-Type'] = 'multipart/mixed; boundary=batch_boundary';

    // 4. בניית גוף הבקשה עם סיומות שורה קשיחות מסוג CRLF (\r\n) לפי הפרוטוקול הסטנדרטי של גוגל
    final StringBuffer bodyBuilder = StringBuffer();

    for (int i = 0; i < validIds.length; i++) {
      final String id = validIds[i];
      bodyBuilder.write('--batch_boundary\r\n');
      bodyBuilder.write('Content-Type: application/http\r\n');
      bodyBuilder.write('Content-ID: <item_${i + 1}>\r\n');
      bodyBuilder.write('\r\n');
      bodyBuilder.write('DELETE /calendar/v3/calendars/$_primaryCalendarId/events/$id HTTP/1.1\r\n');
      bodyBuilder.write('\r\n');
    }
    bodyBuilder.write('--batch_boundary--\r\n');

    // 5. המרת מחרוזת הטקסט ל-Bytes והזרקתה ישירות לתוך גוף ה-Request הראשי
    request.bodyBytes = utf8.encode(bodyBuilder.toString());

    try {
      // שליחת בקשת ה-Batch המאוחדת בערוץ המאומת (קריאת HTTP בודדת)
      final http.StreamedResponse response = await _authenticatedClient!.send(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('CbvCalendarBatch: בקשת ה-Batch בוצעה בהצלחה מלאה מול שרתי Google Calendar.');
      } else {
        throw Exception('שרת גוגל החזיר סטטוס שגיאה לבקשת ה-Batch: ${response.statusCode}');
      }
    } catch (e) {
      print('CbvCalendarBatch: שגיאה במהלך ביצוע בקשת ה-Batch בקלנדר: $e');
      throw Exception('נכשל ניסיון מחיקת ה-Batch מ-Google Calendar: $e');
    }
  }

  @override
  Future<List<String>> insertMultipleEventSeries(List<Map<String, dynamic>> eventsData) async {
    print('CbvCalendarBatch: מתחיל תהליך יצירת Batch אטומי של ${eventsData.length} אירועים מחזוריים ביומן...');

    if (eventsData.isEmpty) return [];

    if (_authenticatedClient == null) {
      throw StateError('ה-Authenticated Client לא אותחל ב-DataSource.');
    }

    final Uri batchUrl = Uri.parse('https://www.googleapis.com/batch/calendar/v3');
    final http.Request request = http.Request('POST', batchUrl);
    request.headers['Content-Type'] = 'multipart/mixed; boundary=batch_boundary';

    final StringBuffer bodyBuilder = StringBuffer();

    // בניית גוף ה-Batch המרוכז עבור כל אירוע ברשימה
    for (int i = 0; i < eventsData.length; i++) {
      final data = eventsData[i];
      final String title = data['title'] ?? '';
      final String description = data['description'] ?? '';
      final DateTime date = data['date'] ?? DateTime.now();

      // עיצוב התאריך הנוכחי לשנה הנוכחית בפורמט YYYY-MM-DD
      final String yearStr = DateTime.now().year.toString();
      final String monthStr = date.month.toString().padLeft(2, '0');
      final String dayStr = date.day.toString().padLeft(2, '0');
      final String baseDateStr = '$yearStr-$monthStr-$dayStr';

      // קביעת שעות קשיחות: התחלה ב-08:00, סיום ב-08:05 באזור זמן ישראל (+03:00)
      final String startDateTime = '${baseDateStr}T08:00:00+03:00';
      final String endDateTime = '${baseDateStr}T08:05:00+03:00';

      // בניית גוף ה-JSON הייעודי של גוגל עבור אירוע מחזורי קבוע בשעות מוגדרות
      final Map<String, dynamic> eventJson = {
        'summary': title,
        'description': description,
        'start': {'dateTime': startDateTime, 'timeZone': 'Asia/Jerusalem'},
        'end': {'dateTime': endDateTime, 'timeZone': 'Asia/Jerusalem'},
        'recurrence': ['RRULE:FREQ=YEARLY'],
      };

      final String jsonString = json.encode(eventJson);

      bodyBuilder.write('--batch_boundary\r\n');
      bodyBuilder.write('Content-Type: application/http\r\n');
      bodyBuilder.write('Content-ID: <item_${i + 1}>\r\n');
      bodyBuilder.write('\r\n');
      bodyBuilder.write('POST /calendar/v3/calendars/$_primaryCalendarId/events HTTP/1.1\r\n');
      bodyBuilder.write('Content-Type: application/json\r\n');
      bodyBuilder.write('Content-Length: ${utf8.encode(jsonString).length}\r\n');
      bodyBuilder.write('\r\n');
      bodyBuilder.write('$jsonString\r\n');
      bodyBuilder.write('\r\n');
    }
    bodyBuilder.write('--batch_boundary--\r\n');

    request.bodyBytes = utf8.encode(bodyBuilder.toString());

    final List<String> createdEventIds = [];

    try {
      final http.StreamedResponse response = await _authenticatedClient!.send(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final String responseBody = await response.stream.bytesToString();
        print('CbvCalendarBatch: תגובת ה-Batch התקבלה משרתי גוגל. מפענח מזהים...');

        // פענוח מזהי ה-ID מתוך תגובת ה-Multipart של גוגל באמצעות RegExp מהיר וחסין
        final RegExp idExp = RegExp(r'"id":\s*"([^"]+)"');
        final matches = idExp.allMatches(responseBody);

        for (final match in matches) {
          if (match.groupCount >= 1) {
            createdEventIds.add(match.group(1)!);
          }
        }

        print('CbvCalendarBatch: חולצו בהצלחה ${createdEventIds.length} מזהי אירועים חדשים מהיומן.');
        return createdEventIds;
      } else {
        throw Exception('שרת גוגל החזיר סטטוס שגיאה לבקשת ה-Insert Batch: ${response.statusCode}');
      }
    } catch (e) {
      print('CbvCalendarBatch: שגיאה במהלך ביצוע יצירת ה-Batch בקלנדר: $e');
      throw Exception('נכשל ניסיון יצירת ה-Batch ב-Google Calendar: $e');
    }
  }
}

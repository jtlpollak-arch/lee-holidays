import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;

/// החוזה (Interface) לעבודה מול Google Calendar API
abstract class GoogleCalendarApi {
  void updateAuthenticatedClient(http.Client client);

  /// יוצר תזכורת ביומן ומחזיר את ה-ID הייחודי של האירוע שנוצר
  Future<String> insertGreetingReminderEvent({required String title, required DateTime date, required String description, bool isRecurring = false});

  Future<void> deleteMultipleEventSeries(List<String> eventIds);

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
    print('מתחיל תהליך מחיקה מקבילית של ${eventIds.length} אירועים מהיומן...');

    // סינון מזהים ריקים כדי לא לבזבז קריאות רשת
    final validIds = eventIds.where((id) => id.trim().isNotEmpty).toList();

    if (validIds.isEmpty) {
      print('לא נמצאו מזהי יומן תקינים למחיקה מקבילית.');
      return;
    }

    // הפעלת כל פקודות המחיקה בו-זמנית בענן של גוגל
    await Future.wait(
      validIds.map((id) async {
        try {
          await deleteEventSeries(id);
        } catch (e) {
          // תפיסת שגיאה נקודתית כדי שאירוע בודד שלא נמצא לא יפיל את שאר המחיקות
          print('אירוע $id לא נמחק מהיומן (ייתכן שנמחק ידנית בעבר): $e');
        }
      }),
    );

    print('סיום תהליך מחיקת האירועים המקבילית מהיומן.');
  }
}

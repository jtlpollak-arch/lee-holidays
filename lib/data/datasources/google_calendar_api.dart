import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;

/// החוזה (Interface) לעבודה מול Google Calendar API
abstract class GoogleCalendarApi {
  Future<void> insertGreetingReminderEvent({required String title, required DateTime date, required String description});
}

/// המימוש בפועל של יצירת תזכורות ביומן גוגל
class GoogleCalendarApiImpl implements GoogleCalendarApi {
  final http.Client _authenticatedClient;

  // נשתמש ביומן הראשי והברירת מחדל של המשתמשת
  static const String _primaryCalendarId = 'primary';

  GoogleCalendarApiImpl(this._authenticatedClient);

  calendar.CalendarApi _getCalendarApi() => calendar.CalendarApi(_authenticatedClient);

  @override
  Future<void> insertGreetingReminderEvent({required String title, required DateTime date, required String description}) async {
    final calendar.CalendarApi api = _getCalendarApi();

    // הגדרת זמן תחילת האירוע ל-08:00 בבוקר בתאריך המבוקש
    final DateTime startDateTime = DateTime(date.year, date.month, date.day, 8, 0);
    // הגדרת זמן סיום ל-08:05 (אירוע ממוקד של 5 דקות)
    final DateTime endDateTime = startDateTime.add(const Duration(minutes: 5));

    // בניית אובייקט האירוע לפי המפרט של גוגל
    final calendar.Event event = calendar.Event(
      summary: title,
      description: description,
      start: calendar.EventDateTime(
        dateTime: startDateTime.toUtc(),
        timeZone: 'UTC', // עבודה ב-UTC מונעת בעיות של שעון קיץ/חורף במכשירים שונים
      ),
      end: calendar.EventDateTime(dateTime: endDateTime.toUtc(), timeZone: 'UTC'),
      // הגדרת התראה אקטיבית שתקפוץ על המסך בטלפון ברגע תחילת האירוע
      reminders: calendar.EventReminders(
        useDefault: false,
        overrides: [
          calendar.EventReminder(
            method: 'popup',
            minutes: 0, // בדיוק בשעה 08:00
          ),
        ],
      ),
    );

    try {
      await api.events.insert(event, _primaryCalendarId);
    } catch (e) {
      // כאן ניתן להוסיף טיפול בשגיאות רשת או הרשאות במידת הצורך בעתיד
      rethrow;
    }
  }
}

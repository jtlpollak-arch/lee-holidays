import '../../data/models/client_model.dart';
import '../../data/models/event_model.dart';

/// מחלקת עזר המייצגת אירוע יומי מעובד שמוכן להצגה במסך הבית
class DailyEventResult {
  final ClientModel client;
  final EventModel event;
  final bool isEarlyReminder; // האם האירוע הוקדם בגלל שבת/חג
  final String displayMessage; // הודעת תיוג (למשל: "חל מחר בשבת - שליחה מוקדמת")

  DailyEventResult({required this.client, required this.event, required this.isEarlyReminder, required this.displayMessage});
}

/// Use Case האחראי על פילוח וחישוב האירועים שיש להציג היום למשתמשת
class CalculateDailyEventsUseCase {
  /// הפונקציה המרכזית שמקבלת את כל המידע ומחזירה רק את מה שרלוונטי להיום
  List<DailyEventResult> execute({required List<ClientModel> allClients, required List<EventModel> allEvents, required DateTime today}) {
    final List<DailyEventResult> results = [];

    // יצירת מפה (Map) של לקוחות לפי ה-ID שלהם לגישה מהירה ב-O(1)
    final Map<int, ClientModel> clientMap = {for (var client in allClients) client.id: client};

    // הגדרת תאריכי הבדיקה (היום, מחר, ומחרתיים) ללא שעות/דקות לצורך השוואה נקייה
    final DateTime dateToday = DateTime(today.year, today.month, today.day);
    final DateTime dateTomorrow = dateToday.add(const Duration(days: 1));
    final DateTime dateDayAfterTomorrow = dateToday.add(const Duration(days: 2));

    for (var event in allEvents) {
      final ClientModel? client = clientMap[event.clientId];
      if (client == null) continue; // אם הלקוח לא קיים במערכת, נדלג על האירוע

      // נרמול תאריך האירוע ללא שעות (כדי להשוות רק יום וחודש, ללא תלות בשנת הלידה)
      final DateTime eventDateNormalized = DateTime(dateToday.year, event.date.month, event.date.day);

      // 1. בדיקה האם האירוע חל ממש היום
      if (eventDateNormalized == dateToday) {
        results.add(DailyEventResult(client: client, event: event, isEarlyReminder: false, displayMessage: 'אירוע של היום'));
      }
      // 2. מנגנון הקדמת שבת חכם:
      // אם מחר יום שישי (והאירוע חל מחר), או מחר יום שבת (והאירוע חל מחר) - נקדים אותו להיום
      else if (eventDateNormalized == dateTomorrow) {
        if (dateTomorrow.weekday == DateTime.friday || dateTomorrow.weekday == DateTime.saturday) {
          final String dayName = dateTomorrow.weekday == DateTime.friday ? 'שישי' : 'שבת';
          results.add(DailyEventResult(client: client, event: event, isEarlyReminder: true, displayMessage: 'חל מחר ביום $dayName - שליחה מוקדמת'));
        }
      }
      // אם מחרתיים יום שבת (והאירוע חל מחרתיים) והיום יום חמישי - נקדים אותו להיום (חמישי)
      else if (eventDateNormalized == dateDayAfterTomorrow) {
        if (dateDayAfterTomorrow.weekday == DateTime.saturday && dateToday.weekday == DateTime.thursday) {
          results.add(DailyEventResult(client: client, event: event, isEarlyReminder: true, displayMessage: 'חל בשבת - שליחה מוקדמת מראש'));
        }
      }
    }

    return results;
  }
}

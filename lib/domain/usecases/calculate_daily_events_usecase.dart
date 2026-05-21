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
    final Map<String, ClientModel> clientMap = {for (var client in allClients) client.id: client};

    // איפוס שעות, דקות ושניות לצורך השוואת תאריכים נקייה
    final dateToday = DateTime(today.year, today.month, today.day);
    final dateTomorrow = dateToday.add(const Duration(days: 1));
    final dateAfterTomorrow = dateToday.add(const Duration(days: 2));

    for (var event in allEvents) {
      if (!event.isActive) continue;

      // שליפת הלקוח המתאים מתוך המפה לפי ה-clientId של האירוע
      final client = clientMap[event.clientId];
      if (client == null || !client.isActive) continue; // הגנה: אם הלקוח לא נמצא (למשל נמחק לחלוטין), נדלג על האירוע

      // יצירת תאריך לבדיקה - עבור יום הולדת נשליך לשנה הנוכחית, עבור אירוע נדל"ן את התאריך המקורי
      DateTime eventDateToCheck;
      if (event.eventType == 'יום הולדת') {
        eventDateToCheck = DateTime(dateToday.year, event.date.month, event.date.day);
      } else {
        eventDateToCheck = DateTime(event.date.year, event.date.month, event.date.day);
      }

      // 1. בדיקה האם האירוע חל ממש היום
      if (eventDateToCheck == dateToday) {
        results.add(DailyEventResult(client: client, event: event, isEarlyReminder: false, displayMessage: 'אירוע של היום'));
      }
      // 2. מנגנון הקדמת שבת חכם:
      // אם מחר יום שישי או שבת (והאירוע חל מחר) - נקדים אותו להיום
      else if (eventDateToCheck == dateTomorrow) {
        if (dateTomorrow.weekday == DateTime.friday || dateTomorrow.weekday == DateTime.saturday) {
          final String dayName = dateTomorrow.weekday == DateTime.friday ? 'שישי' : 'שבת';
          results.add(DailyEventResult(client: client, event: event, isEarlyReminder: true, displayMessage: 'חל מחר ביום $dayName - שליחה מוקדמת'));
        }
      }
      // אם מחרתיים יום שבת (והאירוע חל מחרתיים) והיום יום חמישי - נקדים אותו להיום (חמישי)
      else if (eventDateToCheck == dateAfterTomorrow) {
        // כאן תוקן ה-thursday ללא רווח ובאות קטנה
        if (dateAfterTomorrow.weekday == DateTime.saturday && dateToday.weekday == DateTime.thursday) {
          results.add(DailyEventResult(client: client, event: event, isEarlyReminder: true, displayMessage: 'חל בשבת - שליחה מוקדמת ביום חמישי'));
        }
      }
    }

    return results;
  }
}

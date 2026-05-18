import 'package:meta/meta.dart';

@immutable
class EventModel {
  final int clientId;
  final DateTime date;
  final String eventType;
  final String notes;

  const EventModel({required this.clientId, required this.date, required this.eventType, required this.notes});

  /// קונסטרקטור חכם המקבל שורה גולמית מטאב האירועים ב-Google Sheets
  /// וממיר אותה לאובייקט אירוע באפליקציה.
  factory EventModel.fromSheetsRow(List<dynamic> row) {
    final int parsedClientId = row.isNotEmpty ? int.tryParse(row[0].toString()) ?? 0 : 0;

    // פענוח התאריך מפורמט DD/MM/YYYY ל-DateTime
    DateTime parsedDate = DateTime.now();
    if (row.length > 1 && row[1] != null) {
      final String dateStr = row[1].toString().trim();
      final List<String> parts = dateStr.split('/');
      if (parts.length == 3) {
        final int? day = int.tryParse(parts[0]);
        final int? month = int.tryParse(parts[1]);
        final int? year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          parsedDate = DateTime(year, month, day);
        }
      }
    }

    final String parsedEventType = row.length > 2 ? row[2].toString().trim() : '';
    final String parsedNotes = row.length > 3 ? row[3].toString().trim() : '';

    return EventModel(clientId: parsedClientId, date: parsedDate, eventType: parsedEventType, notes: parsedNotes);
  }

  /// מתודה הממירה את אובייקט האירוע למבנה של שורה (רשימה)
  /// לצורך כתיבה או עדכון ב-Google Sheets בפורמט קבוע.
  List<dynamic> toSheetsRow() {
    // פורמט ידני של התאריך ל-DD/MM/YYYY כדי לא להסתמך על חבילות חיצוניות בשלב זה
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String year = date.year.toString();
    final String formattedDate = '$day/$month/$year';

    return [clientId, formattedDate, eventType, notes];
  }

  /// יצירת עותק חדש עם שינויים במידת הצורך (נחוץ לניהול מצב באפליקציה)
  EventModel copyWith({int? clientId, DateTime? date, String? eventType, String? notes}) {
    return EventModel(clientId: clientId ?? this.clientId, date: date ?? this.date, eventType: eventType ?? this.eventType, notes: notes ?? this.notes);
  }
}

class EventModel {
  final String clientPhone; // הקישור ללקוח נעשה כעת ישירות באמצעות מספר הטלפון שלו
  final DateTime date;
  final String eventType;
  final String address; // כתובת הנכס / אזור המשויכת לאירוע
  final String notes;
  final String status; // פעיל / מחוק
  final String sentTimestamp; // חותמת זמן של השליחה האחרונה בפועל (טור G בשיטס)

  EventModel({required this.clientPhone, required this.date, required this.eventType, required this.address, required this.notes, required this.status, this.sentTimestamp = ''});

  /// האם האירוע פעיל במערכת
  bool get isActive => status == 'פעיל';

  /// המרה מרשימה (שורת גיליון בגוגל שיטס) למודל אירוע (A עד G)
  factory EventModel.fromRow(List<dynamic> row) {
    return EventModel(
      clientPhone: row.isNotEmpty ? row[0].toString() : '',
      date: row.length > 1 ? DateTime.tryParse(row[1].toString()) ?? DateTime.now() : DateTime.now(),
      eventType: row.length > 2 ? row[2].toString() : '',
      address: row.length > 3 ? row[3].toString() : '', // קריאת טור D
      notes: row.length > 4 ? row[4].toString() : '', // קריאת טור E
      status: row.length > 5 ? row[5].toString() : 'פעיל', // קריאת טור F
      sentTimestamp: row.length > 6 ? row[6].toString() : '', // קריאת טור G
    );
  }

  /// המרה של מודל אירוע לשורה עבור גוגל שיטס
  List<dynamic> toRow() {
    return [
      clientPhone,
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      eventType,
      address, // כתיבה לטור D
      notes, // כתיבה לטור E
      status, // כתיבה לטור F
      sentTimestamp, // כתיבה לטור G
    ];
  }

  /// המרה ממפה (בסיס נתונים מקומי) למודל
  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(clientPhone: json['clientPhone'] as String? ?? '', date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(), eventType: json['eventType'] as String? ?? '', address: json['address'] as String? ?? '', notes: json['notes'] as String? ?? '', status: json['status'] as String? ?? 'פעיל', sentTimestamp: json['sentTimestamp'] as String? ?? '');
  }

  /// המרה ממודל למפה (עבור בסיס נתונים מקומי)
  Map<String, dynamic> toJson() {
    return {'clientPhone': clientPhone, 'date': date.toIso8601String(), 'eventType': eventType, 'address': address, 'notes': notes, 'status': status, 'sentTimestamp': sentTimestamp};
  }

  /// יצירת עותק חדש של המודל עם ערכים מעודכנים ספציפיים
  EventModel copyWith({String? clientPhone, DateTime? date, String? eventType, String? address, String? notes, String? status, String? sentTimestamp}) {
    return EventModel(clientPhone: clientPhone ?? this.clientPhone, date: date ?? this.date, eventType: eventType ?? this.eventType, address: address ?? this.address, notes: notes ?? this.notes, status: status ?? this.status, sentTimestamp: sentTimestamp ?? this.sentTimestamp);
  }
}

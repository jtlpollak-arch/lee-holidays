class EventModel {
  final String id; // מזהה ייחודי עבור כל שורה - טור A בגוגל שיטס
  final String clientPhone; // הקישור ללקוח נעשה כעת ישירות באמצעות מספר הטלפון שלו
  final DateTime date;
  final String eventType;
  final String address; // כתובת הנכס / אזור המשויכת לאירוע
  final String notes;
  final String status; // פעיל / מחוק
  final String sentTimestamp; // חותמת זמן של השליחה האחרונה בפועל (טור H בשיטס)

  EventModel({
    this.id = '', // אופציונלי עם ערך דיפולטיבי למניעת שבירת קריאות קיימות באפליקציה
    required this.clientPhone,
    required this.date,
    required this.eventType,
    required this.address,
    required this.notes,
    required this.status,
    this.sentTimestamp = '',
  });

  /// האם האירוע פעיל במערכת
  bool get isActive => status == 'פעיל';

  /// המרה מרשימה (שורת גיליון בגוגל שיטס) למודל אירוע (עמודות A עד H)
  factory EventModel.fromRow(List<dynamic> row) {
    return EventModel(
      id: row.isNotEmpty ? row[0].toString() : '',
      clientPhone: row.length > 1 ? row[1].toString() : '',
      date: row.length > 2 ? DateTime.tryParse(row[2].toString()) ?? DateTime.now() : DateTime.now(),
      eventType: row.length > 3 ? row[3].toString() : '',
      address: row.length > 4 ? row[4].toString() : '', // קריאת טור E
      notes: row.length > 5 ? row[5].toString() : '', // קריאת טור F
      status: row.length > 6 ? row[6].toString() : 'פעיל', // קריאת טור G
      sentTimestamp: row.length > 7 ? row[7].toString() : '', // קריאת טור H
    );
  }

  /// המרה של מודל אירוע לשורה עבור גוגל שיטס (8 עמודות: A עד H)
  List<dynamic> toRow() {
    return [
      id, // כתיבה לטור A
      clientPhone, // כתיבה לטור B
      "${date.year.toString()}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}", // כתיבה לטור C
      eventType, // כתיבה לטור D
      address, // כתיבה לטור E
      notes, // כתיבה לטור F
      status, // כתיבה לטור G
      sentTimestamp, // כתיבה לטור H
    ];
  }

  /// המרה ממפה (בסיס נתונים מקומי) למודל
  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(id: json['id'] as String? ?? '', clientPhone: json['clientPhone'] as String? ?? '', date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(), eventType: json['eventType'] as String? ?? '', address: json['address'] as String? ?? '', notes: json['notes'] as String? ?? '', status: json['status'] as String? ?? 'פעיל', sentTimestamp: json['sentTimestamp'] as String? ?? '');
  }

  /// המרה ממודל למפה (עבור בסיס נתונים מקומי)
  Map<String, dynamic> toJson() {
    return {'id': id, 'clientPhone': clientPhone, 'date': date.toIso8601String(), 'eventType': eventType, 'address': address, 'notes': notes, 'status': status, 'sentTimestamp': sentTimestamp};
  }

  /// יצירת עותק חדש של המודל עם ערכים מעודכנים ספציפיים
  EventModel copyWith({String? id, String? clientPhone, DateTime? date, String? eventType, String? address, String? notes, String? status, String? sentTimestamp}) {
    return EventModel(id: id ?? this.id, clientPhone: clientPhone ?? this.clientPhone, date: date ?? this.date, eventType: eventType ?? this.eventType, address: address ?? this.address, notes: notes ?? this.notes, status: status ?? this.status, sentTimestamp: sentTimestamp ?? this.sentTimestamp);
  }
}

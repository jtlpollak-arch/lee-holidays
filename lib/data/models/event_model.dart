class EventModel {
  final String id; // מזהה ייחודי עבור כל שורה - טור A בגוגל שיטס
  final String clientId; // הקישור ללקוח נעשה כעת באמצעות ה-ID הקשיח שלו - טור B בגוגל שיטס
  final DateTime date;
  final String eventType;
  final String address; // כתובת הנכס / אזור המשויכת לאירוע
  final String notes;
  final String status; // פעיל / מחוק
  final String sentTimestamp; // חותמת זמן של השליחה האחרונה בפועל (טור H בשיטס)
  final String calendarEventId; // מזהה האירוע הרשמי ביומן גוגל (טור I בשיטס)

  EventModel({
    this.id = '', // אופציונלי עם ערך דיפולטיבי למניעת שבירת קריאות קיימות באפליקציה
    required this.clientId,
    required this.date,
    required this.eventType,
    required this.address,
    required this.notes,
    required this.status,
    this.sentTimestamp = '',
    this.calendarEventId = '', // ערך ברירת מחדל ריק לשמירה על תאימות מלאה בקוד הקיים
  });

  /// האם האירוע פעיל במערכת
  bool get isActive => status == 'פעיל';

  /// המרה מרשימה (שורת גיליון בגוגל שיטס) למודל אירוע (עמודות A עד I)
  factory EventModel.fromRow(List<dynamic> row) {
    return EventModel(
      id: row.isNotEmpty ? row[0].toString() : '',
      clientId: row.length > 1 ? row[1].toString() : '',
      date: row.length > 2 ? (DateTime.tryParse(row[2].toString()) ?? DateTime.now()) : DateTime.now(),
      eventType: row.length > 3 ? row[3].toString() : '',
      address: row.length > 4 ? row[4].toString() : '',
      notes: row.length > 5 ? row[5].toString() : '',
      status: row.length > 6 ? row[6].toString() : 'פעיל',
      sentTimestamp: row.length > 7 ? row[7].toString() : '',
      // משיכת העמודה התשיעית בצורה מוגנת למניעת שבירה של שורות ישנות בגיליון
      calendarEventId: row.length > 8 ? row[8].toString() : '',
    );
  }

  /// המרה ממודל לרשימה שטוחה לצורך כתיבה חזרה לגיליון (עמודות A עד I)
  List<dynamic> toRow() {
    return [
      id,
      clientId,
      date.toIso8601String(),
      eventType,
      address,
      notes,
      status,
      sentTimestamp,
      calendarEventId, // נכתב כטור התשיעי (טור I) בגיליון
    ];
  }

  /// המרה ממפה (בסיס נתונים מקומי) למודל
  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '', // המרה מהמפתח החדש ב-JSON
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      eventType: json['eventType'] as String? ?? '',
      address: json['address'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      status: json['status'] as String? ?? 'פעיל',
      sentTimestamp: json['sentTimestamp'] as String? ?? '',
      calendarEventId: json['calendarEventId'] as String? ?? '',
    );
  }

  /// המרה ממודל למפה (עבור בסיס נתונים מקומי)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId, // שמירה לפי clientId
      'date': date.toIso8601String(),
      'eventType': eventType,
      'address': address,
      'notes': notes,
      'status': status,
      'sentTimestamp': sentTimestamp,
      'calendarEventId': calendarEventId,
    };
  }

  /// יצירת עותק חדש של המודל עם ערכים מעודכנים ספציפיים
  EventModel copyWith({String? id, String? clientId, DateTime? date, String? eventType, String? address, String? notes, String? status, String? sentTimestamp, String? calendarEventId}) {
    return EventModel(id: id ?? this.id, clientId: clientId ?? this.clientId, date: date ?? this.date, eventType: eventType ?? this.eventType, address: address ?? this.address, notes: notes ?? this.notes, status: status ?? this.status, sentTimestamp: sentTimestamp ?? this.sentTimestamp, calendarEventId: calendarEventId ?? this.calendarEventId);
  }
}

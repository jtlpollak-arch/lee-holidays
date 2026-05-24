class ClientModel {
  final String id; // המפתח הראשי הקבוע והחדש של הלקוח - טור A בגוגל שיטס
  final String fullName;
  final String firstName;
  final String phone; // שדה הטלפון הופך לשדה טקסט רגיל שניתן לעריכה ושינוי בעתיד - טור B בגוגל שיטס
  final String email;
  final String status; // פעיל / מחוק
  final String notes; // הערות קבועות ללקוח - טור G בגוגל שיטס

  ClientModel({
    required this.id,
    required this.fullName,
    required this.firstName,
    required this.phone,
    required this.email,
    required this.status,
    this.notes = '', // הגדרה כאופציונלי עם ערך ברירת מחדל כדי לא לשבור קריאות קיימות באפליקציה
  });

  /// האם הלקוח פעיל במערכת
  bool get isActive => status == 'פעיל';

  /// המרה מרשימה (שורת גיליון בגוגל שיטס) למודל לקוח (A עד G)
  factory ClientModel.fromRow(List<dynamic> row) {
    return ClientModel(
      id: row.isNotEmpty ? row[0].toString() : '',
      phone: row.length > 1 ? row[1].toString() : '',
      fullName: row.length > 2 ? row[2].toString() : '',
      firstName: row.length > 3 ? row[3].toString() : '',
      email: row.length > 4 ? row[4].toString() : '',
      status: row.length > 5 ? row[5].toString() : 'פעיל',
      notes: row.length > 6 ? row[6].toString() : '', // קריאת אינדקס 6 (עמודה G) במידה וקיים
    );
  }

  /// המרה של מודל לקוח לשורה עבור גוגל שיטס
  List<dynamic> toRow() {
    return [id, phone, fullName, firstName, email, status, notes]; // הוספת notes כאיבר השביעי בשורה
  }

  /// המרה ממפה (בסיס נתונים מקומי / Cache) למודל
  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      status: json['status'] as String? ?? 'פעיל',
      notes: json['notes'] as String? ?? '', // קריאת שדה ההערות מה-Cache
    );
  }

  /// המרה ממודל למפה (עבור בסיס נתונים מקומי / Cache)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'fullName': fullName,
      'firstName': firstName,
      'email': email,
      'status': status,
      'notes': notes, // שמירת שדה ההערות לתוך ה-Cache
    };
  }

  /// יצירת עותק מעודכן של הלקוח (שימושי לצורכי השוואה או עדכונים מקומיים)
  ClientModel copyWith({String? id, String? fullName, String? firstName, String? phone, String? email, String? status, String? notes}) {
    return ClientModel(id: id ?? this.id, fullName: fullName ?? this.fullName, firstName: firstName ?? this.firstName, phone: phone ?? this.phone, email: email ?? this.email, status: status ?? this.status, notes: notes ?? this.notes);
  }
}

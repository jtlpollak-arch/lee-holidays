class ClientModel {
  final String id; // המפתח הראשי הקבוע והחדש של הלקוח - טור A בגוגל שיטס
  final String fullName;
  final String firstName;
  final String phone; // שדה הטלפון הופך לשדה טקסט רגיל שניתן לעריכה ושינוי בעתיד - טור B בגוגל שיטס
  final String email;
  final String status; // פעיל / מחוק

  ClientModel({required this.id, required this.fullName, required this.firstName, required this.phone, required this.email, required this.status});

  /// האם הלקוח פעיל במערכת
  bool get isActive => status == 'פעיל';

  /// המרה מרשימה (שורת גיליון בגוגל שיטס) למודל לקוח (A עד F)
  factory ClientModel.fromRow(List<dynamic> row) {
    return ClientModel(id: row.isNotEmpty ? row[0].toString() : '', phone: row.length > 1 ? row[1].toString() : '', fullName: row.length > 2 ? row[2].toString() : '', firstName: row.length > 3 ? row[3].toString() : '', email: row.length > 4 ? row[4].toString() : '', status: row.length > 5 ? row[5].toString() : 'פעיל');
  }

  /// המרה של מודל לקוח לשורה עבור גוגל שיטס
  List<dynamic> toRow() {
    return [id, phone, fullName, firstName, email, status];
  }

  /// המרה ממפה (בסיס נתונים מקומי / Cache) למודל
  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(id: json['id'] as String? ?? '', phone: json['phone'] as String? ?? '', fullName: json['fullName'] as String? ?? '', firstName: json['firstName'] as String? ?? '', email: json['email'] as String? ?? '', status: json['status'] as String? ?? 'פעיל');
  }

  /// המרה ממודל למפה (עבור בסיס נתונים מקומי / Cache)
  Map<String, dynamic> toJson() {
    return {'id': id, 'phone': phone, 'fullName': fullName, 'firstName': firstName, 'email': email, 'status': status};
  }

  /// יצירת עותק חדש של המודל עם ערכים מעודכנים ספציפיים
  ClientModel copyWith({String? id, String? fullName, String? firstName, String? phone, String? email, String? status}) {
    return ClientModel(id: id ?? this.id, fullName: fullName ?? this.fullName, firstName: firstName ?? this.firstName, phone: phone ?? this.phone, email: email ?? this.email, status: status ?? this.status);
  }
}

class ClientModel {
  final String fullName;
  final String firstName;
  final String phone; // שדה הטלפון הופך למפתח הראשי הבלעדי של הלקוח
  final String email;
  final String status; // פעיל / מחוק

  ClientModel({required this.fullName, required this.firstName, required this.phone, required this.email, required this.status});

  /// האם הלקוח פעיל במערכת
  bool get isActive => status == 'פעיל';

  /// המרה מרשימה (שורת גיליון בגוגל שיטס) למודל לקוח (A עד E)
  factory ClientModel.fromRow(List<dynamic> row) {
    return ClientModel(phone: row.isNotEmpty ? row[0].toString() : '', fullName: row.length > 1 ? row[1].toString() : '', firstName: row.length > 2 ? row[2].toString() : '', email: row.length > 3 ? row[3].toString() : '', status: row.length > 4 ? row[4].toString() : 'פעיל');
  }

  /// המרה של מודל לקוח לשורה עבור גוגל שיטס
  List<dynamic> toRow() {
    return [phone, fullName, firstName, email, status];
  }

  /// המרה ממפה (בסיס נתונים מקומי / Cache) למודל
  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(phone: json['phone'] as String? ?? '', fullName: json['fullName'] as String? ?? '', firstName: json['firstName'] as String? ?? '', email: json['email'] as String? ?? '', status: json['status'] as String? ?? 'פעיל');
  }

  /// המרה של המודל למפה עבור בסיס הנתונים המקומי
  Map<String, dynamic> toJson() {
    return {'phone': phone, 'fullName': fullName, 'firstName': firstName, 'email': email, 'status': status};
  }
}

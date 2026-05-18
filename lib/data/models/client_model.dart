class ClientModel {
  final int id;
  final String fullName;
  final String firstName;
  final String phone;
  final String email;
  final String status; // פעיל / מחוק

  ClientModel({required this.id, required this.fullName, required this.firstName, required this.phone, required this.email, required this.status});

  /// האם הלקוח פעיל במערכת
  bool get isActive => status == 'פעיל';

  /// המרה מרשימה (שורת גיליון בגוגל שיטס) למודל לקוח (A עד F)
  factory ClientModel.fromRow(List<dynamic> row) {
    return ClientModel(id: int.tryParse(row[0].toString()) ?? 0, fullName: row.length > 1 ? row[1].toString() : '', firstName: row.length > 2 ? row[2].toString() : '', phone: row.length > 3 ? row[3].toString() : '', email: row.length > 4 ? row[4].toString() : '', status: row.length > 5 ? row[5].toString() : 'פעיל');
  }

  /// המרה של מודל לקוח לשורה עבור גוגל שיטס
  List<dynamic> toRow() {
    return [id, fullName, firstName, phone, email, status];
  }

  /// המרה ממפה (בסיס נתונים מקומי / Cache) למודל
  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(id: json['id'] as int, fullName: json['fullName'] as String? ?? '', firstName: json['firstName'] as String? ?? '', phone: json['phone'] as String? ?? '', email: json['email'] as String? ?? '', status: json['status'] as String? ?? 'פעיל');
  }

  /// המרה של המודל למפה עבור בסיס הנתונים המקומי
  Map<String, dynamic> toJson() {
    return {'id': id, 'fullName': fullName, 'firstName': firstName, 'phone': phone, 'email': email, 'status': status};
  }
}

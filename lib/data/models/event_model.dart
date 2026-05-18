class EventModel {
  final int clientId;
  final DateTime date;
  final String eventType;
  final String address; // כתובת הנכס / אזור הועברה לכאן!
  final String notes;
  final String status; // פעיל / מחוק

  EventModel({required this.clientId, required this.date, required this.eventType, required this.address, required this.notes, required this.status});

  /// האם האירוע פעיל במערכת
  bool get isActive => status == 'פעיל';

  /// המרה מרשימה (שורת גיליון בגוגל שיטס) למודל אירוע (A עד F)
  factory EventModel.fromRow(List<dynamic> row) {
    return EventModel(
      clientId: int.tryParse(row[0].toString()) ?? 0,
      date: row.length > 1 ? DateTime.tryParse(row[1].toString()) ?? DateTime.now() : DateTime.now(),
      eventType: row.length > 2 ? row[2].toString() : '',
      address: row.length > 3 ? row[3].toString() : '', // קריאת טור D
      notes: row.length > 4 ? row[4].toString() : '', // קריאת טור E
      status: row.length > 5 ? row[5].toString() : 'פעיל', // קריאת טור F
    );
  }

  /// המרה של מודל אירוע לשורה עבור גוגל שיטס
  List<dynamic> toRow() {
    return [
      clientId,
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      eventType,
      address, // כתיבה לטור D
      notes, // כתיבה לטור E
      status, // כתיבה לטור F
    ];
  }

  /// המרה ממפה (בסיס נתונים מקומי) למודל
  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(clientId: json['clientId'] as int, date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(), eventType: json['eventType'] as String? ?? '', address: json['address'] as String? ?? '', notes: json['notes'] as String? ?? '', status: json['status'] as String? ?? 'פעיל');
  }

  /// המרה של המודל למפה עבור בסיס הנתונים המקומי
  Map<String, dynamic> toJson() {
    return {'clientId': clientId, 'date': date.toIso8601String(), 'eventType': eventType, 'address': address, 'notes': notes, 'status': status};
  }
}

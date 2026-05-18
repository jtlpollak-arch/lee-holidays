import 'package:meta/meta.dart';

@immutable
class ClientModel {
  final int id;
  final String fullName;
  final String firstName;
  final String phone;

  const ClientModel({required this.id, required this.fullName, required this.firstName, required this.phone});

  /// קונסטרקטור חכם המקבל שורה גולמית מ-Google Sheets (רשימה של ערכים)
  /// וממיר אותה לאובייקט לקוח באפליקציה.
  factory ClientModel.fromSheetsRow(List<dynamic> row) {
    // הגנה מפני שורות חלקיות או חסרות בגיליון
    final int parsedId = row.isNotEmpty ? int.tryParse(row[0].toString()) ?? 0 : 0;
    final String parsedFullName = row.length > 1 ? row[1].toString().trim() : '';
    final String parsedFirstName = row.length > 2 ? row[2].toString().trim() : '';
    final String rawPhone = row.length > 3 ? row[3].toString().trim() : '';

    return ClientModel(id: parsedId, fullName: parsedFullName, firstName: parsedFirstName, phone: rawPhone);
  }

  /// מתודה הממירה את אובייקט הלקוח חזרה למבנה של שורה (רשימה)
  /// לצורך כתיבה או עדכון ב-Google Sheets.
  List<dynamic> toSheetsRow() {
    return [id, fullName, firstName, phone];
  }

  /// מתודת עזר שמנקה את מספר הטלפון ומחזירה אותו בפורמט בינלאומי מושלם לוואטסאפ.
  /// לדוגמה: "050-123-4567" יהפוך ל-"972501234567"
  String get cleanWhatsAppPhone {
    // הסרת כל התווים שאינם ספרות (מקפים, רווחים וכו')
    final String digitsOnly = phone.replaceAll(RegExp(r'\D'), '');

    // אם המספר מתחיל ב-0, נוריד אותו ונחליף בקידומת ישראל
    if (digitsOnly.startsWith('0')) {
      return '972${digitsOnly.substring(1)}';
    }

    return digitsOnly;
  }

  /// יצירת עותק חדש עם שינויים במידת הצורך (נחוץ לניהול מצב באפליקציה)
  ClientModel copyWith({int? id, String? fullName, String? firstName, String? phone}) {
    return ClientModel(id: id ?? this.id, fullName: fullName ?? this.fullName, firstName: firstName ?? this.firstName, phone: phone ?? this.phone);
  }
}

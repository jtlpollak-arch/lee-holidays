import 'package:flutter/services.dart';

class EmojiSpaceFixFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // זיהוי הבעיה: הוספת סימני השאלה
    if (newValue.text.contains('??') || newValue.text.contains('? ?')) {
      // 1. שמירת המיקום הנוכחי של הסמן (כדי שלא יקפוץ)
      final int cursorPosition = oldValue.selection.baseOffset;

      // 2. ניקוי השיבוש (החזרת הטקסט היציב האחרון)
      final updatedText = oldValue.text;

      // 3. החזרת הערך עם מיקום הסמן המקורי
      return TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: cursorPosition),
      );
    }

    // אם אין בעיה, מחזירים את הערך החדש כרגיל
    return newValue;
  }
}

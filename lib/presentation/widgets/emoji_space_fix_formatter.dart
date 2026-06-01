import 'package:flutter/services.dart';

class EmojiSpaceFixFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text;
    String oldText = oldValue.text;

    // בודקים אם השינוי הוא הוספת תווים (ולא מחיקה)
    if (newText.length > oldText.length) {
      // מחפשים דפוס שבו סימן שאלה מופיע לפני או אחרי תו חדש
      // (למשל: ?A? או ?🍎?)
      // אם נמצא שיבוש, ננקה אותו
      if (newText.contains('?') && newText.length > oldText.length) {
        // אנחנו מבצעים ניקוי של סימני שאלה רק אם הם מופיעים
        // צמוד לתווים חדשים או אחרי אימוג'י בצורה חשודה
        String cleanedText = newText.replaceAllMapped(RegExp(r'\?+([^\?]+)\?+'), (match) {
          return match.group(1)!; // מחזירים רק את התו התקין בלי ה-? מסביב
        });

        // אם בוצע ניקוי, נעדכן את הטקסט ונשמור על מיקום הסמן
        if (cleanedText != newText) {
          final int diff = newText.length - cleanedText.length;
          final int newCursorPosition = newValue.selection.baseOffset - diff;

          return TextEditingValue(
            text: cleanedText,
            selection: TextSelection.collapsed(offset: newCursorPosition.clamp(0, cleanedText.length)),
          );
        }
      }
    }

    return newValue;
  }
}

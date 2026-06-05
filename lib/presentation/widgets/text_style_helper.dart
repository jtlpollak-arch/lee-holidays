import 'package:flutter/material.dart';

class TextStyleHelper {
  // המבנה החדש: #אות...אות#
  static const Map<String, Map<String, dynamic>> styleMap = {
    'הטיה': {'tag': 'i', 'icon': Icons.format_italic},
    'זהב': {'tag': 'g', 'icon': Icons.star_border},
    'הדגשה': {'tag': 'b', 'icon': Icons.format_bold},
    'קו': {'tag': 'u', 'icon': Icons.format_underline},
    'רווח': {'tag': 's', 'icon': Icons.space_bar},
    'רטט': {'tag': 'v', 'icon': Icons.vibration},
    'הילה': {'tag': 'f', 'icon': Icons.flare},
    'לחש': {'tag': 'w', 'icon': Icons.keyboard_voice_outlined},
    'מרקר': {'tag': 'h', 'icon': Icons.highlight},
    'קפיצה': {'tag': 'r', 'icon': Icons.rocket_launch},
  };

  static void applyStyle(TextEditingController controller, String tag) {
    final selection = controller.selection;
    if (!selection.isValid) return;

    // לוגיקת בחירת מילה בודדת אם לא סומן כלום
    TextSelection targetSelection = selection;
    if (selection.isCollapsed) {
      int cursorIndex = selection.baseOffset;
      String text = controller.text;

      int start = cursorIndex;
      while (start > 0 && text[start - 1] != ' ' && text[start - 1] != '\n') start--;
      int end = cursorIndex;
      while (end < text.length && text[end] != ' ' && text[end] != '\n') end++;

      targetSelection = TextSelection(baseOffset: start, extentOffset: end);
    }

    String selectedText = targetSelection.textInside(controller.text);
    if (selectedText.isEmpty) return;

    // --- התיקון כאן ---
    // הפורמט החדש: #tag + טקסט + tag + #
    // אנחנו חייבים להוסיף את ה-tag גם בסוף לפני ה-#
    String newText = '#$tag$selectedText$tag#';
    // ------------------

    controller.value = controller.value.replaced(targetSelection, newText);

    // עדכון מיקום הסמן לאחר ההזרקה
    controller.selection = TextSelection.collapsed(offset: targetSelection.baseOffset + newText.length);
  }
}

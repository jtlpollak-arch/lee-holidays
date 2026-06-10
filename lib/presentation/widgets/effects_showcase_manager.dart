import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:holidays/presentation/widgets/greeting_preview_page.dart';
import 'package:holidays/presentation/widgets/text_style_helper.dart';
// וודא שאתה מייבא את הדפים והעזרים הרלוונטיים שלך
// import 'your_text_style_helper.dart';
// import 'greeting_preview_page.dart';

class EffectsShowcaseManager {
  // 1. מיפוי אימוג'ים לכל אפקט (כדי שה-Showcase ייראה חי)
  static final Map<String, String> _emojiMap = {'i': '✨', 'g': '👑', 'b': '💫', 'u': '🌊', 's': '↔️', 'v': '🫨', 'f': '🔥', 'w': '🤫', 'h': '🏷️', 'r': '🚀', 'd': '👯', 'o': '🟦', 't': '❌', 'y': '🎈', 'p': '💓', 'm': '⚡', 'n': '💡', 'z': '🌅', 'c': '🪙', 'k': '🕵️'};

  // 2. הגדרת קומבינציות מנצחות (שילובים שעובדים היטב יחד)
  static final List<Map<String, dynamic>> _combinations = [
    {'text': 'גל + דופק', 'tags': 'i,p', 'emoji': '✨💓'},
    {'text': 'ניאון + חלול', 'tags': 'n,o', 'emoji': '💡🟦'},
    {'text': 'מרקר + זהב', 'tags': 'h,g', 'emoji': '🏷️👑'},
    {'text': 'הילה + זינוק', 'tags': 'f,m', 'emoji': '🔥⚡'},
  ];

  static void openShowcase(BuildContext context) {
    final List<Map<String, dynamic>> deltaOperations = [];
    final allEntries = TextStyleHelper.styleMap.entries.toList();

    // --- שלב א': רינדור אפקטים בודדים עם אימוג'י ---
    deltaOperations.add({'insert': 'אפקטים בודדים:\n'});
    for (int i = 0; i < allEntries.length; i++) {
      final String name = allEntries[i].key;
      final String tag = allEntries[i].value['tag'] as String;
      final String emoji = _emojiMap[tag] ?? '⭐';

      deltaOperations.add({
        'insert': '$name$emoji ',
        'attributes': {'effect': tag},
      });

      // שבירת שורות כל 5 אפקטים למראה מסודר
      if ((i + 1) % 5 == 0) deltaOperations.add({'insert': '\n'});
    }

    // --- שלב ב': רינדור קומבינציות ---
    deltaOperations.add({'insert': '\n\nקומבינציות משולבות:\n'});
    for (var combo in _combinations) {
      deltaOperations.add({
        'insert': '${combo['text']} ${combo['emoji']}\n',
        'attributes': {'effect': combo['tags']},
      });
    }

    // --- שלב ג': שליחה ל-Preview (לוגיקה מוכרת) ---
    final previewMap = {'clientName': 'דוגמאות', 'text': jsonEncode(deltaOperations)};
    final base64String = base64UrlEncode(utf8.encode(jsonEncode(previewMap)));
    final url = 'https://lee-greetings.web.app/?preview=$base64String';

    Navigator.push(context, MaterialPageRoute(builder: (context) => GreetingPreviewPage(url: url)));
  }
}

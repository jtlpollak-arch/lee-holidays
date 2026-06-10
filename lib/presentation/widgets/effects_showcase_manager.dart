import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:holidays/presentation/widgets/text_style_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class EffectsShowcaseManager {
  // מיפוי אימוג'ים ייחודיים לכל אפקט (כדי שה-Showcase ייראה עשיר וחי)
  static final Map<String, String> _emojiMap = {'i': '✨', 'g': '👑', 'b': '💫', 'u': '🌊', 's': '👀', 'v': '🫨', 'f': '🔥', 'w': '🤫', 'h': '🏷️', 'r': '🚀', 'd': '👯', 'o': '💥', 't': '❌', 'y': '🎈', 'p': '💓', 'm': '⚡', 'n': '💡', 'z': '🌅', 'c': '🪙', 'k': '🕵️'};

  /// מתודת עזר שמקבלת מחרוזת תגיות גולמית (למשל "n,o,i"), וממיינת אותן לפי ה-priority ב-styleMap
  static String _sortTagsByPriority(String tagsString) {
    List<String> tags = tagsString.split(',');

    tags.sort((a, b) {
      // שליפת ה-priority מתוך ה-styleMap לפי ה-tag
      int priorityA = 2; // ברירת מחדל אם לא נמצא
      int priorityB = 2;

      for (var entry in TextStyleHelper.styleMap.values) {
        if (entry['tag'] == a) priorityA = entry['priority'] as int;
        if (entry['tag'] == b) priorityB = entry['priority'] as int;
      }

      return priorityA.compareTo(priorityB);
    });

    return tags.join(',');
  }

  static void openShowcase(BuildContext context) {
    final List<Map<String, dynamic>> deltaOperations = [];
    final allEntries = TextStyleHelper.styleMap.entries.toList();

    // =================================================================
    // חלק 1: אפקטים בודדים (כל אפקט מקבל את האימוג'י הצמוד שלו)
    // =================================================================
    deltaOperations.add({
      'insert': 'אפקטים בודדים:\n',
      'attributes': {'b': true},
    });

    for (int i = 0; i < allEntries.length; i++) {
      final String name = allEntries[i].key;
      final String tag = allEntries[i].value['tag'] as String;
      final String emoji = _emojiMap[tag] ?? '⭐';

      deltaOperations.add({
        'insert': '$name$emoji ',
        'attributes': {'effect': tag},
      });

      // ירידת שורה בכל 5 אפקטים לשמירה על מבנה מטריצה נקי
      if ((i + 1) % 10 == 0) {
        deltaOperations.add({'insert': '\n'});
      }
    }

    // =================================================================
    // חלק 2: מנוע קומבינציות משולשות ומרובעות (חופש מלא, ללא מגבלות)
    // =================================================================
    deltaOperations.add({
      'insert': '\n קומבינציות:\n',
      'attributes': {'b': true},
    });

    // הגדרת קומבינציות מורכבות המשלבות תנועה, סטייל ומבנה
    final List<Map<String, String>> rawCombinations = [
      // קומבינציות כפולות משופרות
      {'text': 'מרקר + זהב', 'tags': 'h,g', 'emojis': '🏷️👑'},
      {'text': 'ניאון + חלול', 'tags': 'n,o', 'emojis': '💡👀'},

      // קומבינציות משולשות (Triple Threat)
      {'text': 'גל + הילה + רווח', 'tags': 'i,f,s', 'emojis': '✨🔥↔️'},
      {'text': 'דופק + ניאון + חלול', 'tags': 'p,n,o', 'emojis': '💓💡🥸'},
      {'text': 'שקיעה + כסף + מרקר', 'tags': 'z,c,h', 'emojis': '🌅🪙🏷️'},

      // קומבינציות מרובעות (Quad Overkill - השתוללות מלאה)
      {'text': 'קפיצה + רטט + זהב + חלול', 'tags': 'r,v,g,o', 'emojis': '🚀🫨👑🐮'},
      {'text': 'זינוק + נדנדה + הילה + קו', 'tags': 'm,y,f,u', 'emojis': '⚡🎈🔥🌊'},
    ];

    for (var combo in rawCombinations) {
      final String rawTags = combo['tags']!;
      // הרצת מנוע המיון האוטומטי לפני יצירת ה-attribute
      final String sortedTags = _sortTagsByPriority(rawTags);
      final String displayName = combo['text']!;
      final String emojis = combo['emojis']!;

      deltaOperations.add({
        'insert': '$displayName $emojis\n',
        'attributes': {'effect': sortedTags},
      });
    }

    // הוספת ירידת שורה סופית כמקובל ב-Quill
    deltaOperations.add({'insert': '\n'});

    // =================================================================
    // חלק 3: קידוד ושילוח ל-Base64 וטעינת ה-Preview
    // =================================================================
    final previewMap = {'clientName': 'דוגמה', 'text': jsonEncode(deltaOperations)};
    final jsonString = jsonEncode(previewMap);
    final bytes = utf8.encode(jsonString);
    final base64String = base64UrlEncode(bytes);

    final url = 'https://lee-greetings.web.app/?preview=$base64String';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    //    Navigator.push(context, MaterialPageRoute(builder: (context) => GreetingPreviewPage(url: url)));
  }
}

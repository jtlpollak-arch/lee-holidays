import 'package:flutter/material.dart';

class TextStyleHelper {
  static const Map<String, Map<String, dynamic>> styleMap = {
    // === 10 האפקטים הקיימים ===
    'גל': {'tag': 'i', 'color': Color.fromARGB(255, 16, 146, 211), 'icon': Icons.waves, 'priority': 2, 'behavior': 'motion'},
    'זהב': {'tag': 'g', 'color': Colors.amber, 'icon': Icons.star_border, 'priority': 1, 'behavior': 'style'},
    'הדגשה': {'tag': 'b', 'color': Colors.black87, 'icon': Icons.format_bold, 'priority': 1, 'behavior': 'style'},
    'קו': {'tag': 'u', 'color': Colors.teal, 'icon': Icons.format_underline, 'priority': 1, 'behavior': 'style'},
    'רווח': {'tag': 's', 'color': Colors.brown, 'icon': Icons.space_bar, 'priority': 0, 'behavior': 'layout'},
    'רטט': {'tag': 'v', 'color': Colors.redAccent, 'icon': Icons.vibration, 'priority': 2, 'behavior': 'motion'},
    'הילה': {'tag': 'f', 'color': Colors.orangeAccent, 'icon': Icons.flare, 'priority': 1, 'behavior': 'style'},
    'לחש': {'tag': 'w', 'color': Colors.purple, 'icon': Icons.keyboard_voice_outlined, 'priority': 2, 'behavior': 'motion'},
    'מרקר': {'tag': 'h', 'color': Colors.yellow, 'icon': Icons.highlight, 'priority': 0, 'behavior': 'layout'},
    'קפיצה': {'tag': 'r', 'color': Colors.deepPurple, 'icon': Icons.rocket_launch, 'priority': 2, 'behavior': 'motion'},

    // === 10 האפקטים החדשים (11-20) ===
    'כפול': {'tag': 'd', 'color': Colors.blueGrey, 'icon': Icons.density_small, 'priority': 2, 'behavior': 'motion'},
    'חלול': {'tag': 'o', 'color': Colors.grey, 'icon': Icons.text_fields_outlined, 'priority': 0, 'behavior': 'layout'},
    'ריצוד': {'tag': 't', 'color': Colors.red, 'icon': Icons.looks, 'priority': 2, 'behavior': 'motion'},
    'נדנדה': {'tag': 'y', 'color': Colors.lightGreen, 'icon': Icons.swap_horizontal_circle_outlined, 'priority': 2, 'behavior': 'motion'},
    'דופק': {'tag': 'p', 'color': Colors.pinkAccent, 'icon': Icons.favorite_border, 'priority': 2, 'behavior': 'motion'},
    'זינוק': {'tag': 'm', 'color': Colors.green, 'icon': Icons.unfold_more_double, 'priority': 2, 'behavior': 'motion'},
    'ניאון': {'tag': 'n', 'color': Colors.cyan, 'icon': Icons.wb_incandescent_outlined, 'priority': 1, 'behavior': 'style'},
    'שקיעה': {'tag': 'z', 'color': Colors.deepOrangeAccent, 'icon': Icons.brightness_low, 'priority': 2, 'behavior': 'motion'},
    'כסף': {'tag': 'c', 'color': Colors.blueAccent, 'icon': Icons.blur_linear_outlined, 'priority': 1, 'behavior': 'style'},
    'הבלש': {'tag': 'k', 'color': Colors.indigo, 'icon': Icons.visibility_off_outlined, 'priority': 2, 'behavior': 'motion'},
  };
}

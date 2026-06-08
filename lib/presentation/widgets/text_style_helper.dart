import 'package:flutter/material.dart';

class TextStyleHelper {
  static const Map<String, Map<String, dynamic>> styleMap = {
    // 10 האפקטים הקיימים
    'גל': {'tag': 'i', 'color': Color.fromARGB(255, 16, 146, 211), 'icon': Icons.waves},
    'זהב': {'tag': 'g', 'color': Colors.amber, 'icon': Icons.star_border},
    'הדגשה': {'tag': 'b', 'color': Colors.black87, 'icon': Icons.format_bold},
    'קו': {'tag': 'u', 'color': Colors.teal, 'icon': Icons.format_underline},
    'רווח': {'tag': 's', 'color': Colors.brown, 'icon': Icons.space_bar},
    'רטט': {'tag': 'v', 'color': Colors.redAccent, 'icon': Icons.vibration},
    'הילה': {'tag': 'f', 'color': Colors.orangeAccent, 'icon': Icons.flare},
    'לחש': {'tag': 'w', 'color': Colors.purple, 'icon': Icons.keyboard_voice_outlined},
    'מרקר': {'tag': 'h', 'color': Colors.yellow, 'icon': Icons.highlight},
    'קפיצה': {'tag': 'r', 'color': Colors.deepPurple, 'icon': Icons.rocket_launch},

    // 10 האפקטים החדשים (11-20)
    'כפול': {'tag': 'd', 'color': Colors.blueGrey, 'icon': Icons.density_small},
    'חלול': {'tag': 'o', 'color': Colors.grey, 'icon': Icons.text_fields_outlined},
    'ריצוד': {'tag': 't', 'color': Colors.red, 'icon': Icons.looks},
    'נדנדה': {'tag': 'y', 'color': Colors.lightGreen, 'icon': Icons.swap_horizontal_circle_outlined},
    'דופק': {'tag': 'p', 'color': Colors.pinkAccent, 'icon': Icons.favorite_border},
    'זינוק': {'tag': 'm', 'color': Colors.green, 'icon': Icons.unfold_more_double},
    'ניאון': {'tag': 'n', 'color': Colors.cyan, 'icon': Icons.wb_incandescent_outlined},
    'שקיעה': {'tag': 'z', 'color': Colors.deepOrangeAccent, 'icon': Icons.brightness_low},
    'כסף': {'tag': 'c', 'color': Colors.blueAccent, 'icon': Icons.blur_linear_outlined},
    'הבלש': {'tag': 'k', 'color': Colors.indigo, 'icon': Icons.visibility_off_outlined},
  };
}

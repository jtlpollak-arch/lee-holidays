import 'package:flutter/material.dart';

class TextStyleHelper {
  static const Map<String, Map<String, dynamic>> styleMap = {
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
  };
}

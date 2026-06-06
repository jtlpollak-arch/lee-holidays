import 'package:flutter/material.dart';

class TextStyleOption {
  final String label;
  final String effect;
  final IconData icon;

  TextStyleOption(this.label, this.effect, this.icon);
}

final List<TextStyleOption> effects = [
  TextStyleOption('סיבוב', 'emphasized-rotate', Icons.rotate_right),
  TextStyleOption('זהב', 'gold-text', Icons.star),
  TextStyleOption('בולד גדול', 'bold-large', Icons.format_bold),
  TextStyleOption('קו תחתי', 'underline-handwritten', Icons.format_underline),
  TextStyleOption('ריווח', 'wide-spacing', Icons.space_bar),
  TextStyleOption('ריטוט', 'jitter-effect', Icons.graphic_eq),
  TextStyleOption('זוהר', 'glow-effect', Icons.lightbulb),
  TextStyleOption('לחישה', 'whisper-text', Icons.text_format),
  TextStyleOption('מרקר', 'marker-highlight', Icons.highlight),
  TextStyleOption('פופ-אפ', 'pop-up', Icons.open_in_new),
];

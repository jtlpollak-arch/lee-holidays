// voice_management_dialog.dart
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceManagementDialog extends StatefulWidget {
  final String voiceUrl;
  final VoidCallback onDelete;
  final VoidCallback onReRecord;

  const VoiceManagementDialog({super.key, required this.voiceUrl, required this.onDelete, required this.onReRecord});

  @override
  State<VoiceManagementDialog> createState() => _VoiceManagementDialogState();
}

class _VoiceManagementDialogState extends State<VoiceManagementDialog> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("ניהול ברכה קולית", textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("הברכה הקולית שלך מוכנה"),
          const SizedBox(height: 20),

          // כפתור ניגון/עצירה
          IconButton(
            iconSize: 64,
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
            color: const Color(0xFF1B5565),
            onPressed: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
                setState(() => _isPlaying = false);
              } else {
                await _audioPlayer.play(UrlSource(widget.voiceUrl));
                setState(() => _isPlaying = true);
                _audioPlayer.onPlayerComplete.listen((event) {
                  setState(() => _isPlaying = false);
                });
              }
            },
          ),

          const SizedBox(height: 20),

          // כפתור מחיקה
          TextButton.icon(
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text("מחיקת הברכה", style: TextStyle(color: Colors.red)),
            onPressed: widget.onDelete,
          ),

          const SizedBox(height: 10),

          // כפתור הקלטה מחדש
          OutlinedButton(onPressed: widget.onReRecord, child: const Text("הקלטה מחדש")),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("סגירה"))],
    );
  }
}

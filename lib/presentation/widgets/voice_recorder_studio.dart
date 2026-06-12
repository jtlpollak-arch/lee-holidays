import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecorderStudio extends StatefulWidget {
  final Function(File?) onRecordingSaved;

  const VoiceRecorderStudio({super.key, required this.onRecordingSaved});

  @override
  State<VoiceRecorderStudio> createState() => _VoiceRecorderStudioState();
}

class _VoiceRecorderStudioState extends State<VoiceRecorderStudio> {
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();

  String? _recordingPath;
  bool _isRecording = false;
  bool _hasRecording = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await _audioRecorder.openRecorder();
    await _audioPlayer.openPlayer();
  }

  @override
  void dispose() {
    _audioRecorder.closeRecorder();
    _audioPlayer.closePlayer();
    super.dispose();
  }

  Future<void> _playRecording() async {
    if (_recordingPath != null) {
      await _audioPlayer.startPlayer(
        fromURI: _recordingPath,
        codec: Codec.aacADTS,
        whenFinished: () {
          setState(() {});
        },
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (status == PermissionStatus.granted) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/temp_greeting.aac';

        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }

        await _audioRecorder.startRecorder(
          toFile: path,
          codec: Codec.aacADTS,
          sampleRate: 44100,
          bitRate: 128000, // איכות גבוהה - קרוב לוואטסאפ
          numChannels: 1,
        );

        setState(() {
          _isRecording = true;
          _hasRecording = false;
          _recordingPath = path;
        });
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  Future<void> _stopRecording() async {
    await _audioRecorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _hasRecording = _recordingPath != null;
    });
  }

  void _deleteRecording() {
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (file.existsSync()) file.delete();
      setState(() {
        _recordingPath = null;
        _hasRecording = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("הקלטת ברכה אישית", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: _isRecording ? Colors.red : const Color(0xFF1B5565),
                child: Icon(_isRecording ? Icons.mic : Icons.mic_none, size: 40, color: Colors.white),
              ),
            ),

            const SizedBox(height: 20),

            if (_hasRecording) ...[
              const Text("ההקלטה מוכנה!"),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(_audioPlayer.isPlaying ? Icons.stop : Icons.play_arrow),
                    onPressed: () async {
                      if (_audioPlayer.isPlaying) {
                        await _audioPlayer.stopPlayer();
                      } else {
                        await _playRecording();
                      }
                      setState(() {});
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deleteRecording,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _hasRecording
                  ? () {
                      widget.onRecordingSaved(File(_recordingPath!));
                      Navigator.pop(context);
                    }
                  : null,
              child: const Text("אישור ושמירה"),
            ),
          ],
        ),
      ),
    );
  }
}

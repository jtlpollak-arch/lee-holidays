import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/client_model.dart';

class GreetingCanvas extends StatefulWidget {
  final ClientModel client;
  final String defaultGreetingText;
  final String logoAssetPath;

  const GreetingCanvas({super.key, required this.client, required this.defaultGreetingText, required this.logoAssetPath});

  @override
  State<GreetingCanvas> createState() => _GreetingCanvasState();
}

class _GreetingCanvasState extends State<GreetingCanvas> {
  final GlobalKey _globalKey = GlobalKey();
  late TextEditingController _textController;
  late String _currentGreetingText;

  final Color _tealColor = const Color(0xFF1B5565);
  final Color _goldColor = const Color(0xFF8B7355);

  @override
  void initState() {
    super.initState();
    _currentGreetingText = widget.defaultGreetingText;
    _textController = TextEditingController(text: widget.defaultGreetingText);

    _textController.addListener(() {
      setState(() {
        _currentGreetingText = _textController.text;
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // פונקציית שליחה בוואטסאפ הקיימת
  Future<void> generateAndSendWhatsApp(BuildContext context) async {
    try {
      final RenderRepaintBoundary? boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      await Clipboard.setData(ClipboardData(text: _currentGreetingText));

      final String whatsappNumber = widget.client.phone.replaceAll('-', '').trim();
      final Uri whatsappUri = Uri.parse('https://wa.me/$whatsappNumber');

      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('הברכה הועתקה! כעת עשי "הדבק" בוואטסאפ.'), backgroundColor: Colors.green));
        }
      } else {
        throw 'לא ניתן לפתוח את אפליקציית וואטסאפ';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה בתהליך השליחה: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // פונקציה חדשה: שליחה ישירה במייל
  Future<void> sendEmail(BuildContext context) async {
    try {
      final String subject = Uri.encodeComponent('ברכה חגיגית מלי אטדגי נדל"ן');
      final String body = Uri.encodeComponent('היי ${widget.client.firstName},\n\n$_currentGreetingText\n\nשלך,\nלי אטדגי - נדל"ן בגובה העיניים');

      // יצירת קישור Mailto רשמי
      final Uri emailUri = Uri.parse('mailto:?subject=$subject&body=$body');

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        // גיבוי במידה ואין אפליקציית מייל מוגדרת - העתקה ללוח
        await Clipboard.setData(ClipboardData(text: _currentGreetingText));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('לא נמצאה אפליקציית מייל מוגדרת. תוכן הברכה הועתק ללוח!'), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה בפתיחת המייל: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          key: _globalKey,
          child: Container(
            width: 350,
            height: 350,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFFDF9), Color(0xFFF9F5F0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _goldColor.withOpacity(0.3), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Image.asset(widget.logoAssetPath, height: 70, fit: BoxFit.contain),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'היי ${widget.client.firstName},',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _tealColor, fontFamily: 'Assistant'),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currentGreetingText,
                          style: const TextStyle(fontSize: 16, color: Color(0xFF555555), height: 1.5, fontFamily: 'Assistant'),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      'שלך,',
                      style: TextStyle(fontSize: 12, color: _goldColor, fontFamily: 'Assistant'),
                    ),
                    Text(
                      'לי אטדגי - נדל"ן בגובה העיניים',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _tealColor, fontFamily: 'Assistant'),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _textController,
          maxLines: 4,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: 'כתבי את הברכה האישית שלך כאן...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _tealColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 24),

        // שורת כפתורי הפעולה המשולבת: WhatsApp ומייל
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => generateAndSendWhatsApp(context),
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text('וואטסאפ', style: TextStyle(fontSize: 15, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => sendEmail(context),
                icon: const Icon(Icons.email, color: Colors.white),
                label: const Text('שלחי במייל', style: TextStyle(fontSize: 15, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tealColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

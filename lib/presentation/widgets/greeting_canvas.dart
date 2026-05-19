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
  final Color _lightBgColor = const Color(0xFFF4F7F8);

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

  String get _fullMessage {
    return 'היי ${widget.client.firstName},\n$_currentGreetingText';
  }

  Future<void> generateAndSendWhatsApp(BuildContext context) async {
    final String encodedText = Uri.encodeComponent(_fullMessage);
    final String cleanPhone = widget.client.phone.replaceAll('-', '').trim();

    // התאמת הקידומת הבינלאומית של ישראל
    String internationalPhone = cleanPhone;
    if (cleanPhone.startsWith('0')) {
      internationalPhone = '972${cleanPhone.substring(1)}';
    }

    final url = 'https://wa.me/$internationalPhone?text=$encodedText';
    final uri = Uri.parse(url);

    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      print('וואטסאפ נפתח בהצלחה.');
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('לא ניתן לפתוח את אפליקציית וואטסאפ')));
      }
    }
  }

  Future<void> sendEmail(BuildContext context) async {
    if (widget.client.email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ללקוח זה לא מוגדרת כתובת אימייל במערכת')));
      return;
    }

    final String subject = Uri.encodeComponent('ברכה חמה מלי');
    final String body = Uri.encodeComponent(_fullMessage);
    final url = 'mailto:${widget.client.email}?subject=$subject&body=$body';
    final uri = Uri.parse(url);

    if (await launchUrl(uri)) {
      print('אפליקציית המייל נפתחה בהצלחה.');
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('לא ניתן לפתוח את אפליקציית המייל')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // חלק עליון: לוגו מעוצב ומרווח
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _tealColor.withOpacity(0.05), shape: BoxShape.circle),
              child: Image.asset(widget.logoAssetPath, height: 55, errorBuilder: (context, error, stackTrace) => Icon(Icons.star_purple500_rounded, size: 36, color: _goldColor)),
            ),
            const SizedBox(height: 16),

            // כותרות פנייה
            Text(
              'עריכת ברכה עבור ${widget.client.fullName}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _tealColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'הפתיח "היי ${widget.client.firstName}," יתווסף אוטומטית להודעה',
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),

            // שדה טקסט פרימיום מעוגל ונקי ללא מסגרות שחורות
            TextFormField(
              controller: _textController,
              maxLines: 5,
              style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
              decoration: InputDecoration(
                filled: true,
                fillColor: _lightBgColor,
                hintText: 'הקלידי את גוף הברכה כאן...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.all(18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _tealColor.withOpacity(0.3), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // שורת כפתורי הפעולה המאוזנת והממורכזת
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => generateAndSendWhatsApp(context),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'וואטסאפ',
                      style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 140,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => sendEmail(context),
                    icon: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'שלחי במייל',
                      style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tealColor,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

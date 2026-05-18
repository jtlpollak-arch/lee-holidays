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
  // מפתח ייחודי המאפשר לקוד לגשת לרכיב הגרפי הספציפי ולרנדר אותו לתמונה
  final GlobalKey _globalKey = GlobalKey();

  // קונטרולר לניהול הטקסט בתיבת העריכה
  late TextEditingController _textController;

  // המשתנה שמחזיק את הטקסט העדכני שמוצג על הכרטיס
  late String _currentGreetingText;

  // צבעי המותג של לי
  final Color _tealColor = const Color(0xFF1B5565);
  final Color _goldColor = const Color(0xFF8B7355);

  @override
  void initState() {
    super.initState();
    _currentGreetingText = widget.defaultGreetingText;
    _textController = TextEditingController(text: widget.defaultGreetingText);

    // האזנה לשינויים בתיבת הטקסט ועדכון הכרטיס ב-Live
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

  /// הפונקציה המרכזית שמבצעת את "הקסם": הופכת את הווידג'ט לתמונה,
  /// מעתיקה את הטקסט, ופותחת את הוואטסאפ של הלקוח.
  Future<void> generateAndSendWhatsApp(BuildContext context) async {
    try {
      // 1. מציאת הרכיב הגרפי בזיכרון לפי המפתח שלו
      final RenderRepaintBoundary? boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) return;

      // 2. רנדור הווידג'ט לקובץ תמונה דיגיטלי (Image) ברזולוציה גבוהה
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return;

      // אלו הבייטים הגולמיים של התמונה המעוצבת, מוכנים לשמירה זמנית או שיתוף
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 3. אוטומציה של הטקסט: העתקת הברכה האישית ללוח (Clipboard) של הטלפון
      await Clipboard.setData(ClipboardData(text: _currentGreetingText));

      // 4. פתיחת וואטסאפ: שימוש במספר המנוקה בפורמט הבינלאומי
      final String whatsappNumber = widget.client.cleanWhatsAppPhone;
      final Uri whatsappUri = Uri.parse('https://wa.me/$whatsappNumber');

      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);

        // הצגת הודעה קלה ומעודדת לסוכנת על המסך
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // רכיב ה-RepaintBoundary שעוטף את העיצוב הגרפי של כרטיס הברכה
        RepaintBoundary(
          key: _globalKey,
          child: Container(
            width: 350,
            height: 350,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              // רקע משודרג: מעבר צבעים בין שמנת-זהב עדין לקרם
              gradient: const LinearGradient(colors: [Color(0xFFFFFDF9), Color(0xFFF9F5F0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _goldColor.withOpacity(0.3), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // חלק עליון: הלוגו של לי ממוקם בצד שמאל (נקי ומאוזן מול הטקסט)
                Align(
                  alignment: Alignment.topLeft,
                  child: Image.asset(
                    widget.logoAssetPath,
                    height: 70, // גובה מותאם
                    fit: BoxFit.contain,
                  ),
                ),

                // מרכז הכרטיס: פנייה אישית וטקסט הברכה המשתנה בזמן אמת
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'היי ${widget.client.firstName},',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _tealColor, // צבע טורקיז מהמותג
                            fontFamily: 'Assistant',
                          ),
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

                // חלק תחתון: חתימה מקצועית משודרגת
                Column(
                  children: [
                    Text(
                      'שלך,',
                      style: TextStyle(fontSize: 12, color: _goldColor, fontFamily: 'Assistant'),
                    ),
                    Text(
                      'לי אטדגי - נדל"ן בגובה העיניים',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _tealColor, // צבע טורקיז מהמותג
                        fontFamily: 'Assistant',
                      ),
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

        // מנגנון עריכה Live: תיבת טקסט המאפשרת ללי לשנות את הברכה
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

        // כפתור הפעולה הגדול והברור עבור לי
        ElevatedButton.icon(
          onPressed: () => generateAndSendWhatsApp(context),
          icon: const Icon(Icons.share, color: Colors.white),
          label: const Text(
            'שלחי ברכה בוואטסאפ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366), // צבע וואטסאפ
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ],
    );
  }
}

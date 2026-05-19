import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  bool _isExporting = false;

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

  /// פונקציית הליבה: לכידת הווידג'ט הגרפי, הפיכתו ל-JPG ושמירתו כקובץ זמני
  Future<File?> _captureCanvasToImageFile() async {
    try {
      final RenderRepaintBoundary? boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) return null;

      // הבטחת רזולוציה גבוהה וחדה ללא טשטוש (pixelRatio: 3.0)
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // מציאת נתיב זמני במכשיר וכתיבת הקובץ
      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/greeting_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File file = File(filePath);
      await file.writeAsBytes(pngBytes);

      return file;
    } catch (e) {
      debugPrint('שגיאה בתהליך יצירת קובץ הגלויה: $e');
      return null;
    }
  }

  /// הפקת הגלויה ושליחתה לערוץ המבוקש (וואטסאפ או אימייל) כקובץ תמונה
  Future<void> _handleShareAction({required String channelType}) async {
    setState(() {
      _isExporting = true;
    });

    final File? imageFile = await _captureCanvasToImageFile();

    setState(() {
      _isExporting = false;
    });

    if (imageFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('נכשל תהליך הפקת הגלויה הגרפית'), backgroundColor: Colors.redAccent));
      }
      return;
    }

    // הגדרת כותרת הברכה לפי סוג הערוץ שבו לי בחרה לשלוח
    final String shareSubject = channelType == 'whatsapp' ? 'גלויה מעוצבת מוואטסאפ של לי ✨' : 'ברכה חמה ומעוצבת מלי פתרונות נדל"ן';

    // פתיחת תפריט השיתוף הרשמי של המכשיר עם קובץ התמונה המעוצב
    await Share.shareXFiles([XFile(imageFile.path)], subject: shareSubject, text: 'מצורפת גלויה אישית עבורך! ✨');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'גלויה דיגיטלית ללקוח',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _tealColor),
                  ),
                  if (_isExporting) SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_tealColor))) else IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 14),

              // שדה עריכת הטקסט הרך והמודרני
              TextFormField(
                controller: _textController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _lightBgColor,
                  hintText: 'ערוך את גוף הברכה שיופיע בתוך הגלויה...',
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _tealColor.withOpacity(0.3), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'תצוגה מקדימה של הגלויה שתישלח:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 10),

              // קופסת ה-RepaintBoundary המבודדת: כל מה שבתוכה הופך לתמונה חלקה!
              RepaintBoundary(
                key: _globalKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                    border: Border.all(color: _goldColor.withOpacity(0.2), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // לוגו יוקרתי במרכז הגלויה
                      Image.asset(widget.logoAssetPath, height: 50, errorBuilder: (context, error, stackTrace) => Icon(Icons.star_purple500_rounded, size: 36, color: _goldColor)),
                      const SizedBox(height: 16),

                      // כותרת פנייה מעוצבת
                      Text(
                        'היי ${widget.client.firstName},',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _tealColor, fontFamily: 'Assistant'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),

                      // תוכן הברכה הדינמי והאישי
                      Text(
                        _currentGreetingText,
                        style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // חתימת המותג המהודרת בתחתית הגלויה
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 20, height: 1, color: _goldColor),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'לי - תיווך וייעוץ נדל"ן',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _goldColor, letterSpacing: 0.5),
                            ),
                          ),
                          Container(width: 20, height: 1, color: _goldColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // שורת כפתורי הפעולה המאוזנת והנפרדת
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : () => _handleShareAction(channelType: 'whatsapp'),
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
                      onPressed: _isExporting ? null : () => _handleShareAction(channelType: 'email'),
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
      ),
    );
  }
}

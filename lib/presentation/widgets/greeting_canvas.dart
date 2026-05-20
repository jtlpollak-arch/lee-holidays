import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ייבוא רשמי לעבודה מול בסיס הנתונים בענן
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
  late TextEditingController _textController;
  late String _currentGreetingText;
  bool _isProcessing = false;

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

  /// פונקציית הליבה: שמירת הברכה בבסיס הנתונים בענן ויצירת קישור ישיר ללקוח
  Future<void> _processAndSend({required String channelType}) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. גישה לאוסף הברכות ב-Firestore ויצירת מסמך עם מזהה (ID) ייחודי אוטומטי
      final CollectionReference greetingsRef = FirebaseFirestore.instance.collection('greetings');
      final String greetingId = greetingsRef.doc().id;

      // 2. העלאת נתוני הגלויה לשרת הענן בזמן אמת
      await greetingsRef.doc(greetingId).set({'id': greetingId, 'clientName': widget.client.firstName, 'text': _currentGreetingText.trim(), 'createdAt': FieldValue.serverTimestamp()});

      // 3. בניית כתובת הקישור הרשמית המצביעה ישירות על ה-index.html ב-Hosting
      final String cloudCardUrl = 'https://lee-greetings.web.app/?id=$greetingId';

      // 4. ניסוח הודעת ההזמנה החגיגית שתלווה את הקישור בצ'אט
      final String messageBody =
          'היי ${widget.client.firstName} 👋\n'
          'מצורפת גלויה חגיגית ואישית שנכתבה במיוחד עבורך מלי אטדגי - תיווך וייעוץ נדל"ן! ✨\n\n'
          'לחצי כאן לפתיחת הגלויה המלאה:\n$cloudCardUrl';

      final String encodedMessage = Uri.encodeComponent(messageBody);

      if (channelType == 'whatsapp') {
        // ניקוי מספר הטלפון של הלקוח והתאמת קידומת בינלאומית
        final String cleanPhone = widget.client.phone.replaceAll(RegExp(r'[^0-9]'), '').trim();
        String internationalPhone = cleanPhone;
        if (cleanPhone.startsWith('0')) {
          internationalPhone = '972${cleanPhone.substring(1)}';
        }

        // פתיחה ישירה וממוקדת של הצ'אט מול מספר הטלפון המדויק ללא מסכי ביניים
        final String whatsappUrl = 'https://wa.me/$internationalPhone?text=$encodedMessage';
        final Uri whatsappUri = Uri.parse(whatsappUrl);

        if (await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
          debugPrint('צ\'אט וואטסאפ נפתח ישירות מול הלקוח עם מזהה הגלויה בענן.');
        } else {
          throw Exception('לא ניתן לפתוח את אפליקציית וואטסאפ במכשיר זה');
        }
      } else if (channelType == 'email') {
        if (widget.client.email.isEmpty) {
          throw Exception('לא מוגדרת כתובת אימייל עבור לקוח זה במערכת');
        }

        final String subject = Uri.encodeComponent('ברכה חמה ומעוצבת מלי אטדגי - תיווך וייעוץ נדל"ן');
        final String emailUrl = 'mailto:${widget.client.email}?subject=$subject&body=$encodedMessage';
        final Uri emailUri = Uri.parse(emailUrl);

        if (await launchUrl(emailUri)) {
          debugPrint('אפליקציית הדואר נפתחה ישירות מול נמען המייל.');
        } else {
          throw Exception('לא ניתן לפתוח את אפליקציית המייל במכשיר זה');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה בתהליך השמירה והשליחה: ${e.toString().replaceAll('Exception:', '').trim()}'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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
                    'ניהול ושליחת גלויה דיגיטלית',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _tealColor),
                  ),
                  if (_isProcessing) SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_tealColor))) else IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 14),

              // שדה עריכת תוכן הגלויה
              TextFormField(
                controller: _textController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _lightBgColor,
                  hintText: 'ערוך את גוף הברכה שיופיע בתוך הגלויה בענן...',
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
                'תצוגה מקדימה של הגלויה כפי שתופיע בדפדפן הלקוח:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 10),

              // סימולטור העיצוב היוקראתי של הגלויה
              Container(
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
                    Image.asset(widget.logoAssetPath, height: 50, errorBuilder: (context, error, stackTrace) => Icon(Icons.star_purple500_rounded, size: 36, color: _goldColor)),
                    const SizedBox(height: 16),

                    Text(
                      'היי ${widget.client.firstName},',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _tealColor, fontFamily: 'Assistant'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),

                    Text(
                      _currentGreetingText,
                      style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 20, height: 1, color: _goldColor),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'לי אטדגי - תיווך וייעוץ נדל"ן',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _goldColor, letterSpacing: 0.5),
                          ),
                        ),
                        Container(width: 20, height: 1, color: _goldColor),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // שורת כפתורי ההפעלה הממוקדים
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _processAndSend(channelType: 'whatsapp'),
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
                      onPressed: _isProcessing ? null : () => _processAndSend(channelType: 'email'),
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

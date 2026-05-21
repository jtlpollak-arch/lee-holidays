import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ייבוא רשמי לעבודה מול בסיס הנתונים בענן
import '../../data/models/client_model.dart';
import '../../data/models/event_model.dart'; // ייבוא מודל האירוע עבור טור E

class GreetingCanvas extends StatefulWidget {
  final ClientModel client;
  final EventModel event; // הוספת אובייקט האירוע המלא לגמישות מירבית
  final String defaultGreetingText;
  final String logoAssetPath;

  const GreetingCanvas({super.key, required this.client, required this.event, required this.logoAssetPath, required this.defaultGreetingText});

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
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('עריכת ועיצוב הברכה', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            centerTitle: true,
            automaticallyImplyLeading: false,
            actions: [IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context))],
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    // קנבס ה-Preview החזותי של הברכה
                    Center(
                      child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          color: _lightBgColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(widget.logoAssetPath, height: 65, errorBuilder: (context, error, stackTrace) => Icon(Icons.insert_emoticon_rounded, size: 50, color: _goldColor)),
                                    const SizedBox(height: 20),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Text(
                                          _currentGreetingText,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 16, height: 1.5, color: _tealColor, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'לי - תיווך וייעוץ נדל"ן',
                                      style: TextStyle(fontSize: 14, color: _goldColor, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // הוספת קוביות תצוגת ההערות מטור E מול עיני המשתמש
                    if (widget.event.notes.trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.notes_rounded, size: 16, color: Colors.amber.shade900),
                                const SizedBox(width: 6),
                                Text(
                                  'הערות לאירוע :',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(widget.event.notes, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // כותרת ותיבת עריכת הטקסט
                    const Text(
                      'עריכת תוכן המלל:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _textController,
                      maxLines: 5,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'הקלידו את הברכה שלכם כאן...',
                        fillColor: _lightBgColor,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _tealColor, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // אזור לחצני הפעולה התחתון
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _processAndSend(channelType: 'whatsapp'),
                      icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'שלחי ב-WA',
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

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ייבוא רשמי לעבודה מול בסיס הנתונים בענן
import '../../data/models/client_model.dart';
import '../../data/models/event_model.dart';
import '../bloc_or_provider/home_cubit.dart';
import 'dart:convert';
import 'greeting_templates.dart';
import 'emoji_space_fix_formatter.dart';
import 'text_style_helper.dart';

class GreetingCanvas extends StatefulWidget {
  final ClientModel client;
  final EventModel event; // הוספת אובייקט האירוע המלא לגמישות מירבית
  final String defaultGreetingText;
  final String logoAssetPath;

  final HomeCubit cubit;
  final String spreadsheetId;
  final bool isMock;

  const GreetingCanvas({super.key, required this.client, required this.event, required this.logoAssetPath, required this.defaultGreetingText, required this.cubit, required this.spreadsheetId, this.isMock = false});

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

  void _openPreview() {
    final previewMap = {'clientName': widget.client.firstName, 'text': _textController.text};

    // הופכים את ה-JSON למחרוזת של בתים ומקודדים ל-Base64 בטוח ל-URL
    final jsonString = jsonEncode(previewMap);
    final bytes = utf8.encode(jsonString);
    final base64String = base64UrlEncode(bytes);

    final url = 'https://lee-greetings.web.app/?preview=$base64String';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
          'לחצו כאן לפתיחת הגלויה המלאה:\n$cloudCardUrl';

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

      if (mounted) {
        if (!widget.isMock) {
          widget.cubit.markEventAsSent(spreadsheetId: widget.spreadsheetId, event: widget.event);
        }
        Navigator.of(context).pop();
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

  Widget _buildInfoSection() {
    // בודק אם יש תוכן שמצדיק כפתור "פרטים"
    bool hasExtraDetails = widget.client.notes.trim().isNotEmpty || widget.event.notes.trim().isNotEmpty || widget.event.address.trim().isNotEmpty;

    return Container(
      // ... העיצוב שלך נשאר זהה ...
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: _tealColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'שם: ',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1B5565), fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: widget.client.fullName,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1B5565)),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'שם לברכה: ',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1B5565), fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: widget.client.firstName,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1B5565)),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2), // מרווח קטן בין השורות
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'אירוע: ',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1B5565), fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: widget.event.eventType,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1B5565)),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // כאן מתבצעת הלוגיקה: הצג את הכפתור רק אם יש נתונים
          if (hasExtraDetails)
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => _buildFullDetailsSheet(),
                );
              },
              child: Row(
                // שינינו ל-Row כדי להכניס אייקון וטקסט יחד
                children: [
                  Text(
                    'פרטים',
                    style: TextStyle(
                      fontSize: 12,
                      color: _goldColor,
                      fontWeight: FontWeight.bold, // הוספנו Bold
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 2), // מרווח קטן מאוד בין הטקסט לאייקון
                  Icon(
                    Icons.visibility_outlined, // אייקון של עין או חץ למטה
                    size: 14,
                    color: _goldColor,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullDetailsSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'פרטים',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _tealColor),
          ),
          const Divider(),
          const SizedBox(height: 10),
          if (widget.client.notes.isNotEmpty) _buildInfoRow(Icons.person, Colors.purple, 'הערות לקוח:', widget.client.notes),
          const SizedBox(height: 10),
          if (widget.event.notes.isNotEmpty) _buildInfoRow(Icons.notes, Colors.amber, 'הערות אירוע:', widget.event.notes),
          const SizedBox(height: 10),
          if (widget.event.address.isNotEmpty) _buildInfoRow(Icons.location_on, Colors.red, 'כתובת:', widget.event.address),
        ],
      ),
    );
  }

  // מתודה עזר קטנה כדי לחסוך כפילות קוד ולמנוע שגיאות
  Widget _buildInfoRow(IconData icon, Color color, String title, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, decoration: TextDecoration.underline),
              ),
              const SizedBox(height: 4),
              Text(content, style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  void _showTemplatesDialog(String eventType) {
    final List<Category> categories = eventCategories[widget.event.eventType] ?? eventCategories['אחר'] ?? [];

    if (categories.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: categories.length,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: const Color(0xFF1B5565),
                    indicatorColor: const Color(0xFF1B5565),
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    tabs: categories.map((c) => Tab(text: c.name)).toList(),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: categories.map((category) {
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: category.templates.length,
                          itemBuilder: (context, index) {
                            final template = category.templates[index];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() => _textController.text = template.content);
                                  Navigator.pop(context);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // הכותרת
                                      Text(
                                        template.title,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
                                      ),
                                      const SizedBox(height: 6),
                                      // קו ההדגשה המוזהב
                                      Container(
                                        height: 2,
                                        width: 40,
                                        decoration: BoxDecoration(color: const Color(0xFF8B7355), borderRadius: BorderRadius.circular(2)),
                                      ),
                                      const SizedBox(height: 10),
                                      // התוכן
                                      Text(
                                        template.content,
                                        style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actionButtons = [];
    if (widget.client.phone.isNotEmpty) {
      actionButtons.add(
        SizedBox(
          width: 140,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _processAndSend(channelType: 'whatsapp'),
            icon: const Icon(Icons.message, color: Colors.white, size: 18),
            label: const Text(
              'שלחי ב-WA',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _tealColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      );
    }

    if (widget.client.phone.isNotEmpty && widget.client.email.isNotEmpty) {
      actionButtons.add(const SizedBox(width: 16));
    }

    if (widget.client.email.isNotEmpty) {
      actionButtons.add(
        SizedBox(
          width: 140,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _processAndSend(channelType: 'email'),
            icon: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 18),
            label: const Text(
              'שלחי במייל',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _tealColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        // הוסר ה-height הקשיח של ה-0.85 כדי למנוע מהמסך הלבן להידחף ולבלוע את הדף
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // פינצטה: משנים ל-false כדי למנוע מה-Scaffold להתכווץ, לקטוע את המסך לשניים ולהציג בור לבן בתחתית
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: const Text('עריכת ועיצוב הברכה', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            centerTitle: true,
            automaticallyImplyLeading: false,
            actions: [IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context))],
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: SafeArea(
            top: true, // מגן על החלק העליון של החלונית מפני חיתוך והצמדה לבר המערכת כשהמקלדת עולה
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    // ה-padding התחתון מתרחב דינמית בגובה המקלדת ומייצר את מרחב הגלילה המושלם והטבעי בתוך החלון היציב
                    padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? MediaQuery.of(context).viewInsets.bottom + 20 : 24.0),
                    children: [
                      // 1. הוספת קוביות תצוגת ההערות מטור E ומודל הלקוח מול עיני המשתמש (בראש הרשימה)
                      if (true) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _lightBgColor, // שונה מ-amber.shade50 לרקע הבהיר והנקי של ה-preview
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200, width: 1), // שונה מ-amber.shade200 לגבול אפור עדין ומודרני
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildInfoSection()]),
                        ),
                        const SizedBox(height: 20),
                      ],

                      const Text(
                        'תוכן הברכה:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 8),

                      // הוסף את זה בדיוק לפני ה-Stack של ה-TextFormField
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: // בתוך ה-Column של ה-build:
                        SizedBox(
                          height: 45,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: TextStyleHelper.styleMap.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ActionChip(
                                  avatar: Icon(entry.value['icon'], size: 16),
                                  label: Text(entry.key, style: const TextStyle(fontSize: 12)),
                                  onPressed: () => TextStyleHelper.applyStyle(_textController, entry.value['tag']),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      // בתוך ה-build של GreetingCanvas, לפני ה-Stack של ה-TextField:
                      Stack(
                        children: [
                          // 1. תיבת הטקסט
                          TextFormField(
                            controller: _textController,
                            enableSuggestions: true,
                            autocorrect: false,
                            inputFormatters: [
                              EmojiSpaceFixFormatter(), // הפילטר שיפתור את סימני השאלה
                            ],
                            minLines: 13,
                            maxLines: 13,
                            textDirection: TextDirection.rtl,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: "הקלידי ברכה אישית או בחרי מהמאגר ✨",
                              fillColor: _lightBgColor,
                              filled: true,
                              contentPadding: const EdgeInsets.only(top: 16, bottom: 16, left: 16, right: 48),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: _tealColor, width: 1.5),
                              ),
                            ),
                          ),

                          // 2. הכפתור ממוקם ידנית בפינה
                          Positioned(
                            top: 8,
                            right: 8, // ב-RTL, right הוא הפינה העליונה של ההתחלה
                            child: IconButton(
                              icon: const Icon(Icons.auto_awesome, color: Color(0xFF1B5565)),
                              onPressed: () => _showTemplatesDialog(widget.event.eventType),
                              tooltip: 'מחולל ברכות',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // במקום SizedBox, השתמש ב-Alignment או ב-Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center, // מרכז את הכפתור
                        children: [
                          OutlinedButton.icon(
                            onPressed: _openPreview,
                            icon: const Icon(Icons.visibility_rounded, size: 18),
                            label: const Text('תצוגה מקדימה'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1B5565), // צבע טקסט ואייקון אוטומטי
                              side: const BorderSide(color: Color(0xFF1B5565), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(horizontal: 20), // ריווח נקי
                              minimumSize: const Size(140, 48), // גודל מינימלי נוח ללחיצה
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24), // הוגדל מעט מ-20 לרווח נקי לפני הכפתורים
                      // 4. אזור לחצני הפעולה - ממוקם בתחתית הרשימה
                      // לפני ה-return של ה-build או בתוכו, הגדר את הרשימה:
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: actionButtons, // זה הכל! הוא יציג רק מה שצריך.
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ייבוא רשמי לעבודה מול בסיס הנתונים בענן
import '../../data/models/client_model.dart';
import '../../data/models/event_model.dart';
import '../bloc_or_provider/home_cubit.dart';
import 'dart:convert';
import 'greeting_templates.dart';
import 'text_style_helper.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'greeting_preview_page.dart';

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
  late QuillController _quillController;
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<List<String>> _activeTagsNotifier = ValueNotifier<List<String>>([]);
  bool _isProcessing = false;

  final Color _tealColor = const Color(0xFF1B5565);
  final Color _goldColor = const Color(0xFF8B7355);
  final Color _lightBgColor = const Color(0xFFF4F7F8);

  @override
  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();

    // הוספת האזנה גם לשינויי בחירה וגם לשינויי תוכן
    _quillController.addListener(_updateActiveTags);
  }

  @override
  void dispose() {
    _quillController.removeListener(_updateActiveTags);
    _quillController.dispose();
    super.dispose();
  }

  void _updateActiveTags() {
    if (!mounted) return;

    // 1. נזהה את הטווח של המילה הנוכחית (בדומה למה שעשינו ב-_toggleEffect)
    final selection = _quillController.selection;
    final text = _quillController.document.toPlainText();

    int start = selection.start;
    while (start > 0 && text[start - 1] != ' ' && text[start - 1] != '\n') {
      start--;
    }
    int end = selection.start;
    while (end < text.length && text[end] != ' ' && text[end] != '\n') {
      end++;
    }

    // הגנה למקרה שהטקסט ריק או שהאינדקס מחוץ לטווח
    if (start >= text.length || start == end) {
      _activeTagsNotifier.value = [];
      return;
    }

    // 2. חבל ההצלה: נשלוף את ה-Attributes רק של התו הראשון במילה (באורך 1)
    // זה מונע מסימני פיסוק צמודים בסוף המילה (כמו ! או ?) להכשיל את בדיקת ה-collectStyle
    final attributes = _quillController.document.collectStyle(start, 1).attributes;

    if (attributes.containsKey('effect')) {
      _activeTagsNotifier.value = attributes['effect']!.value.toString().split(',');
    } else {
      _activeTagsNotifier.value = [];
    }
  }

  void _toggleEffect(String tag) {
    _focusNode.requestFocus();

    // 1. זיהוי הטווח (כולל הרחבה למילה אם הסמן רק עומד)
    var selection = _quillController.selection;
    if (selection.isCollapsed) {
      final text = _quillController.document.toPlainText();
      int start = selection.start;
      while (start > 0 && text[start - 1] != ' ' && text[start - 1] != '\n') start--;
      int end = selection.start;
      while (end < text.length && text[end] != ' ' && text[end] != '\n') end++;
      selection = TextSelection(baseOffset: start, extentOffset: end);
      _quillController.updateSelection(selection, ChangeSource.local);
    }

    // 2. עוברים תו-תו בטווח הנבחר ומפעילים לוגיקה עצמאית לכל אחד
    for (int i = selection.start; i < selection.end; i++) {
      // א. קריאת המצב הקיים של התו הספציפי
      final style = _quillController.document.collectStyle(i, 1);
      final String currentEffectStr = style.attributes['effect']?.value?.toString() ?? "";
      List<String> effects = currentEffectStr.isEmpty ? [] : currentEffectStr.split(',');

      // ב. לוגיקה חכמה: אם יש - תוריד, אם אין - תוסיף
      // זה קורה בנפרד עבור כל תו, לכן זה עובד בצורה מושלמת על טווחים מעורבים
      if (effects.contains(tag)) {
        effects.remove(tag);
      } else {
        effects.add(tag);
      }

      // ג. החלת העדכון על התו הספציפי הזה בלבד
      final newEffect = effects.join(',');
      _quillController.formatText(i, 1, newEffect.isEmpty ? Attribute<String>('effect', AttributeScope.inline, "") : Attribute<String>('effect', AttributeScope.inline, newEffect));
    }

    // 3. ריענון ה-UI כדי שהצ'יפים יתעדכנו לפי המצב החדש
    Future.delayed(const Duration(milliseconds: 50), () {
      _updateActiveTags();
    });
  }

  void _openPreview() {
    // 1. שליפת מבנה ה-Delta המלא (כולל העיצובים והתגים) והמרתו ל-Map
    final deltaMap = _quillController.document.toDelta().toJson();

    // 2. בניית ה-Map עבור ה-Preview, כאשר שדה ה-text מכיל את ה-Delta כסטרינג של JSON
    final previewMap = {'clientName': widget.client.firstName, 'text': jsonEncode(deltaMap)};

    // הופכים את ה-JSON למחרוזת של בתים ומקודדים ל-Base64 בטוח ל-URL
    final jsonString = jsonEncode(previewMap);
    final bytes = utf8.encode(jsonString);
    final base64String = base64UrlEncode(bytes);

    final url = 'https://lee-greetings.web.app/?preview=$base64String';
    Navigator.push(context, MaterialPageRoute(builder: (context) => GreetingPreviewPage(url: url)));
  }

  void _openAllEffectsShowcasePreview() {
    final List<Map<String, dynamic>> deltaOperations = [];
    final List<MapEntry<String, Map<String, dynamic>>> allEntries = TextStyleHelper.styleMap.entries.toList();

    for (int i = 0; i < allEntries.length; i++) {
      final String name = allEntries[i].key;
      final String tag = allEntries[i].value['tag'] as String;

      // 1. הזרקת המילה של האפקט עם ה-Attribute של ה-effect
      deltaOperations.add({
        'insert': name,
        'attributes': {'effect': tag},
      });

      // 2. הזרקת רווח מפריד או ירידת שורה בכל 5 אפקטים (להתאמה למטריצה)
      if (i < allEntries.length - 1) {
        if ((i + 1) % 10 == 0) {
          deltaOperations.add({'insert': '\n'});
        } else {
          deltaOperations.add({'insert': ' '});
        }
      }
    }
    // הוספת ירידת שורה סופית כמקובל במבנה של Quill Document
    deltaOperations.add({'insert': '\n'});

    // בניית ה-Map בדיוק לפי הפורמט של _openPreview ששלחת
    final previewMap = {'clientName': 'דוגמה', 'text': jsonEncode(deltaOperations)};

    // קידוד ל-Base64 בטוח ל-URL
    final jsonString = jsonEncode(previewMap);
    final bytes = utf8.encode(jsonString);
    final base64String = base64UrlEncode(bytes);

    final url = 'https://lee-greetings.web.app/?preview=$base64String';
    Navigator.push(context, MaterialPageRoute(builder: (context) => GreetingPreviewPage(url: url)));
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
      await greetingsRef.doc(greetingId).set({'id': greetingId, 'clientName': widget.client.firstName, 'text': jsonEncode(_quillController.document.toDelta().toJson()), 'createdAt': FieldValue.serverTimestamp()});

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
                                  setState(() {
                                    _quillController.document = Document()..insert(0, template.content);
                                  });
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

  void _showEffectsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // כותרת הדיאלוג
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 18, color: Color(0xFF1B5565)),
                        SizedBox(width: 8),
                        Text(
                          'סגנונות ואפקטים לטקסט',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Text('סמני מילים בברכה ובחרי אפקט להחלה או להסרה:', style: TextStyle(fontSize: 11, color: Colors.black54)),
                const SizedBox(height: 16),

                // בניית 10 הכפתורים במבנה דו-שורתי של 5 כפול 2 בתוך ה-Dialog
                ValueListenableBuilder<List<String>>(
                  valueListenable: _activeTagsNotifier,
                  builder: (context, activeTags, child) {
                    final List<MapEntry<String, Map<String, dynamic>>> allEntries = TextStyleHelper.styleMap.entries.toList();

                    // חלוקת כל 20 האפקטים ל-4 שורות סימטריות של 5 כפתורים בשורה למניעת חריגת רוחב במובייל
                    final List<MapEntry<String, Map<String, dynamic>>> firstRow = allEntries.sublist(0, 5);
                    final List<MapEntry<String, Map<String, dynamic>>> secondRow = allEntries.sublist(5, 10);
                    final List<MapEntry<String, Map<String, dynamic>>> thirdRow = allEntries.sublist(10, 15);
                    final List<MapEntry<String, Map<String, dynamic>>> fourthRow = allEntries.sublist(15, 20);

                    Widget buildDialogKey(MapEntry<String, Map<String, dynamic>> entry) {
                      final String name = entry.key;
                      final String tag = entry.value['tag'];
                      final Color color = entry.value['color'] as Color;
                      final IconData icon = entry.value['icon'] as IconData;
                      final bool isActive = activeTags.contains(tag);

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: GestureDetector(
                            onTap: () {
                              // 1. החלת האפקט על ה-Controller בזיכרון
                              _toggleEffect(tag);

                              // 2. חבל ההצלה: מכיוון ש-_toggleEffect מחזיר אוטומטית פוקוס לעורך,
                              // אנחנו מורידים אותו מיד חזרה כדי להעלים את הדמעות הסגולות באותה מאית שנייה!
                              _focusNode.unfocus();
                            },
                            child: Container(
                              height: 52, // גובה מושלם ללחיצה נוחה בדיאלוג
                              decoration: BoxDecoration(
                                color: isActive ? color : Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isActive ? color : Colors.grey[300]!, width: 1),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(icon, size: 18, color: isActive ? Colors.white : Colors.black87),
                                  const SizedBox(height: 4),
                                  Text(
                                    name,
                                    style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: firstRow.map((e) => buildDialogKey(e)).toList()),
                        const SizedBox(height: 4),
                        Row(children: secondRow.map((e) => buildDialogKey(e)).toList()),
                        const SizedBox(height: 4),
                        Row(children: thirdRow.map((e) => buildDialogKey(e)).toList()),
                        const SizedBox(height: 4),
                        Row(children: fourthRow.map((e) => buildDialogKey(e)).toList()),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      // בלוק זה יורץ אוטומטית מיד ברגע שהדיאלוג נסגר מכל סיבה שהיא
      // אנחנו מחזירים את הפוקוס לעורך כדי שהמקלדת והידיות הסגולות יקפצו חזרה למקומן
      if (mounted && _quillController.selection.isValid && !_quillController.selection.isCollapsed) {
        _focusNode.requestFocus();
      }
    });
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

                      SizedBox(
                        height: 300, // הגובה המוקצה לעורך
                        child: _buildQuillEditorComponent(),
                      ),

                      // בתוך ה-build של GreetingCanvas, לפני ה-Stack של ה-TextField:
                      const SizedBox(height: 24),

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

  Widget _buildQuillEditorComponent() {
    return Column(
      children: [
        // שורת כלי עיצוב עליונה מהודקת ואלגנטית במקום ה-ListView הישן
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              // 1. צד ימין: כפתור תצוגה מקדימה הרחב והראשי פותח את השורה מיד בתחילתה
              TextButton.icon(
                onPressed: _openPreview,
                icon: const Icon(Icons.visibility_rounded, size: 16, color: Color(0xFF1B5565)),
                label: const Text(
                  "תצוגה מקדימה",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 40), // מתאים לגובה השורה
                ),
              ),

              // Spacer דוחף את כל שאר הכפתורים (העיצוב והבדיקה) לצד שמאל באופן מוחלט
              const Spacer(),

              // 2. צד שמאל: כפתור הפתיחה של לוח האפקטים המרוכז
              TextButton.icon(
                onPressed: () {
                  // 1. הסרת הפוקוס מהעורך - מעלים מיד את המקלדת ואת ידיות הבחירה (הטיפות) מהמסך
                  _focusNode.unfocus();

                  // 2. פתיחת הדיאלוג המרוכז
                  _showEffectsDialog();
                },
                icon: const Icon(Icons.palette_outlined, size: 16, color: Color(0xFF1B5565)),
                label: const Text(
                  "אפקטים 💥",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 40), // מתאים לגובה השורה
                ),
              ),

              const SizedBox(width: 2),

              // 3. צמוד לשמאל הקיצוני: כפתור המבחנה לבדיקת כל 20 האפקטים יחד
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: const Color(0xFF1B5565).withOpacity(0.08), shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.science_outlined, size: 16, color: Color(0xFF1B5565)),
                  tooltip: "איך זה ייראה (כל האפקטים)",
                  onPressed: _openAllEffectsShowcasePreview,
                  padding: EdgeInsets.zero,
                ),
              ),

              const SizedBox(width: 4), // מרווח קל מסגרת המסך השמאלית
            ],
          ),
        ),

        // 2. ה-Stack שמכיל את העורך ואת כפתור הברכות הצף
        Expanded(
          child: Stack(
            children: [
              // העורך תופס את כל המקום הפנוי שנותר
              Positioned.fill(
                child: QuillEditor.basic(
                  controller: _quillController,
                  focusNode: _focusNode,
                  config: const QuillEditorConfig(placeholder: "הקלידי ברכה אישית או בחרי מהמאגר ✨", padding: EdgeInsets.only(top: 16, left: 16, bottom: 16, right: 60)),
                ),
              ),

              // כפתור הברכות ממוקם בפינה העליונה (RTL)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
                  child: IconButton(
                    icon: const Icon(Icons.auto_awesome, color: Color(0xFF1B5565)),
                    onPressed: () => _showTemplatesDialog(widget.event.eventType),
                    tooltip: 'בחירת ברכה מהמאגר',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

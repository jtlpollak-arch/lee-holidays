import 'package:flutter/material.dart';
import 'package:holidays/data/datasources/google_calendar_api.dart';
import 'package:holidays/data/models/client_model.dart';
import 'package:holidays/data/repositories/client_repository.dart';
import 'package:holidays/data/repositories/event_repository.dart';

/// קומפוננטת לוויין עצמאית לניהול, תצוגה וביצוע של מחיקת לקוח לצמיתות (פיזית וצמצום)
/// מה-Google Sheet, מה-Cache המקומי ומיומן גוגל במקביל.
class CbvDelPermanently {
  final ClientRepository clientRepository;
  final EventRepository eventRepository;
  final GoogleCalendarApi googleCalendarApi;

  CbvDelPermanently({required this.clientRepository, required this.eventRepository, required this.googleCalendarApi});

  /// מציג דיאלוג אזהרה קפדני ומבצע את שרשרת המחיקות האטומית במידה והמשתמשת מאשרת
  void showDeleteConfirmationDialog({required BuildContext context, required String spreadsheetId, required ClientModel client, required VoidCallback onSuccess}) {
    showDialog(
      context: context,
      barrierDismissible: false, // מניעת סגירת הדיאלוג בלחיצה בחוץ בזמן תהליך המחיקה
      builder: (BuildContext dialogContext) {
        bool isDeleting = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: TextDirection.rtl, // עימוד לימין כמבוקש
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                title: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'מחיקת לקוח לצמיתות',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('את עומדת למחוק את הלקוח/ה לצמיתות:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(
                        '${client.fullName} (${client.phone})',
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade800, backgroundColor: Colors.amber.shade50),
                      ),
                      const SizedBox(height: 16),
                      const Text('משמעות פעולה זו היא:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('• שורת הלקוח תימחק פיזית מגיליון ה-Google Sheets והגיליון יצומצם.'), const Text('• כל פגישותיו, אירועיו והיסטוריית הטיפולים שלו יימחקו פיזית מהגיליון.'), const Text('• כל התזכורות והסדרות המשויכות אליו ביומן גוגל (Google Calendar) יוסרו לחלוטין.'), const Text('• המידע יימחק לחלוטין מה-Cache המקומי במכשיר הנייד.')]),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '⚠️ אזהרה: פעולה זו היא סופית לחלוטין ולא ניתן לבטל אותה או לשחזר את הנתונים לאחר מכן!',
                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (isDeleting) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: const [
                            CircularProgressIndicator(strokeWidth: 3),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text('מבצע מחיקה מרוכזת (Batch Update) ומצמצם שורות בענן, נא לא לסגור את האפליקציה...', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                actions: isDeleting
                    ? null // הסרת הכפתורים בזמן ביצוע המחיקה למניעת הפרעות
                    : [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'ביטול',
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                          onPressed: () async {
                            setState(() {
                              isDeleting = true;
                            });

                            try {
                              await _executePermanentDeletionChain(spreadsheetId: spreadsheetId, clientId: client.id);

                              // סגירת הדיאלוג לאחר הצלחה מלאה
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }

                              // הפעלת פונקציית ההצלחה (למשל רענון מסך הבית או מעבר דף)
                              onSuccess();
                            } catch (e) {
                              print('שגיאה קריטית בשרשרת המחיקה: $e');

                              setState(() {
                                isDeleting = false;
                              });

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('נכשלה מחיקת הלקוח: ${e.toString()}'), backgroundColor: Colors.red));
                              }
                            }
                          },
                          child: const Text('כן, מחקי לצמיתות', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
              ),
            );
          },
        );
      },
    );
  }

  /// מנהל את השרשרת האטומית של המחיקות הפיזיות מול ה-Repositories והיומן
  Future<void> _executePermanentDeletionChain({required String spreadsheetId, required String clientId}) async {
    print('CbvDelPermanently: מתחיל שרשרת מחיקה פיזית אטומית עבור לקוח: $clientId');

    // 1. שלב א': מחיקת כל שורות האירועים המשויכים ללקוח ב-Google Sheets בפקודת Batch אחת מרוכזת
    // המתודה מחזירה לנו את כל מזהי יומן גוגל שהיו רשומים על השורות שנמחקו
    final List<String> calendarEventIdsToClean = await eventRepository.deleteEventsPermanentlyByClient(spreadsheetId, clientId);

    // 2. שלב ב': מעבר על מזהי יומן גוגל וניקוי האירועים/סדרות מהיומן הפיזי של המשתמשת
    if (calendarEventIdsToClean.isNotEmpty) {
      print('CbvDelPermanently: נמצאו ${calendarEventIdsToClean.length} אירועי יומן לניקוי מ-Google Calendar.');

      for (final eventId in calendarEventIdsToClean) {
        try {
          print('CbvDelPermanently: מוחק מיומן גוגל אירוע ID: $eventId');
          await googleCalendarApi.deleteEventSeries(eventId);
        } catch (e) {
          // אנחנו עוטפים ב-try-catch פנימי כדי שגם אם אירוע ספציפי נמחק ידנית ביומן בעבר, השרשרת לא תיעצר!
          print('CbvDelPermanently: שגיאה זמנית בניקוי אירוע יומן ספציפי (ייתכן שנמחק כבר): $e');
        }
      }
    }

    // 3. שלב ג': מחיקה פיזית וצמצום של שורת הלקוח עצמו מגיליון הלקוחות בענן ומה-Cache המקומי במכשיר
    await clientRepository.deleteClientPermanently(spreadsheetId, clientId);

    print('CbvDelPermanently: שרשרת המחיקה הפיזית והצמצום הסתיימה בהצלחה מוחלטת!');
  }
}

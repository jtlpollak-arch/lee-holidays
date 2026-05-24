import 'package:flutter/material.dart';
import 'package:holidays/data/models/client_model.dart';
import 'package:holidays/data/repositories/client_repository.dart';
import 'package:holidays/data/repositories/event_repository.dart';

/// קומפוננטת לוויין עצמאית לניהול, תצוגה וביצוע של מחיקת לקוח לצמיתות (פיזית וצמצום)
/// מה-Google Sheet ומה-Cache המקומי במקביל, ללא פנייה לקלנדר (מאחר שהלקוח כבר מוקפא).
class CbvDelPermanently {
  final ClientRepository clientRepository;
  final EventRepository eventRepository;

  CbvDelPermanently({required this.clientRepository, required this.eventRepository});

  /// מציג דיאלוג אזהרה קפדני ומבצע את שרשרת המחיקות האטומית במידה והמשתמשת מאשרת
  void showDeleteConfirmationDialog({required BuildContext context, required String spreadsheetId, required ClientModel client, required VoidCallback onSuccess}) {
    showDialog(
      context: context,
      barrierDismissible: false, // מניעת סגירת הדיאלוג בלחיצה בחוץ בזמן תהליך המחיקה
      builder: (BuildContext dialogContext) {
        bool isDeleting = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 30),
                    const SizedBox(width: 10),
                    const Text(
                      'אזהרת מחיקה סופית',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('את עומדת למחוק לצמיתות את הלקוח: ${client.fullName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      const Text(
                        'פעולה זו בלתי הפיכה! כל שורות האירועים המשויכות אליו יימחקו פיזית מגיליון הנתונים בענן והגיליון יצומצם.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                      if (isDeleting) ...[
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.red)),
                            SizedBox(width: 12),
                            Text(
                              'מבצע מחיקת שורות וכיווץ גיליונות ב-Batch...',
                              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                    child: const Text(
                      'ביטול',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: isDeleting
                        ? null
                        : () async {
                            setDialogState(() {
                              isDeleting = true;
                            });

                            try {
                              // הפעלת שרשרת המחיקה המזוקקת מול Sheets בלבד
                              await _executePermanentDeletionChain(spreadsheetId: spreadsheetId, clientId: client.id);

                              if (context.mounted) {
                                Navigator.pop(dialogContext); // סגירת הדיאלוג
                              }
                              onSuccess(); // הפעלת קולבק הצלחה לרענון התצוגה
                            } catch (e) {
                              print('שגיאה במהלך מחיקה סופית: $e');
                              setDialogState(() {
                                isDeleting = false;
                              });

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('נכשלה המחיקה הסופית: $e'), backgroundColor: Colors.red));
                              }
                            }
                          },
                    child: const Text(
                      'מחקי לצמיתות',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// מנהל את שרשרת הפעולות של מחיקת השורות מול Google Sheets ב-Batch, ללא פניות לקלנדר
  Future<void> _executePermanentDeletionChain({required String spreadsheetId, required String clientId}) async {
    print('CbvDelPermanently: מתחיל שרשרת מחיקה פיזית אטומית עבור לקוח מוקפא: $clientId');

    // 1. שלב א': מחיקת כל שורות האירועים המשויכים ללקוח ב-Google Sheets בפקודת Batch אחת מרוכזת (בסדר יורד)
    await eventRepository.deleteEventsPermanentlyByClient(spreadsheetId, clientId);

    // 2. שלב ב': מחיקת שורת הלקוח עצמו מגיליון הלקוחות וכיווץ הגיליון
    print('CbvDelPermanently: מוחק את שורת הלקוח לצמיתות מגיליון הלקוחות...');
    await clientRepository.deleteClientPermanently(spreadsheetId, clientId);

    print('CbvDelPermanently: שרשרת מחיקת ה-Batch של הלקוח המוקפא הסתיימה בהצלחה מלאה.');
  }
}

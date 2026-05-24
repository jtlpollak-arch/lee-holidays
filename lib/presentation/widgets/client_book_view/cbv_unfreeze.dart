import 'package:flutter/material.dart';
import 'package:holidays/data/models/client_model.dart';
import 'package:holidays/data/repositories/client_repository.dart';
import 'package:holidays/data/repositories/event_repository.dart';

class CbvUnfreeze {
  static void showUnfreezeDialog({required BuildContext context, required String spreadsheetId, required ClientModel client, required ClientRepository clientRepository, required EventRepository eventRepository, required Function(bool) onLoadingStatusChanged, required VoidCallback onSuccess}) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.wb_sunny, color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Text('שחזור לקוח', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text('האם את בטוחה שברצונך לשחזר ולהפשיר את הלקוח ${client.fullName}?\nכל אירועי העבר והעתיד שלו יוקמו מחדש ביומן גוגל והסטטוס שלו יחזור להיות פעיל.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'ביטול',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () async {
                  Navigator.pop(context); // סגירת הדיאלוג
                  onLoadingStatusChanged(true); // הפעלת מצב טעינה במסך האב

                  try {
                    print('CbvUnfreeze: מתחיל תהליך שחזור והפשרה משולב עבור הלקוח ${client.id}');

                    // 1. שלב א': שחזור אקטיבי של כל אירועי הלקוח ביומן ובשיטס ב-Batch אטומי
                    await eventRepository.unfreezeEventsByClient(spreadsheetId, client.id, client.fullName);

                    // 2. שלב ב': יצירת מודל מעודכן עם סטטוס פעיל
                    final updatedClient = client.copyWith(status: 'פעיל');

                    // 3. שלב ג': עדכון סטטוס הלקוח עצמו בענן וב-Cache המקומי
                    await clientRepository.updateClient(spreadsheetId, updatedClient);

                    // 4. קריאה לקולבק הצלחה לצורך רענון התצוגה במסכים
                    onSuccess();
                  } catch (e) {
                    print('שגיאה בתהליך שחזור לקוח: $e');
                    onLoadingStatusChanged(false); // כיבוי טעינה במקרה של כישלון
                  }
                },
                child: const Text(
                  'שחזרי לקוח',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:holidays/data/datasources/google_calendar_api.dart';
import 'package:holidays/data/models/client_model.dart';
import 'package:holidays/data/repositories/client_repository.dart';
import 'package:holidays/data/repositories/event_repository.dart';

class CbvFreeze {
  static void showFreezeDialog({required BuildContext context, required String spreadsheetId, required ClientModel client, required ClientRepository clientRepository, required EventRepository eventRepository, required GoogleCalendarApi googleCalendarApi, required Function(bool) onLoadingStatusChanged, required VoidCallback onSuccess}) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.ac_unit, color: Colors.blue, size: 28),
                SizedBox(width: 8),
                Text('הקפאת לקוח', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text('האם את בטוחה שברצונך להקפיא את הלקוח ${client.fullName}?\nכל האירועים העתידיים שלו ימחקו מיומן גוגל, אך המידע יישמר במערכת.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'ביטול',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () async {
                  Navigator.pop(context); // סגירת הדיאלוג
                  onLoadingStatusChanged(true); // הפעלת מצב טעינה במסך האב

                  try {
                    // 1. יצירת מודל מעודכן עם סטטוס מוקפא
                    final updatedClient = client.copyWith(status: 'מוקפא');

                    // 2. עדכון סטטוס הלקוח בענן וב-Cache המקומי
                    await clientRepository.updateClient(spreadsheetId, updatedClient);

                    // 5. קריאה לקולבק הצלחה לצורך רענון המסכים
                    onSuccess();
                  } catch (e) {
                    print('שגיאה בתהליך הקפאת לקוח: $e');
                    onLoadingStatusChanged(false); // כיבוי טעינה במקרה של כישלון
                  }
                },
                child: const Text(
                  'הקפיאי לקוח',
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

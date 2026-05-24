import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:holidays/data/models/client_model.dart';
import 'package:holidays/data/repositories/client_repository.dart';
import 'package:holidays/presentation/widgets/add_client_sheet.dart';

class CbvModify {
  static void showEditDialog({required BuildContext context, required ClientModel client, required String spreadsheetId, required ClientRepository clientRepository, required Function(bool) onLoadingStatusChanged, required VoidCallback onClientUpdated}) {
    final nameController = TextEditingController(text: client.fullName);
    final firstNameController = TextEditingController(text: client.firstName);
    final phoneController = TextEditingController(text: client.phone);
    final emailController = TextEditingController(text: client.email);
    // פינצטה: הוספת קונטרולר חמישי שמחזיק את ההערה הקיימת של הלקוח מתוך המודל
    final notesController = TextEditingController(text: client.notes);
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text(
              'עריכת פרטי לקוח',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'שם מלא'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'חובה להזין שם מלא' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: firstNameController,
                      decoration: const InputDecoration(labelText: 'שם פרטי (לפנייה בברכה)'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'חובה להזין שם פרטי' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'טלפון'),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, PhoneNumberFormatter()],
                      validator: (value) => value == null || value.trim().isEmpty ? 'חובה להזין מספר טלפון' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'אימייל'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    // פינצטה: תוספת שדה הקלט החזותי החדש בתוך הטופס עבור עריכת ההערות הקבועות ללקוח
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'הערות קבועות ללקוח'),
                      maxLines: 2, // מאפשר שתי שורות קלט לנוחות המשתמשת
                      keyboardType: TextInputType.multiline,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ביטול', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5565)),
                onPressed: () async {
                  if (!dialogFormKey.currentState!.validate()) return;

                  // סגירת הדיאלוג מיד לאחר האישור
                  Navigator.pop(context);

                  // שינוי מצב לטעינה במסך האב (מקביל ל-setState ל-true המקורי שלך)
                  onLoadingStatusChanged(true);

                  try {
                    // פינצטה: הזרקת הנתון המעודכן מתוך ה-notesController אל תוך שדה ה-notes במודל הלקוח החדש
                    final updatedClient = ClientModel(
                      id: client.id,
                      fullName: nameController.text.trim(),
                      firstName: firstNameController.text.trim(),
                      phone: phoneController.text.trim(),
                      email: emailController.text.trim(),
                      status: client.status,
                      notes: notesController.text.trim(), // השדה החדש נשמר כאן
                    );

                    // עדכון ב-Repository מול גוגל שיטס וה-Cache המקומי
                    await clientRepository.updateClient(spreadsheetId, updatedClient);

                    // קריאה לרענון הנתונים והטבלאות במסך האב ובדף הבית
                    onClientUpdated();
                  } catch (e) {
                    print('שגיאה בעדכון לקוח: $e');
                    // במקרה של שגיאה מחזירים את מצב הטעינה למצב רגיל כדי שהמסך לא ייתקע
                    onLoadingStatusChanged(false);
                  }
                },
                child: const Text('שמירה', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }
}

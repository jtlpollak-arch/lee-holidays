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
                      decoration: const InputDecoration(labelText: 'שם מלא *'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'שדה חובה' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: firstNameController,
                      decoration: const InputDecoration(labelText: 'שם פרטי לברכה *'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'שדה חובה' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'טלפון *'),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10), PhoneNumberFormatter()],
                      validator: (v) => v == null || v.trim().isEmpty ? 'שדה חובה' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'אימייל (אופציונלי)'),
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
                    final updatedClient = ClientModel(id: client.id, fullName: nameController.text.trim(), firstName: firstNameController.text.trim(), phone: phoneController.text.trim(), email: emailController.text.trim(), status: client.status);

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

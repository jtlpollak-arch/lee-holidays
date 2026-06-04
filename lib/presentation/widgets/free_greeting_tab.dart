import 'package:flutter/material.dart';
import 'package:holidays/presentation/bloc_or_provider/home_cubit.dart';
import '../../data/models/client_model.dart';
import '../../data/models/event_model.dart';
import '../widgets/greeting_canvas.dart'; // וודא שהנתיב נכון

class FreeGreetingTab extends StatefulWidget {
  final HomeCubit cubit;
  final String spreadsheetId;
  final String logoAssetPath;

  const FreeGreetingTab({super.key, required this.cubit, required this.spreadsheetId, required this.logoAssetPath});

  @override
  State<FreeGreetingTab> createState() => _FreeGreetingTabState();
}

class _FreeGreetingTabState extends State<FreeGreetingTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _eventTypeController = TextEditingController();
  ContactType _contactType = ContactType.phone;

  void _navigateToCanvas() {
    // 1. בדיקה שכל השדות שמסומנים כ-validator תקינים
    if (_formKey.currentState!.validate()) {
      // 2. יצירת האובייקטים הפיקטיביים
      final mockClient = ClientModel.mock(_nameController.text, _contactController.text, _contactType);

      final mockEvent = EventModel.mock(mockClient.id, _eventTypeController.text);

      // 3. ניווט ל-GreetingCanvas עם הפרמטרים הנדרשים
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GreetingCanvas(
            client: mockClient,
            event: mockEvent,
            isMock: true, // מציין שאנחנו במצב יצירה חופשית
            cubit: widget.cubit,
            spreadsheetId: widget.spreadsheetId,
            logoAssetPath: widget.logoAssetPath,
            defaultGreetingText: "שלום רב,",
          ),
        ),
      );
    } else {
      // אופציונלי: כאן אפשר להוסיף הודעה אם יש שדות ריקים
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('נא למלא את כל השדות החובה')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey, // וודא שמוגדר אצלך במחלקה: final _formKey = GlobalKey<FormState>();
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'השם לברכה'),
            validator: (value) => (value == null || value.isEmpty) ? 'שדה חובה' : null,
          ),

          DropdownButtonFormField<ContactType>(
            value: _contactType,
            decoration: const InputDecoration(labelText: 'סוג יצירת קשר'),
            items: const [
              DropdownMenuItem(value: ContactType.phone, child: Text('טלפון')),
              DropdownMenuItem(value: ContactType.email, child: Text('מייל')),
            ],
            onChanged: (ContactType? newValue) {
              setState(() {
                _contactType = newValue!;
              });
            },
          ),

          TextFormField(
            controller: _contactController,
            decoration: InputDecoration(labelText: _contactType == ContactType.phone ? 'מספר טלפון' : 'כתובת מייל'),
            keyboardType: _contactType == ContactType.phone ? TextInputType.phone : TextInputType.emailAddress,
            validator: (value) => (value == null || value.isEmpty) ? 'שדה חובה' : null,
          ),

          TextFormField(
            controller: _eventTypeController,
            decoration: const InputDecoration(labelText: 'סוג אירוע'),
            validator: (value) => (value == null || value.isEmpty) ? 'שדה חובה' : null,
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _navigateToCanvas();
              }
            },
            child: const Text('עיצוב גלויה'),
          ),
        ],
      ),
    );
  }
}

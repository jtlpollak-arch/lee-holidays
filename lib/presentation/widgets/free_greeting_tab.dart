import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // חובה עבור ה-TextInputFormatters
import 'package:holidays/presentation/bloc_or_provider/home_cubit.dart';
import 'package:holidays/presentation/widgets/add_client_sheet.dart';
import '../../data/models/client_model.dart';
import '../../data/models/event_model.dart';
import '../widgets/greeting_canvas.dart';

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

  ContactType _contactType = ContactType.phone;
  String? _selectionType;
  String? _selectedEvent;
  List<String> _eventOptions = [];

  final List<String> _holidayList = ['ראש השנה', 'פסח', 'סוכות', 'חנוכה', 'פורים', 'שבועות'];
  final List<String> _eventList = ['יום הולדת', 'קניית דירה', 'מכירת דירה', 'השכרת נכס', 'אחר'];

  void _updateEventOptions(String type) {
    setState(() {
      _selectionType = type;
      _selectedEvent = null;
      _eventOptions = (type == 'חגים') ? _holidayList : _eventList;
    });
  }

  void _navigateToCanvas() {
    if (_formKey.currentState!.validate()) {
      final mockClient = ClientModel.mock(_nameController.text, _contactController.text, _contactType);
      final mockEvent = EventModel.mock(mockClient.id, _selectedEvent!);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GreetingCanvas(client: mockClient, event: mockEvent, isMock: true, cubit: widget.cubit, spreadsheetId: widget.spreadsheetId, logoAssetPath: widget.logoAssetPath, defaultGreetingText: ""),
        ),
      );
    }
  }

  // בדיקת תקינות מייל בסיסית
  bool _isEmailValid(String email) {
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'השם לברכה'),
            validator: (value) => (value == null || value.isEmpty) ? 'שדה חובה' : null,
          ),

          DropdownButtonFormField<ContactType>(
            initialValue: _contactType,
            decoration: const InputDecoration(labelText: 'סוג יצירת קשר'),
            items: const [
              DropdownMenuItem(value: ContactType.phone, child: Text('טלפון')),
              DropdownMenuItem(value: ContactType.email, child: Text('מייל')),
            ],
            onChanged: (ContactType? newValue) {
              setState(() {
                _contactType = newValue!;
                _contactController.clear(); // ניקוי השדה במעבר סוג
              });
            },
          ),

          TextFormField(
            controller: _contactController,
            decoration: InputDecoration(labelText: _contactType == ContactType.phone ? 'טלפון' : 'מייל'),
            keyboardType: _contactType == ContactType.phone ? TextInputType.phone : TextInputType.emailAddress,
            inputFormatters: _contactType == ContactType.phone ? [FilteringTextInputFormatter.digitsOnly, PhoneNumberFormatter()] : [],
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'נא להזין ערך';
              if (_contactType == ContactType.phone) {
                if (value.length != 12) return 'נא להזין מספר טלפון מלא כולל קידומת';
              } else {
                if (!_isEmailValid(value)) return 'כתובת מייל לא תקינה';
              }
              return null;
            },
          ),

          const Padding(
            padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text('בחרי סוג:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          Row(
            children: [
              Radio<String>(value: 'חגים', groupValue: _selectionType, onChanged: (val) => _updateEventOptions(val!)),
              const Text('חגים'),
              const SizedBox(width: 20),
              Radio<String>(value: 'אירועים', groupValue: _selectionType, onChanged: (val) => _updateEventOptions(val!)),
              const Text('אירועים'),
            ],
          ),

          DropdownButtonFormField<String>(
            initialValue: _selectedEvent,
            hint: const Text('בחרי אירוע מתוך הרשימה'),
            items: _eventOptions.map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (val) => setState(() => _selectedEvent = val),
            validator: (value) => value == null ? 'חובה לבחור אירוע' : null,
          ),

          const SizedBox(height: 20),
          ElevatedButton(onPressed: _navigateToCanvas, child: const Text('עיצוב גלויה')),
        ],
      ),
    );
  }
}

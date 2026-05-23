import 'package:flutter/material.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/event_model.dart';

class CVNewEventForm extends StatefulWidget {
  final ClientModel client;
  final Function(EventModel) onSubmit;

  const CVNewEventForm({super.key, required this.client, required this.onSubmit});

  @override
  State<CVNewEventForm> createState() => _CVNewEventFormState();
}

class _CVNewEventFormState extends State<CVNewEventForm> {
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _otherTypeController = TextEditingController();
  bool _isLoading = false;
  String? _selectedEventType;
  DateTime? _selectedDate;

  final List<String> _eventTypes = ['יום הולדת', 'קניית דירה', 'מכירת דירה', 'השכרת נכס', 'אחר (טקסט חופשי)'];

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _selectedDate ?? now, firstDate: DateTime(now.year), lastDate: DateTime(now.year, 12, 31), locale: const Locale('he', 'IL'));
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _submitForm() async {
    // 1. בדיקת תקינות: האם נבחר סוג אירוע?
    if (_selectedEventType == null || _selectedEventType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('חובה לבחור סוג אירוע!')));
      return;
    }

    // 2. בדיקת תקינות: האם נבחר "אחר" אך לא נכתב טקסט?
    if (_selectedEventType == 'אחר (טקסט חופשי)' && _otherTypeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('נא לפרט את סוג האירוע בתיבת הטקסט')));
      return;
    }

    // 3. בדיקת תקינות: האם נבחר תאריך?
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('חובה לבחור תאריך!')));
      return;
    }

    setState(() => _isLoading = true);

    // המשך הלוגיקה לשמירה...
    final type = (_selectedEventType == 'אחר (טקסט חופשי)') ? _otherTypeController.text : _selectedEventType!;

    final newEvent = EventModel(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      clientId: widget.client.id,
      date: _selectedDate!, // השתמשנו בתאריך שנבחר ב-DatePicker
      eventType: type,
      address: _addressController.text,
      notes: _notesController.text,
      status: 'פעיל',
    );

    await widget.onSubmit(newEvent);
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context); // <-- השורה שסוגרת את המסך/הבטום-שיט באופן אוטומטי
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'סוג אירוע', border: OutlineInputBorder()),
              value: _selectedEventType,
              items: _eventTypes
                  .map(
                    (t) => DropdownMenuItem<String>(
                      value: t,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(t, textAlign: TextAlign.right),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedEventType = val),
            ),
            if (_selectedEventType == 'אחר (טקסט חופשי)')
              TextField(
                controller: _otherTypeController,
                decoration: const InputDecoration(labelText: 'נא לפרט סוג אירוע'),
              ),

            // שדה התאריך המעודכן
            ListTile(contentPadding: EdgeInsets.zero, title: Text(_selectedDate == null ? 'בחרי תאריך' : 'תאריך נבחר: ${_selectedDate!.day}/${_selectedDate!.month}'), trailing: const Icon(Icons.calendar_today), onTap: _pickDate),

            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'כתובת'),
            ),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'הערות'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _isLoading ? null : _submitForm, child: _isLoading ? const CircularProgressIndicator() : const Text('שמרי אירוע')),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

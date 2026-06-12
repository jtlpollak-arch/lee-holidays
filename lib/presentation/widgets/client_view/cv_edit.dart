import 'package:flutter/material.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/event_model.dart';

class CVEditEventForm extends StatefulWidget {
  final ClientModel client;
  final EventModel eventToEdit;
  final Function(EventModel) onSubmit;

  const CVEditEventForm({super.key, required this.client, required this.eventToEdit, required this.onSubmit});

  @override
  State<CVEditEventForm> createState() => _CVEditEventFormState();
}

class _CVEditEventFormState extends State<CVEditEventForm> {
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _otherTypeController = TextEditingController();
  String? _selectedEventType;
  DateTime? _selectedDate;
  bool _isLoading = false;

  final List<String> _eventTypes = ['יום הולדת', 'קניית דירה', 'מכירת דירה', 'השכרת נכס', 'אחר (טקסט חופשי)'];

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.eventToEdit.address;
    _notesController.text = widget.eventToEdit.notes;
    _selectedDate = widget.eventToEdit.date;

    if (_eventTypes.contains(widget.eventToEdit.eventType)) {
      _selectedEventType = widget.eventToEdit.eventType;
    } else {
      _selectedEventType = 'אחר (טקסט חופשי)';
      _otherTypeController.text = widget.eventToEdit.eventType;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _selectedDate ?? now, firstDate: DateTime(now.year), lastDate: DateTime(now.year, 12, 31), locale: const Locale('he', 'IL'));
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _submitForm() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('חובה לבחור תאריך!')));
      return;
    }
    setState(() => _isLoading = true);
    final type = (_selectedEventType == 'אחר (טקסט חופשי)') ? _otherTypeController.text : (_selectedEventType ?? widget.eventToEdit.eventType);

    final updatedEvent = widget.eventToEdit.copyWith(eventType: type, date: _selectedDate, address: _addressController.text, notes: _notesController.text);

    await widget.onSubmit(updatedEvent);
    setState(() => _isLoading = false);
  }

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
              initialValue: _selectedEventType,
              items: _eventTypes
                  .map(
                    (t) => DropdownMenuItem(
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
            ListTile(title: Text(_selectedDate == null ? 'בחרי תאריך' : '${_selectedDate!.day}/${_selectedDate!.month}'), trailing: const Icon(Icons.calendar_today), onTap: _pickDate),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'כתובת'),
            ),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'הערות'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _isLoading ? null : _submitForm, child: const Text('עדכני אירוע')),
          ],
        ),
      ),
    );
  }
}

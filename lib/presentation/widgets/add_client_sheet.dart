import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/client_model.dart';
import '../../data/models/event_model.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../bloc_or_provider/home_cubit.dart';

class AddClientSheet extends StatefulWidget {
  final String spreadsheetId;
  final ClientRepository clientRepository;
  final EventRepository eventRepository;
  final HomeCubit homeCubit;

  const AddClientSheet({super.key, required this.spreadsheetId, required this.clientRepository, required this.eventRepository, required this.homeCubit});

  @override
  State<AddClientSheet> createState() => _AddClientSheetState();
}

class _AddClientSheetState extends State<AddClientSheet> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedEventType = 'יום הולדת';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _firstNameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(1900), lastDate: DateTime(2100));
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final int clientId = DateTime.now().millisecondsSinceEpoch % 100000000;

      final newClient = ClientModel(
        id: clientId,
        fullName: _fullNameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        phone: _phoneController.text.trim(), // נשמר בפורמט האחיד עם המקפים
      );

      final newEvent = EventModel(clientId: clientId, date: _selectedDate, eventType: _selectedEventType, notes: _notesController.text.trim());

      await widget.clientRepository.addNewClient(widget.spreadsheetId, newClient);
      await widget.eventRepository.addNewEvent(widget.spreadsheetId, newEvent, newClient.fullName);

      if (mounted) {
        widget.homeCubit.loadDailyOverview(spreadsheetId: widget.spreadsheetId);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('הלקוח והאירוע נשמרו וסונכרנו בהצלחה!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה במהלך השמירה: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'הוספת לקוח ואירוע חדש',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'שם מלא של הלקוח *', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'נא להזין שם מלא' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'שם פרטי לפנייה בברכה *', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder()),
                validator: (val) => val == null || val.trim().isEmpty ? 'נא להזין שם פרטי לפנייה' : null,
              ),
              const SizedBox(height: 16),

              // שדה טלפון עם מעצב פורמט אוטומטי 000-000-0000
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                  _PhoneNumberFormatter(), // המעצב המותאם שכתבנו למטה
                ],
                decoration: const InputDecoration(labelText: 'מספר טלפון (וואטסאפ) *', hintText: '050-000-0000', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder()),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'נא להזין מספר טלפון';
                  if (val.length < 12) return 'נא להזין מספר טלפון מלא כולל קידומת';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedEventType,
                decoration: const InputDecoration(labelText: 'סוג האירוע *', prefixIcon: Icon(Icons.star_border), border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'יום הולדת', child: Text('יום הולדת')),
                  DropdownMenuItem(value: 'קניית דירה', child: Text('קניית דירה')),
                  DropdownMenuItem(value: 'מכירת דירה', child: Text('מכירת דירה')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedEventType = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month, color: Color(0xFF1B5565)),
                      label: Text('תאריך האירוע: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.black)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'הערות מיוחדות', prefixIcon: Icon(Icons.chat_bubble_outline), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5565),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'שמירה וסנכרון לענן',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// רכיב עזר ייעודי המזריק מקפים למספר הטלפון בזמן ההקלדה
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      final nonDigitsLen = buffer.toString().replaceAll('-', '').length;

      // הוספת מקף לאחר הספרה השלישית ולאחר הספרה השישית
      if ((nonDigitsLen == 3 || nonDigitsLen == 6) && i != text.length - 1) {
        buffer.write('-');
      }
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

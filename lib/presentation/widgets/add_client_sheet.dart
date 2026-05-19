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
  final VoidCallback onClientAdded;

  const AddClientSheet({super.key, required this.spreadsheetId, required this.clientRepository, required this.eventRepository, required this.homeCubit, required this.onClientAdded});

  @override
  State<AddClientSheet> createState() => _AddClientSheetState();
}

class _AddClientSheetState extends State<AddClientSheet> {
  final _formKey = GlobalKey<FormState>();

  // שדות לקוח
  final _fullNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // שדות אירוע
  String _selectedEventType = 'יום הולדת';
  DateTime _selectedDate = DateTime.now();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _firstNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1930),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1B5565), onPrimary: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final String formattedPhone = _phoneController.text.trim();

      // 1. משיכת הלקוחות הקיימים ובדיקת כפילויות לפי מספר הטלפון
      final existingClients = await widget.clientRepository.getClients(widget.spreadsheetId, forceRefresh: true);

      final bool isDuplicate = existingClients.any((c) => c.phone == formattedPhone && c.isActive);

      if (isDuplicate) {
        setState(() {
          _isLoading = false;
        });

        // הצגת הודעת שגיאה חוסמת ללי במידה והלקוח כבר קיים במערכת
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                    SizedBox(width: 8),
                    Text('לקוח כבר קיים', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                content: Text('מספר הטלפון ($formattedPhone) כבר משויך ללקוח פעיל במערכת.\nלא ניתן להכניס לקוח כפול.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'הבנתי',
                      style: TextStyle(color: Color(0xFF1B5565), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return; // עוצרים את תהליך השמירה ולא ממשיכים לענן
      }

      // 2. יצירת מודל לקוח - מספר הטלפון משמש כמפתח הראשי (ה-ID הוסר לחלוטיًן)
      final newClient = ClientModel(phone: formattedPhone, fullName: _fullNameController.text.trim(), firstName: _firstNameController.text.trim(), email: _emailController.text.trim(), status: 'פעיל');

      // 3. יצירת מודל אירוע משויך ללקוח באמצעות מספר הטלפון שלו
      final newEvent = EventModel(clientPhone: formattedPhone, date: _selectedDate, eventType: _selectedEventType, address: _selectedEventType == 'יום הולדת' ? '' : _addressController.text.trim(), notes: _notesController.text.trim(), status: 'פעיל');

      // 4. שמירה כפולה ומסונכרנת בענן גוגל שיטס
      await widget.clientRepository.addClient(widget.spreadsheetId, newClient);
      await widget.eventRepository.addEvent(widget.spreadsheetId, newEvent);

      // 5. משיכה כפויה ומעודכנת של הלקוחות מהענן לתוך ה-Cache מיד לאחר השמירה
      await widget.clientRepository.getClients(widget.spreadsheetId, forceRefresh: true);

      // 6. ריענון ה-Cubit עבור טאב המשימות ברקע
      await widget.homeCubit.loadDailyOverview(spreadsheetId: widget.spreadsheetId);

      // 7. הפעלת הקולבק לרענון המיידי של הטאב הנוכחי (ספר לקוחות)
      widget.onClientAdded();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('הלקוח והאירוע התווספו וסונכרנו בהצלחה!', textDirection: TextDirection.rtl)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה בתהליך השמירה: $e', textDirection: TextDirection.rtl)));
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
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'הוספת לקוח ואירוע חדש',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
                  ),
                  if (_isLoading) const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B5565))),
                ],
              ),
              const SizedBox(height: 20),

              // --- פרטי הלקוח הכלליים ---
              const Text(
                'פרטי הלקוח הכלליים:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'שם מלא *', border: OutlineInputBorder()),
                validator: (value) => value == null || value.trim().isEmpty ? 'נא להזין שם מלא' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'שם פרטי (לפנייה בברכה) *', border: OutlineInputBorder()),
                validator: (value) => value == null || value.trim().isEmpty ? 'נא להזין שם פרטי' : null,
              ),
              const SizedBox(height: 12),

              // שדה טלפון מעודכן עם פורמטר
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10), _PhoneNumberFormatter()],
                decoration: const InputDecoration(labelText: 'מספר טלפון *', border: OutlineInputBorder(), hintText: '050-000-0000', prefixIcon: Icon(Icons.phone_outlined)),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'נא להזין מספר טלפון';
                  if (value.length < 12) return 'נא להזין מספר טלפון מלא כולל קידומת';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'אימייל (אופציונלי)', border: OutlineInputBorder()),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),

              // --- פרטי האירוע / העסקה ---
              const Text(
                'פרטי האירוע / העסקה הנדל"נית:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedEventType,
                decoration: const InputDecoration(labelText: 'סוג האירוע', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'יום הולדת', child: Text('יום הולדת')),
                  DropdownMenuItem(value: 'קניית דירה', child: Text('קניית דירה (יום השנה)')),
                  DropdownMenuItem(value: 'מכירת דירה', child: Text('מכירת דירה (יום השנה)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedEventType = val);
                },
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month, color: Color(0xFF1B5565)),
                label: Text('תאריך האירוע: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}', style: const TextStyle(color: Colors.black87, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 12),

              if (_selectedEventType != 'יום הולדת') ...[
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'כתובת נכס / אזור *', border: OutlineInputBorder(), hintText: 'למשל: רוטשילד 45, פתח תקווה'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'נא להזין את כתובת הנכס' : null,
                ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'הערות נוספות (אופציונלי)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5565),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('שמירה וסנכרון לענן', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('ביטול', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

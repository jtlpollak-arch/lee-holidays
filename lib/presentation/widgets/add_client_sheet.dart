import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/client_model.dart';
import '../../data/repositories/client_repository.dart';
import '../bloc_or_provider/home_cubit.dart';

class AddClientSheet extends StatefulWidget {
  final String spreadsheetId;
  final ClientRepository clientRepository;
  final HomeCubit homeCubit;
  final VoidCallback onClientAdded;

  const AddClientSheet({super.key, required this.spreadsheetId, required this.clientRepository, required this.homeCubit, required this.onClientAdded});

  @override
  State<AddClientSheet> createState() => _AddClientSheetState();
}

class _AddClientSheetState extends State<AddClientSheet> {
  final _formKey = GlobalKey<FormState>();

  // שדות לקוח בלבד
  final _fullNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _firstNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final String formattedPhone = _phoneController.text.trim();

      // 1. משיכת הלקוחות הקיימים מהענן לצורך בדיקת כפילויות הרמטית לפי טלפון
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
        return;
      }

      // 2. יצירת מודל הלקוח החדש
      final newClient = ClientModel(phone: formattedPhone, fullName: _fullNameController.text.trim(), firstName: _firstNameController.text.trim(), email: _emailController.text.trim(), status: 'פעיל');

      // 3. שמירת הלקוח בלבד בענן ובמסד הנתונים המקומי
      await widget.clientRepository.addClient(widget.spreadsheetId, newClient);

      // 4. משיכה כפויה ומעודכנת של הלקוחות מהענן לתוך ה-Cache מיד לאחר השמירה
      await widget.clientRepository.getClients(widget.spreadsheetId, forceRefresh: true);

      // 5. ריענון ה-Cubit עבור טאב המשימות ברקע
      await widget.homeCubit.loadDailyOverview(spreadsheetId: widget.spreadsheetId);

      // 6. הפעלת הקולבק לרענון המיידי של ספר הלקוחות
      widget.onClientAdded();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('הלקוח התווסף וסונכרן בהצלחה!', textDirection: TextDirection.rtl)));
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
                    'הוספת לקוח חדש',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
                  ),
                  if (_isLoading) const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B5565))),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                'פרטי הלקוח הכלליים:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 14),
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
                      child: const Text('שמירת לקוח וסנכרון', style: TextStyle(color: Colors.white, fontSize: 16)),
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

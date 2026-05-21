import 'package:flutter/material.dart';
import '../../data/models/client_model.dart';
import '../../data/models/event_model.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../bloc_or_provider/home_cubit.dart';

class ClientEventsView extends StatefulWidget {
  final String spreadsheetId;
  final ClientRepository clientRepository;
  final EventRepository eventRepository;
  final HomeCubit homeCubit;

  const ClientEventsView({super.key, required this.spreadsheetId, required this.clientRepository, required this.eventRepository, required this.homeCubit});

  @override
  State<ClientEventsView> createState() => _ClientEventsViewState();
}

class _ClientEventsViewState extends State<ClientEventsView> {
  ClientModel? _selectedClient;
  List<ClientModel> _allClients = [];
  List<EventModel> _clientEvents = [];
  bool _isLoadingClients = true;
  bool _isLoadingEvents = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialClients();
  }

  /// טעינת רשימת הלקוחות הפעילים מה-Repository לצורך הצגה ב-Dropdown
  Future<void> _loadInitialClients() async {
    try {
      setState(() {
        _isLoadingClients = true;
        _errorMessage = null;
      });

      // משיכת לקוחות ממאגר המידע (ענן/מקומי)
      final clients = await widget.clientRepository.getClients(widget.spreadsheetId);

      // סינון לקוחות שאינם מחוקים
      final activeClients = clients.where((c) => c.status != 'מחוק').toList();

      setState(() {
        _allClients = activeClients;
        _isLoadingClients = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'נכשלת טעינת רשימת הלקוחות: $e';
        _isLoadingClients = false;
      });
    }
  }

  /// טעינת כל האירועים המשויכים למספר הטלפון של הלקוח שנבחר
  Future<void> _loadEventsForSelectedClient() async {
    if (_selectedClient == null) return;

    try {
      setState(() {
        _isLoadingEvents = true;
      });

      final allEvents = await widget.eventRepository.getAllEvents(widget.spreadsheetId);

      // סינון אירועים השייכים ללקוח לפי טלפון ושאינם במצב 'מחוק'
      final filteredEvents = allEvents.where((e) {
        return e.clientPhone == _selectedClient!.phone && e.status != 'מחוק';
      }).toList();

      // מיון האירועים לפי תאריך (מהקרוב לרחוק)
      filteredEvents.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _clientEvents = filteredEvents;
        _isLoadingEvents = false;
      });
    } catch (e) {
      setState(() {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה בטעינת האירועים: $e'), backgroundColor: Colors.redAccent));
        _isLoadingEvents = false;
      });
    }
  }

  /// ביצוע מחיקה רכה לאירוע ועדכון התצוגה וה-Cubit
  Future<void> _handleDeleteEvent(EventModel event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('מחיקת אירוע'),
          content: Text('האם את בטוחה שברצונך למחוק את האירוע "${event.eventType}" של ${_selectedClient?.fullName}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ביטול')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('מחק'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      // ביצוע מחיקה רכה ב-Repository
      await widget.eventRepository.deleteEventSoft(widget.spreadsheetId, event);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('האירוע נמחק בהצלחה'), backgroundColor: Colors.green));

      // רענון האירועים במסך הנוכחי ועדכון ה-Overview במסך הראשי
      await _loadEventsForSelectedClient();
      await widget.homeCubit.loadDailyOverview(spreadsheetId: widget.spreadsheetId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('נכשלת מחיקת האירוע: $e'), backgroundColor: Colors.redAccent));
    }
  }

  /// פתיחת טופס הוספת אירוע/עסקה חדשה בתפריט תחתון
  void _showAddEventBottomSheet() {
    if (_selectedClient == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _AddEventFormSheet(
            client: _selectedClient!,
            spreadsheetId: widget.spreadsheetId,
            eventRepository: widget.eventRepository,
            onEventSaved: () async {
              await _loadEventsForSelectedClient();
              await widget.homeCubit.loadDailyOverview(spreadsheetId: widget.spreadsheetId);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'בחירת לקוח לצפייה וניהול',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
              ),
              const SizedBox(height: 10),
              _buildClientDropdown(),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              Expanded(child: _buildEventsSection()),
            ],
          ),
        ),
        floatingActionButton: _selectedClient != null
            ? FloatingActionButton.extended(
                onPressed: _showAddEventBottomSheet,
                backgroundColor: const Color(0xFF1B5565),
                icon: const Icon(Icons.add_alert_rounded, color: Colors.white),
                label: const Text(
                  'אירוע חדש',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildClientDropdown() {
    if (_isLoadingClients) {
      return const Center(child: LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B5565))));
    }

    if (_errorMessage != null) {
      return Text(_errorMessage!, style: const TextStyle(color: Colors.red));
    }

    if (_allClients.isEmpty) {
      return const Text('לא נמצאו לקוחות פעילים במערכת. יש להוסיף לקוח תחילה בלשונית ספר לקוחות.', textDirection: TextDirection.rtl);
    }

    // עטיפת ה-Dropdown ב-Directionality מבטיחה שהחץ, הטקסט והרשימה הנפתחת כולם יפעלו מימין לשמאל
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DropdownButtonFormField<ClientModel>(
        value: _selectedClient,
        hint: const Text('בחרי לקוח מהרשימה...'),
        alignment: Alignment.centerRight, // מצמיד את הטקסט הנבחר לצד ימין בקומפוננטה
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1B5565), width: 2),
          ),
        ),
        items: _allClients.map((client) {
          return DropdownMenuItem<ClientModel>(
            value: client,
            // שימוש ב-Alignment ו-TextDirection מונע היפוך של תווים מיוחדים ומספרים בסוגריים
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('${client.fullName} (${client.phone})', textDirection: TextDirection.rtl),
            ),
          );
        }).toList(),
        onChanged: (ClientModel? newValue) {
          setState(() {
            _selectedClient = newValue;
            _clientEvents = [];
          });
          _loadEventsForSelectedClient();
        },
      ),
    );
  }

  Widget _buildEventsSection() {
    if (_selectedClient == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_pin_rounded, size: 60, color: Colors.grey),
            SizedBox(height: 12),
            Text('אנא בחרי לקוח מלמעלה כדי לצפות ולנהל את האירועים שלו.', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    if (_isLoadingEvents) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B5565))));
    }

    if (_clientEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('לא נמצאו אירועים פעילים עבור ${_selectedClient!.fullName}', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'רשימת אירועים ועסקאות עבור ${_selectedClient!.fullName}:',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: _clientEvents.length,
            itemBuilder: (context, index) {
              final event = _clientEvents[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Row(
                    children: [
                      Text(
                        event.eventType,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${event.date.day}/${event.date.month}/${event.date.year}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (event.address.isNotEmpty) Text('כתובת/נכס: ${event.address}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        if (event.notes.isNotEmpty) Text('הערות: ${event.notes}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _handleDeleteEvent(event),
                    tooltip: 'מחיקת אירוע',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// תפריט פנימי להוספת אירוע/עסקה עם תמיכה דינמית בטקסט חופשי
class _AddEventFormSheet extends StatefulWidget {
  final ClientModel client;
  final String spreadsheetId;
  final EventRepository eventRepository;
  final VoidCallback onEventSaved;

  const _AddEventFormSheet({required this.client, required this.spreadsheetId, required this.eventRepository, required this.onEventSaved});

  @override
  State<_AddEventFormSheet> createState() => _AddEventFormSheetState();
}

class _AddEventFormSheetState extends State<_AddEventFormSheet> {
  final _formKey = GlobalKey<FormState>();

  String _selectedTypeDropdown = 'יום הולדת';
  final _customTypeController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isCustomType = false;

  final List<String> _eventTypes = ['יום הולדת', 'קניית דירה', 'מכירת דירה', 'השכרת נכס', 'פגישת היכרות', 'יום שנה לקשר', 'אחר (טקסט חופשי)'];

  @override
  void dispose() {
    _customTypeController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // קביעת סוג האירוע הסופי - אם נבחר "אחר", ניקח מהשדה החופשי
    final finalEventType = _isCustomType ? _customTypeController.text.trim() : _selectedTypeDropdown;

    setState(() {
      _isLoading = true;
    });

    final newEvent = EventModel(clientPhone: widget.client.phone, date: _selectedDate, eventType: finalEventType, address: _addressController.text.trim(), notes: _notesController.text.trim(), status: 'פעיל');

    try {
      // שמירה של האירוע לענן ולמכשיר וסנכרון מול ה-Calendar
      await widget.eventRepository.addNewEvent(widget.spreadsheetId, newEvent, widget.client.fullName);

      widget.onEventSaved();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('האירוע נשמר וסונכרן בהצלחה לענן וליומן!'), backgroundColor: Colors.green));
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה בשמירת האירוע: $e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'הוספת אירוע/עסקה עבור ${widget.client.fullName}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),

              // שדה בחירת סוג אירוע
              DropdownButtonFormField<String>(
                value: _selectedTypeDropdown,
                decoration: const InputDecoration(labelText: 'סוג האירוע / העסקה', border: OutlineInputBorder()),
                items: _eventTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedTypeDropdown = value;
                    _isCustomType = (value == 'אחר (טקסט חופשי)');
                  });
                },
              ),

              // שדה קלט חופשי דינמי במידה ונבחר "אחר"
              if (_isCustomType) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customTypeController,
                  decoration: const InputDecoration(labelText: 'הקלידי סוג אירוע מותאם אישית', hintText: 'למשל: יום נישואין, סיום שיפוץ נכס', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'שדה חובה כאשר בוחרים סוג אירוע אחר' : null,
                ),
              ],

              const SizedBox(height: 12),

              // בחירת תאריך אירוע
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('תאריך האירוע: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}', style: const TextStyle(fontSize: 15)),
                      const Icon(Icons.calendar_today, color: Color(0xFF1B5565)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // כתובת נכס
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'כתובת נכס / אזור רלוונטי (אופציונלי)', border: OutlineInputBorder()),
              ),

              const SizedBox(height: 12),

              // הערות חופשיות
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'הערות מיוחדות לברכה או תזכורת', border: OutlineInputBorder()),
              ),

              const SizedBox(height: 20),

              // כפתורי שמירה וביטול
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5565), minimumSize: const Size(double.infinity, 48)),
                      child: _isLoading
                          ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                          : const Text(
                              'שמירה וסנכרון לענן',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('ביטול', style: TextStyle(color: Colors.grey, fontSize: 15)),
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

import 'package:flutter/material.dart';
import '../../data/models/client_model.dart';
import '../../data/repositories/client_repository.dart';

class ClientsBookView extends StatefulWidget {
  final String spreadsheetId;
  final ClientRepository clientRepository;
  final VoidCallback onRefreshRequired;

  const ClientsBookView({super.key, required this.spreadsheetId, required this.clientRepository, required this.onRefreshRequired});

  @override
  ClientsBookViewState createState() => ClientsBookViewState();
}

class ClientsBookViewState extends State<ClientsBookView> {
  List<ClientModel> _allClients = [];
  List<ClientModel> _filteredClients = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClientsData();
    _searchController.addListener(_filterClients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // הפונקציה הזו נקראת מדף הבית מיד לאחר שהטופס שומר בהצלחה.
  // הוספנו לה קריאה ישירה ל- _loadClientsData עם forceRefresh: true
  // כדי שהיא תמשוך את המידע ותבצע setState שיצייר מחדש את הרשימה המעודכנת
  void forceReloadFromOutside() {
    print('מבצע רענון ספר לקוחות מבחוץ (מכוח קריאה של דף הבית)...');
    _loadClientsData(forceRefresh: true);
  }

  Future<void> _loadClientsData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final clients = await widget.clientRepository.getClients(widget.spreadsheetId, forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _allClients = clients;
          _filteredClients = clients;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('שגיאה בטעינת ספר הלקוחות: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterClients() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredClients = _allClients;
      } else {
        _filteredClients = _allClients.where((client) {
          return client.fullName.toLowerCase().contains(query) || client.firstName.toLowerCase().contains(query) || client.phone.contains(query) || client.email.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _deleteClient(ClientModel client, int index) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('מחיקת לקוח', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('האם אתה בטוח שברצונך למחוק את ${client.fullName}?\n(הפעולה תבצע מחיקה רכה בענן).'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'מחק',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        // מחיקה רכה מבוססת כעת על מספר הטלפון כמפתח הראשי
        await widget.clientRepository.deleteClientSoft(widget.spreadsheetId, client.phone);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('הלקוח ${client.fullName} נמחק בהצלחה.')));

        // טעינה מחדש של הנתונים כדי לסנכרן את המסך
        await _loadClientsData(forceRefresh: true);

        // הפעלת רענון המשימות היומיות בדף הבית
        widget.onRefreshRequired();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה במחיקת לקוח: $e')));
      }
    }
  }

  void _openEditClientDialog(ClientModel client) {
    final formKey = GlobalKey<FormState>();
    final fullNameCtrl = TextEditingController(text: client.fullName);
    final firstNameCtrl = TextEditingController(text: client.firstName);
    final phoneCtrl = TextEditingController(text: client.phone); // מפתח ראשי - לא ניתן לשינוי
    final emailCtrl = TextEditingController(text: client.email);

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'עריכת פרטי לקוח',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: fullNameCtrl,
                    decoration: const InputDecoration(labelText: 'שם מלא *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'שדה חובה' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: firstNameCtrl,
                    decoration: const InputDecoration(labelText: 'שם פרטי *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'שדה חובה' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    readOnly: true, // מספר הטלפון הוא המפתח הראשי החדש, לכן הוא חסום לעריכה
                    decoration: InputDecoration(labelText: 'מספר טלפון (מפתח קבוע)', border: const OutlineInputBorder(), fillColor: Colors.grey.shade100, filled: true),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'אימייל', border: OutlineInputBorder()),
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
                if (!formKey.currentState!.validate()) return;

                final updatedClient = ClientModel(
                  phone: client.phone, // שמירה על המפתח המקורי
                  fullName: fullNameCtrl.text.trim(),
                  firstName: firstNameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  status: client.status,
                );

                try {
                  await widget.clientRepository.updateClient(widget.spreadsheetId, updatedClient);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('פרטי הלקוח עודכנו וסונכרנו בהצלחה!')));
                  }
                  await _loadClientsData(forceRefresh: true);
                  widget.onRefreshRequired();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה בעדכון לקוח: $e')));
                  }
                }
              },
              child: const Text('שמור שינויים', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // שורת חיפוש
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'חיפוש לקוח לפי שם, טלפון או מייל...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1B5565)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1B5565), width: 2),
                ),
              ),
            ),
          ),

          // רשימת הלקוחות
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B5565))))
                : _filteredClients.isEmpty
                ? const Center(
                    child: Text('לא נמצאו לקוחות פעילים במאגר.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadClientsData(forceRefresh: true),
                    color: const Color(0xFF1B5565),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filteredClients.length,
                      itemBuilder: (context, index) {
                        final client = _filteredClients[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFEBF3F5),
                              child: Text(
                                client.fullName.isNotEmpty ? client.fullName[0] : '?',
                                style: const TextStyle(color: Color(0xFF1B5565), fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(client.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('טלפון: ${client.phone}${client.email.isNotEmpty ? ' | מייל: ${client.email}' : ''}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF1B5565)),
                                  onPressed: () => _openEditClientDialog(client),
                                  tooltip: 'עריכת פרטי לקוח',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _deleteClient(client, index),
                                  tooltip: 'מחיקת לקוח',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

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
    print('מבצע רענון מאולץ לספר הלקוחות מפעולה חיצונית...');
    _loadClientsData(forceRefresh: true);
  }

  Future<void> _loadClientsData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final clients = await widget.clientRepository.getAllClients(widget.spreadsheetId, forceRefresh: forceRefresh);

      if (mounted) {
        setState(() {
          _allClients = clients.where((c) => c.isActive).toList();
          _filterClients();
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
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredClients = List.from(_allClients);
      } else {
        _filteredClients = _allClients.where((client) {
          return client.fullName.toLowerCase().contains(query) || client.phone.contains(query) || client.email.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _openEditClientDialog(ClientModel client) {
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

                  Navigator.pop(context);
                  setState(() => _isLoading = true);

                  try {
                    // תיקון בפינצטה: העברת ה-id המקורי של האובייקט כדי לשמור על רציפות המפתח הקבוע
                    final updatedClient = ClientModel(id: client.id, fullName: nameController.text.trim(), firstName: firstNameController.text.trim(), phone: phoneController.text.trim(), email: emailController.text.trim(), status: client.status);

                    await widget.clientRepository.updateClient(widget.spreadsheetId, updatedClient);
                    widget.onRefreshRequired(); // מעורר רענון של רשימת המשימות בדף הבית
                    await _loadClientsData(forceRefresh: true);
                  } catch (e) {
                    print('שגיאה בעדכון לקוח: $e');
                    _loadClientsData();
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

  void _deleteClient(ClientModel client, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('מחיקת לקוח', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text('האם אתה בטוח שברצונך למחוק את הלקוח ${client.fullName}?\nפעולה זו תסיר אותו מספר הלקוחות.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ביטול', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    // החלפת השימוש במחיקה לפי מזהה הלקוח הקבוע
                    await widget.clientRepository.deleteClientSoft(widget.spreadsheetId, client.id);
                    widget.onRefreshRequired(); // מעורר רענון של דף הבית
                    await _loadClientsData(forceRefresh: true);
                  } catch (e) {
                    print('שגיאה במחיקת לקוח: $e');
                    _loadClientsData();
                  }
                },
                child: const Text('מחקי', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // שורת חיפוש עליונה
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'חיפוש מהיר בספר הלקוחות...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1B5565)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1B5565), width: 2),
                ),
              ),
            ),
          ),

          // תוכן ראשי של הרשימה
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B5565))))
                : _filteredClients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('לא נמצאו לקוחות פעילים במערכת', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadClientsData(forceRefresh: true),
                    color: const Color(0xFF1B5565),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _filteredClients.length,
                      itemBuilder: (context, index) {
                        final client = _filteredClients[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // הוספת ריווח פנימי מעט לעידון
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1B5565).withOpacity(0.1),
                              child: Text(
                                client.fullName.isNotEmpty ? client.fullName[0] : '?',
                                style: const TextStyle(color: Color(0xFF1B5565), fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(client.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // שורת הטלפון עם אייקון מעודן
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_android_rounded, size: 14, color: Colors.black45),
                                      const SizedBox(width: 6),
                                      Text(client.phone, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                    ],
                                  ),
                                  // שורת המייל מוצגת רק אם קיים ערך, עם הגנת גמישות וחיתוך עדין
                                  if (client.email.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.mail_outline_rounded, size: 14, color: Colors.black45),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            client.email,
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis, // מונע שבירת שורה ומציג שלוש נקודות במקרה של מייל ארוך
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
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

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

  // ** הנה התיקון המרכזי שפותר את הבעיה **
  // הפונקציה הזו נקראת מדף הבית מיד לאחר שהטופס שומר בהצלחה.
  // הוספנו לה קריאה ישירה ל- _loadClientsData עם forceRefresh: true
  // כדי שהיא תמשוך את המידע ותבצע setState שיצייר מחדש את הרשימה על המסך!
  void loadClientsDataExternal() {
    _loadClientsData(forceRefresh: true);
  }

  Future<void> _loadClientsData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final clients = await widget.clientRepository.getClients(widget.spreadsheetId, forceRefresh: forceRefresh);

      final activeClients = clients.where((c) => c.isActive).toList();

      if (mounted) {
        setState(() {
          _allClients = activeClients;
          _filteredClients = activeClients;
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
    if (query.isEmpty) {
      setState(() {
        _filteredClients = _allClients;
      });
    } else {
      setState(() {
        _filteredClients = _allClients.where((client) {
          return client.fullName.toLowerCase().contains(query) || client.phone.contains(query) || client.email.toLowerCase().contains(query);
        }).toList();
      });
    }
  }

  Future<void> _deleteClient(ClientModel client, int indexInAllList) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('מחיקת לקוח'),
          content: Text('האם את בטוחה שברצונך למחוק את הלקוח "${client.fullName}" מהמערכת?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('מחק', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final updatedClient = ClientModel(id: client.id, fullName: client.fullName, firstName: client.firstName, phone: client.phone, email: client.email, status: 'מחוק');

        final allClientsInDb = await widget.clientRepository.getClients(widget.spreadsheetId);
        final sheetRowIndex = allClientsInDb.indexWhere((c) => c.id == client.id) + 2;

        await widget.clientRepository.editClientRow(widget.spreadsheetId, sheetRowIndex, updatedClient);

        await _loadClientsData(forceRefresh: true);
        widget.onRefreshRequired();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('הלקוח נמחק בהצלחה.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה במהלך המחיקה: $e')));
        }
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openEditClientDialog(ClientModel client) {
    final formKey = GlobalKey<FormState>();
    final fullNameCtrl = TextEditingController(text: client.fullName);
    final firstNameCtrl = TextEditingController(text: client.firstName);
    final phoneCtrl = TextEditingController(text: client.phone);
    final emailCtrl = TextEditingController(text: client.email);

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text(
              'עדכון פרטי לקוח',
              style: TextStyle(color: Color(0xFF1B5565), fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: fullNameCtrl,
                      decoration: const InputDecoration(labelText: 'שם מלא *'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'שדה חובה' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: firstNameCtrl,
                      decoration: const InputDecoration(labelText: 'שם פרטי לפנייה *'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'שדה חובה' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'טלפון *'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'שדה חובה' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'אימייל'),
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
                  Navigator.pop(context);

                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    final updatedClient = ClientModel(id: client.id, fullName: fullNameCtrl.text.trim(), firstName: firstNameCtrl.text.trim(), phone: phoneCtrl.text.trim(), email: emailCtrl.text.trim(), status: client.status);

                    final allClientsInDb = await widget.clientRepository.getClients(widget.spreadsheetId);
                    final sheetRowIndex = allClientsInDb.indexWhere((c) => c.id == client.id) + 2;

                    await widget.clientRepository.editClientRow(widget.spreadsheetId, sheetRowIndex, updatedClient);

                    await _loadClientsData(forceRefresh: true);
                    widget.onRefreshRequired();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('פרטי הלקוח עודכנו וסונכרנו בהצלחה!')));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה בעדכון הנתונים: $e')));
                    }
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
                child: const Text('עדכני בענן', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B5565))));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'חפשי לקוח לפי שם, טלפון או מייל...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1B5565)),
                suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear()) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1B5565), width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredClients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_rounded, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(_allClients.isEmpty ? 'ספר הלקוחות שלך ריק לגמרי.' : 'לא נמצאו לקוחות מתאימים לחיפוש.', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadClientsData(forceRefresh: true),
                    color: const Color(0xFF1B5565),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredClients.length,
                      itemBuilder: (context, index) {
                        final client = _filteredClients[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1B5565).withOpacity(0.1),
                              child: Text(
                                client.fullName.isNotEmpty ? client.fullName.substring(0, 1) : 'ל',
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

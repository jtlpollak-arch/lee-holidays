import 'package:flutter/material.dart';
import 'package:holidays/presentation/widgets/client_book_view/cbv_modify.dart';
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
    print('מבצע רענון מאולץ לספר הלקוחות בעקבות עדכון חיצוני...');
    _loadClientsData(forceRefresh: true);
  }

  Future<void> _loadClientsData({bool forceRefresh = false}) async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      final clients = await widget.clientRepository.getAllClients(widget.spreadsheetId, forceRefresh: forceRefresh);

      if (!mounted) return;
      setState(() {
        // טוענים את כל הלקוחות ומאפשרים ללוגיקת המיון לנהל את המיקום של המחוקים
        _allClients = clients;
        _filterClients();
        _isLoading = false;
      });
    } catch (e) {
      print('שגיאה בטעינת לקוחות: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה בטעינת הנתונים: $e')));
    }
  }

  void _filterClients() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredClients = List.from(_allClients);
      } else {
        _filteredClients = _allClients.where((client) {
          final fullName = client.fullName.toLowerCase();
          final phone = client.phone.toLowerCase();
          return fullName.contains(query) || phone.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _deleteClient(ClientModel client, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת לקוח', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('האם אתה בטוח שברצונך למחוק את ${client.fullName}?\nהלקוח יעבור לתחתית הרשימה ותוכל לשחזר אותו בכל עת.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'מחק',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.clientRepository.deleteClientSoft(widget.spreadsheetId, client.id);

      await _loadClientsData(forceRefresh: true);
      widget.onRefreshRequired();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${client.fullName} הועבר לארכיון הלקוחות המחוקים')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('השבתת הלקוח נכשלה: $e')));
    }
  }

  Future<void> _restoreClient(ClientModel client) async {
    try {
      final restoredClient = client.copyWith(status: 'פעיל');

      await widget.clientRepository.updateClient(widget.spreadsheetId, restoredClient);

      await _loadClientsData(forceRefresh: true);
      widget.onRefreshRequired();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${client.fullName} שוחזר בהצלחה וחזר למצב פעיל')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שחזור הלקוח נכשל: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // מיון דינמי: לקוחות פעילים בראש הרשימה, לקוחות מחוקים שוקעים לתחתית
    final List<ClientModel> sortedFilteredClients = List.from(_filteredClients)
      ..sort((a, b) {
        final bool aActive = a.status == 'פעיל';
        final bool bActive = b.status == 'פעיל';
        if (aActive == bActive) return 0;
        return aActive ? -1 : 1;
      });

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'חפש לקוח לפי שם או מספר טלפון...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1B5565)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1B5565), width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5565)))
                : sortedFilteredClients.isEmpty
                ? const Center(
                    child: Text('לא נמצאו לקוחות במאגר.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadClientsData(forceRefresh: true),
                    color: const Color(0xFF1B5565),
                    child: ListView.builder(
                      itemCount: sortedFilteredClients.length,
                      itemBuilder: (context, index) {
                        final client = sortedFilteredClients[index];
                        final bool isActive = client.status == 'פעיל';
                        final String firstLetter = client.fullName.isNotEmpty ? client.fullName[0] : '?';

                        return Opacity(
                          opacity: isActive ? 1.0 : 0.5,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                // עוגן חזותי: CircleAvatar יציב עם התאמה עיצובית לסטטוס
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isActive ? const Color(0xFF1B5565).withOpacity(0.1) : Colors.grey.shade200,
                                  child: Text(
                                    firstLetter,
                                    style: TextStyle(color: isActive ? const Color(0xFF1B5565) : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // מידע ופרטי הלקוח
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        client.fullName,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.phone_outlined, size: 14, color: isActive ? Colors.green.shade600 : Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                            client.phone,
                                            style: const TextStyle(fontSize: 13, color: Colors.black54, fontFamily: 'Roboto'),
                                          ),
                                        ],
                                      ),
                                      if (client.email.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.email_outlined, size: 14, color: isActive ? const Color(0xFF1B5565) : Colors.grey),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                client.email,
                                                style: const TextStyle(fontSize: 13, color: Colors.black54, fontFamily: 'Roboto'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // כפתורי פעולה מוגנים בריווח פנימי ומותאמים לסטטוס
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isActive) ...[
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF1B5565)),
                                        onPressed: () => CbvModify.showEditDialog(
                                          context: context,
                                          client: client,
                                          spreadsheetId: widget.spreadsheetId,
                                          clientRepository: widget.clientRepository,
                                          onLoadingStatusChanged: (isLoading) {
                                            setState(() {
                                              _isLoading = isLoading;
                                            });
                                          },
                                          onClientUpdated: () {
                                            widget.onRefreshRequired();
                                            _loadClientsData(forceRefresh: true);
                                          },
                                        ),
                                        tooltip: 'עריכת פרטי לקוח',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: () => _deleteClient(client, index),
                                        tooltip: 'מחיקת לקוח',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ] else ...[
                                      IconButton(
                                        icon: const Icon(Icons.restore_from_trash, color: Colors.green),
                                        onPressed: () => _restoreClient(client),
                                        tooltip: 'שחזור לקוח פעיל',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ],
                                  ],
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

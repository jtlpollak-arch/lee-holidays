import 'package:flutter/material.dart';
import '../../data/models/client_model.dart';
import '../../data/models/event_model.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../bloc_or_provider/home_cubit.dart';
import 'client_view/cv_new.dart';
import 'client_view/cv_edit.dart';
import 'client_view/cv_delete.dart';

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

  @override
  void initState() {
    super.initState();
    _loadInitialClients();
  }

  Future<void> _loadInitialClients() async {
    setState(() => _isLoadingClients = true);
    final clients = await widget.clientRepository.getAllClients(widget.spreadsheetId);
    setState(() {
      _allClients = clients.where((c) => c.status == 'פעיל').toList();
      _isLoadingClients = false;
    });
  }

  Future<void> _loadEventsForSelectedClient() async {
    if (_selectedClient == null) return;
    setState(() => _isLoadingEvents = true);
    final allEvents = await widget.eventRepository.getAllEvents(widget.spreadsheetId);
    setState(() {
      _clientEvents = allEvents.where((e) => e.clientId == _selectedClient!.id && e.status != 'מחוק').toList();
      _isLoadingEvents = false;
    });
  }

  String _getEventEmoji(String type) {
    if (type.contains('יום הולדת')) return '🎂';
    if (type.contains('קניית דירה')) return '🔑';
    if (type.contains('מכירת דירה')) return '💰';
    if (type.contains('השכרת נכס')) return '🏠';
    if (type.contains('פגישת היכרות')) return '🤝';
    if (type.contains('יום שנה')) return '❤️';
    return '📌';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'אירועי לקוח',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700, // משקל מודגש אך לא "כבד"
              color: Color(0xFF1B5565), // שימוש בצבע המותג שלך
              letterSpacing: -0.5, // ריווח אותיות מהודק למראה מודרני
            ),
          ),
          centerTitle: true, // זה נותן מראה מאוזן ו"אפליקטיבי"
        ),
        floatingActionButton: _selectedClient == null
            ? null
            : FloatingActionButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CVNewEventForm(
                    client: _selectedClient!,
                    onSubmit: (newEvent) async {
                      await widget.eventRepository.addNewEvent(widget.spreadsheetId, newEvent, _selectedClient!.fullName);
                      await _loadEventsForSelectedClient();
                    },
                  ),
                ),
                child: const Icon(Icons.add),
              ),
        body: _isLoadingClients
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // בתוך ה-Column שלך
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Align(
                      alignment: Alignment.centerRight, // יישור לצד ימין
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 350), // הגבלת רוחב ל-300 פיקסלים
                        child: Autocomplete<ClientModel>(
                          displayStringForOption: (ClientModel option) => option.fullName,
                          // לוגיקת הסינון: מה מציגים ברגע שהמשתמש מקליד
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            // אם התיבה ריקה - תציג את כל הלקוחות
                            if (textEditingValue.text.isEmpty) {
                              return _allClients;
                            }
                            // אם יש טקסט - תסנן את הרשימה
                            return _allClients.where((ClientModel client) {
                              return client.fullName.toLowerCase().contains(textEditingValue.text.toLowerCase());
                            });
                          },

                          // מה קורה כשבוחרים לקוח מהרשימה
                          onSelected: (ClientModel selection) {
                            setState(() {
                              _selectedClient = selection;
                            });
                            _loadEventsForSelectedClient();
                          },

                          // איך שדה הטקסט נראה (שמירה על העיצוב שלך)
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'חיפוש לקוח...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            );
                          },

                          // איך כל תוצאה ברשימה נראית
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topRight,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(16),
                                child: SizedBox(
                                  width: MediaQuery.of(context).size.width - 32, // התאמה לרוחב המסך
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final client = options.elementAt(index);
                                      return ListTile(
                                        title: Text(client.fullName, textAlign: TextAlign.right),
                                        onTap: () => onSelected(client),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _clientEvents.length,
                      itemBuilder: (context, index) {
                        final event = _clientEvents[index];
                        return Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                                child: Text(_getEventEmoji(event.eventType), style: const TextStyle(fontSize: 22)),
                              ),
                              title: Text(event.eventType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('${event.date.day}/${event.date.month} • ${event.address}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_rounded, color: Colors.blueGrey[400], size: 20),
                                    onPressed: () => showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => CVEditEventForm(
                                        client: _selectedClient!,
                                        eventToEdit: event,
                                        onSubmit: (updated) async {
                                          await widget.eventRepository.updateEvent(widget.spreadsheetId, updated);
                                          await _loadEventsForSelectedClient();
                                          if (mounted) Navigator.pop(context);
                                        },
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (_) => CVDeleteDialog(
                                        event: event,
                                        client: _selectedClient!,
                                        onDeleteConfirmed: () async {
                                          await widget.eventRepository.deleteEventSoft(widget.spreadsheetId, event);
                                          await _loadEventsForSelectedClient();
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[200]),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

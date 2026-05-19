import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/spreadsheet_manager.dart';
import '../../data/models/client_model.dart';
import '../../data/datasources/google_sheets_data_source.dart';
import '../../data/datasources/google_calendar_api.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../domain/usecases/calculate_daily_events_usecase.dart';
import '../bloc_or_provider/home_cubit.dart';
import '../widgets/greeting_canvas.dart';
import '../widgets/add_client_sheet.dart';
import '../widgets/clients_book_view.dart';

class HomePage extends StatefulWidget {
  final HomeCubit cubit;
  final GoogleSheetsDataSource googleSheetsDataSource;
  final GoogleCalendarApi googleCalendarApi;
  final ClientRepository clientRepository;
  final EventRepository eventRepository;

  const HomePage({super.key, required this.cubit, required this.googleSheetsDataSource, required this.googleCalendarApi, required this.clientRepository, required this.eventRepository});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final SpreadsheetManager _spreadsheetManager = SpreadsheetManager();

  // מפתח גלובלי המאפשר שליטה ורענון של ספר הלקוחות מבחוץ
  final GlobalKey<ClientsBookViewState> _clientsBookKey = GlobalKey<ClientsBookViewState>();

  GoogleSignInAccount? _googleUser;
  bool _isCheckingAuth = true;
  bool _isSettingUpRealData = false;
  String? _activeSpreadsheetId;
  int _totalRecordsCount = 0;

  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();

    widget.cubit.listen((state) {
      if (mounted) {
        setState(() {
          if (state is HomeSuccess) {
            _totalRecordsCount = state.dailyEvents.length;
          }
        });
      }
    });

    _authService.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      if (mounted) {
        setState(() {
          _googleUser = account;
        });
        if (account != null) {
          _setupAndLoadRealData();
        }
      }
    });

    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    final user = await _authService.signInSilently();
    if (mounted) {
      setState(() {
        _googleUser = user;
        _isCheckingAuth = false;
      });
      if (user != null) {
        _setupAndLoadRealData();
      }
    }
  }

  Future<void> _setupAndLoadRealData() async {
    if (_isSettingUpRealData) return;

    final authenticatedClient = await _authService.getAuthenticatedClient();
    if (authenticatedClient != null) {
      try {
        setState(() {
          _isSettingUpRealData = true;
        });

        widget.googleSheetsDataSource.updateAuthenticatedClient(authenticatedClient);
        widget.googleCalendarApi.updateAuthenticatedClient(authenticatedClient);

        final id = await _spreadsheetManager.getOrCreateSpreadsheet(authenticatedClient);

        if (mounted) {
          setState(() {
            _activeSpreadsheetId = id;
          });

          widget.cubit.loadDailyOverview(spreadsheetId: id);
        }
      } catch (e) {
        print('שגיאה בתהליך איתור/יצירת קובץ הנתונים: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isSettingUpRealData = false;
          });
        }
      }
    }
  }

  Future<void> _handleSignIn() async {
    try {
      await _authService.signIn();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ההתחברות בוטלה או נכשלה: $error')));
      }
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    setState(() {
      _googleUser = null;
      _activeSpreadsheetId = null;
      _totalRecordsCount = 0;
      _currentTabIndex = 0;
    });
  }

  String _generateDefaultGreeting(ClientModel client, String eventType) {
    if (eventType == 'יום הולדת') {
      return 'רציתי לאחל לך המון מזל טוב, יום הולדת שמח, בריאות ושפע של הצלחה בכל מה שתעשה/י!';
    } else if (eventType == 'קניית דירה') {
      return 'איזה כיף לציין את היום המרגש הזה! שיהיה המון מזל טוב על רכישת הדירה, שתזכו להמון רגעים מאושרים בבית החדש.';
    } else if (eventType == 'מכירת דירה') {
      return 'ברכות על המכירה! מאחלת לך המון הצלחה בדרך החדשה ובצעד הבא.';
    }
    return 'שולחת לך המון מזל טוב, בריאות ושמחה לרגל האירוע המרגש!';
  }

  void _openGreetingSender(BuildContext context, DailyEventResult dailyEvent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: AnimatedPadding(
            padding: MediaQuery.of(context).viewInsets,
            duration: const Duration(milliseconds: 100),
            child: SingleChildScrollView(
              child: GreetingCanvas(client: dailyEvent.client, defaultGreetingText: _generateDefaultGreeting(dailyEvent.client, dailyEvent.event.eventType), logoAssetPath: 'assets/images/logo.png'),
            ),
          ),
        );
      },
    );
  }

  void _openAddClientSheet(BuildContext context) {
    if (_activeSpreadsheetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('המערכת עדיין לא סיימה להסתנכרן מול הדרייב. אנא המתיני.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: SingleChildScrollView(
            child: AddClientSheet(
              spreadsheetId: _activeSpreadsheetId!,
              clientRepository: widget.clientRepository,
              eventRepository: widget.eventRepository,
              homeCubit: widget.cubit,
              onClientAdded: () {
                // ריענון מיידי של ספר הלקוחות על המסך ברגע שההוספה מסתיימת
                _clientsBookKey.currentState?.forceReloadFromOutside();
              },
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _getEventTheme(String eventType) {
    if (eventType == 'יום הולדת') {
      return {'icon': Icons.cake_rounded, 'color': const Color(0xFF8B7355), 'bgColor': const Color(0xFF8B7355).withOpacity(0.1)};
    } else if (eventType == 'קניית דירה') {
      return {'icon': Icons.vpn_key_rounded, 'color': const Color(0xFF1B5565), 'bgColor': const Color(0xFF1B5565).withOpacity(0.1)};
    } else {
      return {'icon': Icons.real_estate_agent_rounded, 'color': Colors.amber.shade800, 'bgColor': Colors.amber.shade50};
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.cubit.state;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentTabIndex == 0 ? 'הברכות של לי' : 'ספר הלקוחות שלי', style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0.5,
          actions: [
            if (_googleUser != null) ...[
              IconButton(
                icon: const Icon(Icons.sync, color: Color(0xFF1B5565)),
                onPressed: () {
                  widget.cubit.loadDailyOverview(spreadsheetId: _activeSpreadsheetId!);
                  _clientsBookKey.currentState?.forceReloadFromOutside();
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                onPressed: _handleSignOut,
                tooltip: 'התנתקי מחשבון גוגל',
              ),
            ],
          ],
        ),
        body: _isCheckingAuth
            ? const Center(child: CircularProgressIndicator())
            : _googleUser == null
            ? _buildSignInScreen()
            : _buildNavigationBody(state),

        floatingActionButton: _googleUser != null && _currentTabIndex == 1
            ? FloatingActionButton(
                onPressed: () => _openAddClientSheet(context),
                backgroundColor: const Color(0xFF1B5565),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              )
            : null,

        bottomNavigationBar: _googleUser != null
            ? BottomNavigationBar(
                currentIndex: _currentTabIndex,
                selectedItemColor: const Color(0xFF1B5565),
                unselectedItemColor: Colors.grey,
                onTap: (index) {
                  setState(() {
                    _currentTabIndex = index;
                  });
                },
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.today_rounded), label: 'המשימות להיום'),
                  BottomNavigationBarItem(icon: Icon(Icons.contact_phone_rounded), label: 'ספר לקוחות'),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildSignInScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 120),
            const SizedBox(height: 30),
            const Text(
              'ברוכה הבאה למערכת הברכות',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'כדי לסנכרן את הלקוחות מתוך ה-Google Sheets והיומן שלך, יש לבצע התחברות מאובטחת.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _handleSignIn,
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('התחברי באמצעות Google', style: TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5565),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBody(HomeState state) {
    if (_currentTabIndex == 1 && _activeSpreadsheetId != null) {
      return ClientsBookView(
        key: _clientsBookKey, // הזרקת המפתח הגלובלי לצורך ריענון המסך
        spreadsheetId: _activeSpreadsheetId!,
        clientRepository: widget.clientRepository,
        onRefreshRequired: () => widget.cubit.loadDailyOverview(spreadsheetId: _activeSpreadsheetId!),
      );
    }
    return _buildBody(state);
  }

  Widget _buildBody(HomeState state) {
    if (state is HomeLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('היי לי, בוקר טוב!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text('הנה המשימות שלך להיום:', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1B5565).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF8B7355).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_done, color: Color(0xFF1B5565), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'קובץ הנתונים בענן מחובר ומסונכרן',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
                    ),
                    Text(
                      _activeSpreadsheetId != null ? 'קובץ פעיל בענן גוגל' : 'מאתר קובץ נתונים...',
                      style: const TextStyle(fontSize: 11, color: Colors.grey, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF8B7355), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '$_totalRecordsCount משימות',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildEventsList(state)),
      ],
    );
  }

  Widget _buildEventsList(HomeState state) {
    if (state is HomeSuccess) {
      final events = state.dailyEvents;
      if (events.isEmpty) {
        return const Center(
          child: Text(
            'אין אירועים להיום.\nיום עבודה פורה!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final e = events[index];
          final theme = _getEventTheme(e.event.eventType);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
              border: Border.all(color: Colors.grey.withOpacity(0.15)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: theme['bgColor'], borderRadius: BorderRadius.circular(10)),
                  child: Icon(theme['icon'], color: theme['color'], size: 24),
                ),
                title: Text(e.client.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('${e.event.eventType} | ${e.displayMessage}', style: TextStyle(fontSize: 13, color: e.isEarlyReminder ? Colors.orange.shade800 : Colors.grey.shade600)),
                trailing: ElevatedButton(
                  onPressed: () => _openGreetingSender(context, e),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5565),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('ברכה', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text('טלפון: ${e.client.phone}', style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                        if (e.client.email.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text('מייל: ${e.client.email}', style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ],
                        if (e.event.address.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text('כתובת נכס / אזור: ${e.event.address}', style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ],
                        if (e.event.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.speaker_notes, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('הערות: ${e.event.notes}', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    return const Center(child: Text('משהו השתבש... נסי לרענן.'));
  }
}

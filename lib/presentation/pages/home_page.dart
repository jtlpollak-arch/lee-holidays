import 'package:flutter/material.dart';
import 'package:holidays/presentation/widgets/client_events_view.dart';
import 'package:holidays/presentation/widgets/daily_events_list.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/spreadsheet_manager.dart';
import '../../data/datasources/google_sheets_data_source.dart';
import '../../data/datasources/google_calendar_api.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../bloc_or_provider/home_cubit.dart';
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

  int _selectedIndex = 0;
  String? _spreadsheetId;
  bool _isInitializing = true;
  String? _initError;

  // מפתח גלובלי לגישה ורענון של ספר הלקוחות מהפיג' הנוכחי
  final GlobalKey<ClientsBookViewState> _clientsBookKey = GlobalKey<ClientsBookViewState>();

  @override
  void initState() {
    super.initState();
    // האזנה לשינויי סטייט מה-Cubit כדי לעדכן את הממשק בצורה תקינה
    widget.cubit.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });
    _initializeSpreadsheet();
  }

  Future<void> _initializeSpreadsheet() async {
    try {
      setState(() {
        _isInitializing = true;
        _initError = null;
      });

      var currentUser = await _authService.signInSilently();
      if (currentUser == null) {
        // פותח את החלון הויזואלי של גוגל וממתין לבחירת חשבון
        currentUser = await _authService.signIn();

        // אם המשתמשת ביטלה את החלון ולא בחרה חשבון
        if (currentUser == null) {
          setState(() {
            _isInitializing = false;
          });
          throw Exception('נכשל איתור קליינט מאומת מול שרתי גוגל.');
        }
      }
      final authClient = await _authService.getAuthenticatedClient();
      if (authClient == null) {
        throw Exception('נכשל איתור קליינט מאומת מול שרתי גוגל.');
      }

      widget.googleSheetsDataSource.updateAuthenticatedClient(authClient);
      widget.googleCalendarApi.updateAuthenticatedClient(authClient);

      final sId = await _spreadsheetManager.getOrCreateSpreadsheet(authClient);

      setState(() {
        _spreadsheetId = sId;
        _isInitializing = false;
      });

      // טעינת הנתונים למסך הבית הראשי
      await widget.cubit.loadDailyOverview(spreadsheetId: sId);
    } catch (e) {
      setState(() {
        _initError = e.toString();
        _isInitializing = false;
      });
    }
  }

  void _showAddClientBottomSheet() {
    if (_spreadsheetId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: AddClientSheet(
            spreadsheetId: _spreadsheetId!,
            clientRepository: widget.clientRepository,
            homeCubit: widget.cubit,
            onClientAdded: () {
              // קריאה לרענון מיידי של ספר הלקוחות באמצעות המתודה הקיימת בו
              _clientsBookKey.currentState?.forceReloadFromOutside();
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // עטיפה ב-Directionality כדי שכל ה-AppBar יתיישר לימין
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AppBar(
            title: const Text(
              'מערכת הברכות של לי',
              style: TextStyle(
                fontWeight: FontWeight.w800, // משקל חזק יותר
                fontSize: 20,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            backgroundColor: const Color(0xFF1B5565),
            elevation: 4, // צל עמוק יותר למראה מודרני
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
            // ה-actions מסתדרים אוטומטית משמאל לימין לפי ה-Directionality
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _isInitializing ? null : _initializeSpreadsheet,
                tooltip: 'סנכרון ורענון מלא',
              ),
              const SizedBox(width: 8), // מרווח קטן מהקצה
            ],
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: _selectedIndex == 1 && _spreadsheetId != null
          ? FloatingActionButton(
              onPressed: _showAddClientBottomSheet,
              backgroundColor: const Color(0xFF1B5565),
              tooltip: 'הוספת לקוח חדש',
              child: const Icon(Icons.person_add_alt_1, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Directionality(
        textDirection: TextDirection.rtl,
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            if (index == 0 && _spreadsheetId != null) {
              widget.cubit.loadDailyOverview(spreadsheetId: _spreadsheetId!);
            }
          },
          selectedItemColor: const Color(0xFF1B5565),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined), activeIcon: Icon(Icons.auto_awesome), label: 'משימות להיום'),
            BottomNavigationBarItem(icon: Icon(Icons.contact_phone_outlined), activeIcon: Icon(Icons.contact_phone), label: 'ספר לקוחות'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'אירועים ועסקאות'),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B5565))),
            SizedBox(height: 16),
            Text('מאתחל מערך נתונים ומאמת קבצים בענן...', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
              const SizedBox(height: 16),
              const Text('שגיאה באתחול האפליקציה', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                _initError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeSpreadsheet,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5565)),
                child: const Text('ניסיון חוזר', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    switch (_selectedIndex) {
      case 0:
        return _buildDailyTasksTab();
      case 1:
        return ClientsBookView(
          spreadsheetId: _spreadsheetId!,
          clientRepository: widget.clientRepository,
          eventRepository: widget.eventRepository,
          googleCalendarApi: widget.googleCalendarApi,
          onRefreshRequired: () => widget.cubit.loadDailyOverview(spreadsheetId: _spreadsheetId!), // <--- התיקון המדויק ללא ניחושים
        );
      case 2:
        return ClientEventsView(spreadsheetId: _spreadsheetId!, clientRepository: widget.clientRepository, eventRepository: widget.eventRepository, homeCubit: widget.cubit);
      default:
        return _buildDailyTasksTab();
    }
  }

  Widget _buildDailyTasksTab() {
    final state = widget.cubit.state;

    if (state is HomeLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B5565))));
    }

    if (state is HomeSuccess) {
      return RefreshIndicator(
        onRefresh: () => widget.cubit.loadDailyOverview(spreadsheetId: _spreadsheetId!),
        color: const Color(0xFF1B5565),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                color: const Color(0xFF1B5565).withOpacity(0.05),
                child: Text(
                  'לי היקרה! שלום! להלן הברכות המתוזמנות להיום (${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}):',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1B5565)),
                ),
              ),
              Expanded(
                child: DailyEventsList(events: state.dailyEvents, cubit: widget.cubit, spreadsheetId: _spreadsheetId),
              ),
            ],
          ),
        ),
      );
    }

    if (state is HomeFailure) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'שגיאה בטעינת המשימות: ${state.errorMessage}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => widget.cubit.loadDailyOverview(spreadsheetId: _spreadsheetId!),
              child: const Text('נסה שנית'),
            ),
          ],
        ),
      );
    }

    return const Center(child: Text('ברוך הבא!'));
  }
}

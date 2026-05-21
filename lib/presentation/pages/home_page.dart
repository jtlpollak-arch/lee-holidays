import 'package:flutter/material.dart';
import 'package:holidays/presentation/widgets/client_events_view.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/spreadsheet_manager.dart';
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

      final currentUser = await _authService.signInSilently();
      if (currentUser == null) {
        throw Exception('משתמש לא מחובר לחשבון גוגל. יש לבצע התחברות תחילה.');
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
          key: _clientsBookKey,
          spreadsheetId: _spreadsheetId!,
          clientRepository: widget.clientRepository,
          onRefreshRequired: () {
            widget.cubit.loadDailyOverview(spreadsheetId: _spreadsheetId!);
          },
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
              Expanded(child: _buildEventList(state.dailyEvents)),
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

  Widget _buildEventList(List<DailyEventResult> events) {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          'אין ברכות או אירועים המתוזמנים להיום.\nיום שקט ומוצלח!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final e = events[index];

        // תיקון כפילות הפתיח: מתחילים ישירות מגוף האיחול
        final String defaultText = 'רציתי לאחל לך המון מזל טוב לרגל ${e.event.eventType}! ✨';

        final isBirthday = e.event.eventType.trim() == 'יום הולדת';
        final Color eventColor = isBirthday ? const Color(0xFF8B1E3F) : const Color(0xFFC5A880);
        final String eventEmoji = isBirthday ? '🎂 ' : '🏡 ';

        // קביעת צבעי תגית הסטטוס (אירוע של היום / תזכורת מוקדמת)
        final Color statusBgColor = e.isEarlyReminder ? Colors.orange.shade50 : Colors.green.shade50;
        final Color statusTextColor = e.isEarlyReminder ? Colors.orange.shade800 : Colors.green.shade800;

        // בדיקה האם האירוע כבר נשלח בשנה הנוכחית
        bool isSentThisYear = false;
        if (e.event.sentTimestamp.isNotEmpty) {
          final DateTime? sentDate = DateTime.tryParse(e.event.sentTimestamp);
          if (sentDate != null && sentDate.year == DateTime.now().year) {
            isSentThisYear = true;
          }
        }

        return Opacity(
          opacity: isSentThisYear ? 0.5 : 1.0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
              border: Border(
                left: BorderSide(color: eventColor, width: 5), // פס צבע אנכי שמאלי
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Row(
                children: [
                  Text(e.client.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: eventColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '$eventEmoji${e.event.eventType}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: eventColor),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // הפיכת הודעת הסטטוס המקורית לתגית מעוגלת ועדינה
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        e.displayMessage,
                        style: TextStyle(color: statusTextColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // שורות המידע עם אייקונים, ריווח והדגשת כותרות הנתונים
                    if (e.event.address.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 15, color: Colors.black45),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 13, color: Colors.black87, fontFamily: 'Roboto'),
                                children: [
                                  const TextSpan(
                                    text: 'נכס: ',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: e.event.address),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (e.event.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.notes_rounded, size: 15, color: Colors.black45),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 13, color: Colors.black54, fontFamily: 'Roboto'),
                                children: [
                                  const TextSpan(
                                    text: 'הערות: ',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: e.event.notes),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              trailing: isSentThisYear
                  ? InkWell(
                      onTap: () {
                        if (_spreadsheetId != null) {
                          widget.cubit.cancelEventSentStatus(spreadsheetId: _spreadsheetId!, event: e.event);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400), // תוקן השגיאה מכאן
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              'נשלח',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () {
                        // הוספנו את הקריאה לסימון כנשלח כאן
                        if (_spreadsheetId != null) {
                          widget.cubit.markEventAsSent(spreadsheetId: _spreadsheetId!, event: e.event);
                        }

                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                          builder: (context) => Padding(
                            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                            child: GreetingCanvas(client: e.client, event: e.event, defaultGreetingText: defaultText, logoAssetPath: 'assets/images/logo.png'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5565),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                      label: const Text('ברכה', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
            ),
          ),
        );
      },
    );
  }
}

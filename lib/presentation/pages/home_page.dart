import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/spreadsheet_manager.dart';
import '../../data/models/client_model.dart';
import '../../data/datasources/google_sheets_data_source.dart';
import '../../data/datasources/google_calendar_api.dart';
import '../../domain/usecases/calculate_daily_events_usecase.dart';
import '../bloc_or_provider/home_cubit.dart';
import '../widgets/greeting_canvas.dart';

class HomePage extends StatefulWidget {
  final HomeCubit cubit;
  final GoogleSheetsDataSource googleSheetsDataSource;
  final GoogleCalendarApi googleCalendarApi;

  const HomePage({super.key, required this.cubit, required this.googleSheetsDataSource, required this.googleCalendarApi});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final SpreadsheetManager _spreadsheetManager = SpreadsheetManager();

  GoogleSignInAccount? _googleUser;
  bool _isCheckingAuth = true;
  bool _isSettingUpRealData = false; // משתנה הגנה למניעת יצירה כפולה של קבצים
  String? _activeSpreadsheetId;
  int _totalRecordsCount = 0;

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
    // אם כבר רץ תהליך איתור או יצירה ברגע זה, אנחנו חוסמים קריאות מקבילות
    if (_isSettingUpRealData) return;

    final authenticatedClient = await _authService.getAuthenticatedClient();
    if (authenticatedClient != null) {
      try {
        setState(() {
          _isSettingUpRealData = true;
        });

        // הזרקת הצינור המאומת לשני מקורות ה-API של גוגל
        widget.googleSheetsDataSource.updateAuthenticatedClient(authenticatedClient);
        widget.googleCalendarApi.updateAuthenticatedClient(authenticatedClient);

        // איתור או יצירה של הקובץ הפיזי ב-Google Drive האמיתי של המשתמש
        final id = await _spreadsheetManager.getOrCreateSpreadsheet(authenticatedClient);

        if (mounted) {
          setState(() {
            _activeSpreadsheetId = id;
          });

          // קריאה לטעינת המידע מהקובץ האמיתי
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

  @override
  Widget build(BuildContext context) {
    final state = widget.cubit.state;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('הברכות של לי', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0.5,
          actions: [
            if (_googleUser != null) ...[
              IconButton(
                icon: const Icon(Icons.sync, color: Color(0xFF1B5565)),
                onPressed: _setupAndLoadRealData,
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
            : _buildBody(state),
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

  Widget _buildBody(HomeState state) {
    if (state is HomeLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          color: Colors.white,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('היי לי, בוקר טוב!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text('הנה המשימות שלך להיום:', style: TextStyle(color: Colors.grey)),
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
        padding: const EdgeInsets.all(16),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final e = events[index];
          return Card(
            child: ListTile(
              title: Text(e.client.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${e.event.eventType} | ${e.displayMessage}'),
              trailing: ElevatedButton(
                onPressed: () => _openGreetingSender(context, e),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5565)),
                child: const Text('שלחי ברכה', style: TextStyle(color: Colors.white)),
              ),
            ),
          );
        },
      );
    }
    return const Center(child: Text('משהו השתבש... נסי לרענן.'));
  }
}

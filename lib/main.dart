import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// ייבוא שכבת הנתונים (Data Layer)
import 'data/datasources/local_db_data_source.dart';
import 'data/datasources/google_sheets_data_source.dart';
import 'data/datasources/google_calendar_api.dart';
import 'data/models/client_model.dart';
import 'data/models/event_model.dart';
import 'data/repositories/client_repository.dart';
import 'data/repositories/event_repository.dart';

// ייבוא שכבת הלוגיקה והתצוגה (Domain & Presentation)
import 'domain/usecases/calculate_daily_events_usecase.dart';
import 'presentation/bloc_or_provider/home_cubit.dart';
import 'presentation/pages/home_page.dart';

void main() async {
  // 1. וידוא שכל רכיבי התשתית של פלאטר מאותחלים
  WidgetsFlutterBinding.ensureInitialized();

  // 2. אתחול SharedPreferences לשמירה המקומית בטלפון
  final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();

  // 3. יצירת אובייקט זמני של HTTP Client
  final http.Client httpClient = http.Client();

  // 4. אתחול מקורות המידע הגולמיים
  final LocalDbDataSource localDbDataSource = LocalDbDataSourceImpl(sharedPreferences);
  final GoogleSheetsDataSource googleSheetsDataSource = GoogleSheetsDataSourceImpl();
  final GoogleCalendarApi googleCalendarApi = GoogleCalendarApiImpl(httpClient);

  // 5. הזרקת נתוני בדיקה לתוך ה-Cache המקומי של המכשיר
  await _injectMockData(localDbDataSource);

  // 6. אתחול מנהלי הלוגיקה של המידע (Repositories)
  final ClientRepository clientRepository = ClientRepositoryImpl(googleSheetsDataSource: googleSheetsDataSource, localDbDataSource: localDbDataSource);

  final EventRepository eventRepository = EventRepositoryImpl(googleSheetsDataSource: googleSheetsDataSource, localDbDataSource: localDbDataSource, googleCalendarApi: googleCalendarApi);

  // 7. אתחול ה-Use Case וה-Cubit שינהלו את מסך הבית
  final CalculateDailyEventsUseCase calculateDailyEventsUseCase = CalculateDailyEventsUseCase();

  final HomeCubit homeCubit = HomeCubit(clientRepository: clientRepository, eventRepository: eventRepository, calculateDailyEventsUseCase: calculateDailyEventsUseCase);

  // 8. הרצת האפליקציה
  runApp(MainApp(homeCubit: homeCubit, googleSheetsDataSource: googleSheetsDataSource));
}

Future<void> _injectMockData(LocalDbDataSource localDb) async {
  final List<ClientModel> mockClients = [const ClientModel(id: 101, fullName: 'משה לוי', firstName: 'משה', phone: '050-1234567'), const ClientModel(id: 102, fullName: 'רונית אברהם', firstName: 'רונית', phone: '052-7654321'), const ClientModel(id: 103, fullName: 'אבי כהן', firstName: 'אבי', phone: '054-1112233')];

  final DateTime now = DateTime.now();

  final List<EventModel> mockEvents = [EventModel(clientId: 101, date: now, eventType: 'יום הולדת', notes: 'לקוח VIP - מחפש פנטהאוז'), EventModel(clientId: 102, date: now, eventType: 'קניית דירה', notes: 'סגירת עסקה ברחוב העצמאות'), EventModel(clientId: 103, date: now.add(const Duration(days: 2)), eventType: 'יום הולדת', notes: 'לשלוח לו גם את הגלויה המודפסת')];

  await localDb.saveClients(mockClients);
  await localDb.saveEvents(mockEvents);
}

class MainApp extends StatelessWidget {
  final HomeCubit homeCubit;
  final GoogleSheetsDataSource googleSheetsDataSource;
  static const String _dummySpreadsheetId = 'dummy_spreadsheet_id';

  const MainApp({super.key, required this.homeCubit, required this.googleSheetsDataSource});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'מערכת ברכות נדל"ן',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primaryColor: const Color(0xFF8B7355), scaffoldBackgroundColor: const Color(0xFFF8F9FA), fontFamily: 'Assistant'),
      home: HomePage(cubit: homeCubit, spreadsheetId: _dummySpreadsheetId, googleSheetsDataSource: googleSheetsDataSource),
    );
  }
}

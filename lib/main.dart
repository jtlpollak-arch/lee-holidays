import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'data/datasources/local_db_data_source.dart';
import 'data/datasources/google_sheets_data_source.dart';
import 'data/datasources/google_calendar_api.dart';
import 'data/repositories/client_repository.dart';
import 'data/repositories/event_repository.dart';

import 'domain/usecases/calculate_daily_events_usecase.dart';
import 'presentation/bloc_or_provider/home_cubit.dart';
import 'presentation/pages/home_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // אתחול ישיר באמצעות הגדרות קשיחות בקוד (עוקף את שגיאות ה-Native לחלוטין)
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBCfo3DoB1fY8BUo-pcWlImmIAANaok9Eo', // החלף בערך מהדפדפן
        appId: '1:201464711048:web:fcff4852a31703fb345c3d', // החלף בערך מהדפדפן
        messagingSenderId: '201464711048', // החלף בערך מהדפדפן
        projectId: 'lee-greetings', // שם הפרויקט שלך
        storageBucket: 'lee-greetings.firebasestorage.app',
      ),
    );
    debugPrint('Firebase אותחל בהצלחה רבה ובאופן ישיר!');
  } catch (e) {
    debugPrint('שגיאה באתחול Firebase: $e');
  }

  final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();

  final LocalDbDataSource localDbDataSource = LocalDbDataSourceImpl(sharedPreferences);
  final GoogleSheetsDataSource googleSheetsDataSource = GoogleSheetsDataSourceImpl();
  final GoogleCalendarApi googleCalendarApi = GoogleCalendarApiImpl();

  final ClientRepository clientRepository = ClientRepositoryImpl(googleSheetsDataSource: googleSheetsDataSource, localDbDataSource: localDbDataSource);

  final EventRepository eventRepository = EventRepositoryImpl(googleSheetsDataSource: googleSheetsDataSource, localDbDataSource: localDbDataSource, googleCalendarApi: googleCalendarApi);

  final CalculateDailyEventsUseCase calculateDailyEventsUseCase = CalculateDailyEventsUseCase();

  final HomeCubit homeCubit = HomeCubit(clientRepository: clientRepository, eventRepository: eventRepository, calculateDailyEventsUseCase: calculateDailyEventsUseCase);

  runApp(MainApp(homeCubit: homeCubit, googleSheetsDataSource: googleSheetsDataSource, googleCalendarApi: googleCalendarApi, clientRepository: clientRepository, eventRepository: eventRepository));
}

class MainApp extends StatelessWidget {
  final HomeCubit homeCubit;
  final GoogleSheetsDataSource googleSheetsDataSource;
  final GoogleCalendarApi googleCalendarApi;
  final ClientRepository clientRepository;
  final EventRepository eventRepository;

  const MainApp({super.key, required this.homeCubit, required this.googleSheetsDataSource, required this.googleCalendarApi, required this.clientRepository, required this.eventRepository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'מערכת ברכות נדל"ן',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primaryColor: const Color(0xFF8B7355), scaffoldBackgroundColor: const Color(0xFFF8F9FA), fontFamily: 'Assistant'),

      // 2. הוסף את השורות הבאות כאן:
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: const [Locale('he', 'IL')],
      locale: const Locale('he', 'IL'),

      home: HomePage(cubit: homeCubit, googleSheetsDataSource: googleSheetsDataSource, googleCalendarApi: googleCalendarApi, clientRepository: clientRepository, eventRepository: eventRepository),
    );
  }
}

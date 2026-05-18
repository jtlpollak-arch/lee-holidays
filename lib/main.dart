import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/datasources/local_db_data_source.dart';
import 'data/datasources/google_sheets_data_source.dart';
import 'data/datasources/google_calendar_api.dart';
import 'data/repositories/client_repository.dart';
import 'data/repositories/event_repository.dart';

import 'domain/usecases/calculate_daily_events_usecase.dart';
import 'presentation/bloc_or_provider/home_cubit.dart';
import 'presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();

  final LocalDbDataSource localDbDataSource = LocalDbDataSourceImpl(sharedPreferences);
  final GoogleSheetsDataSource googleSheetsDataSource = GoogleSheetsDataSourceImpl();
  final GoogleCalendarApi googleCalendarApi = GoogleCalendarApiImpl(); // ללא קונסטרקטור קשיח

  final ClientRepository clientRepository = ClientRepositoryImpl(googleSheetsDataSource: googleSheetsDataSource, localDbDataSource: localDbDataSource);

  final EventRepository eventRepository = EventRepositoryImpl(googleSheetsDataSource: googleSheetsDataSource, localDbDataSource: localDbDataSource, googleCalendarApi: googleCalendarApi);

  final CalculateDailyEventsUseCase calculateDailyEventsUseCase = CalculateDailyEventsUseCase();

  final HomeCubit homeCubit = HomeCubit(clientRepository: clientRepository, eventRepository: eventRepository, calculateDailyEventsUseCase: calculateDailyEventsUseCase);

  runApp(MainApp(homeCubit: homeCubit, googleSheetsDataSource: googleSheetsDataSource, googleCalendarApi: googleCalendarApi));
}

class MainApp extends StatelessWidget {
  final HomeCubit homeCubit;
  final GoogleSheetsDataSource googleSheetsDataSource;
  final GoogleCalendarApi googleCalendarApi;

  const MainApp({super.key, required this.homeCubit, required this.googleSheetsDataSource, required this.googleCalendarApi});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'מערכת ברכות נדל"ן',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primaryColor: const Color(0xFF8B7355), scaffoldBackgroundColor: const Color(0xFFF8F9FA), fontFamily: 'Assistant'),
      home: HomePage(cubit: homeCubit, googleSheetsDataSource: googleSheetsDataSource, googleCalendarApi: googleCalendarApi),
    );
  }
}

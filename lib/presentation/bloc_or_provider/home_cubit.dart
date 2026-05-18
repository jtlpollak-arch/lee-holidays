import 'package:meta/meta.dart';
import '../../data/models/client_model.dart';
import '../../data/models/event_model.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../domain/usecases/calculate_daily_events_usecase.dart';

/// הגדרת כל המצבים האפשריים של מסך הבית
@immutable
abstract class HomeState {
  const HomeState();
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeSuccess extends HomeState {
  final List<DailyEventResult> dailyEvents;
  final List<ClientModel> allClients;

  const HomeSuccess({required this.dailyEvents, required this.allClients});
}

class HomeFailure extends HomeState {
  final String errorMessage;

  const HomeFailure(this.errorMessage);
}

/// ה-Cubit שמנהל את הלוגיקה והמצב של מסך הבית
class HomeCubit {
  final ClientRepository _clientRepository;
  final EventRepository _eventRepository;
  final CalculateDailyEventsUseCase _calculateDailyEventsUseCase;

  // משתנה פנימי להחזקת המצב הנוכחי (מדמה את התנהגות Bloc)
  HomeState _state = const HomeInitial();
  HomeState get state => _state;

  // פונקציית קולבק המאפשרת ל-UI להאזין לשינויי הסטייט
  void Function(HomeState state)? _onStateChanged;

  HomeCubit({required ClientRepository clientRepository, required EventRepository eventRepository, required CalculateDailyEventsUseCase calculateDailyEventsUseCase}) : _clientRepository = clientRepository, _eventRepository = eventRepository, _calculateDailyEventsUseCase = calculateDailyEventsUseCase;

  /// הרשמה להאזנה לשינויי הסטייט מה-UI
  void listen(void Function(HomeState state) onStateChanged) {
    _onStateChanged = onStateChanged;
  }

  /// פונקציה פנימית לעדכון הסטייט והרצת הקולבק
  void _emit(HomeState newState) {
    _state = newState;
    if (_onStateChanged != null) {
      _onStateChanged!(_state);
    }
  }

  /// הפעולה המרכזית: טעינה, מיזוג ופילוח של אירועי היום מהענן והמכשיר
  Future<void> loadDailyOverview({required String spreadsheetId}) async {
    _emit(const HomeLoading());

    try {
      // 1. הבאת הלקוחות מה-Repository (ענן + גיבוי Offline מקומי)
      final List<ClientModel> clients = await _clientRepository.getAllClients(spreadsheetId);

      // 2. הבאת האירועים מה-Repository (כולל ביצוע המיזוג האוטומטי החכם - גישה 2)
      final List<EventModel> events = await _eventRepository.getAllEvents(spreadsheetId);

      // 3. הרצת ה-Use Case החכם שמחשב את אירועי היום והקדמות השבת/חג
      final List<DailyEventResult> dailyEvents = _calculateDailyEventsUseCase.execute(allClients: clients, allEvents: events, today: DateTime.now());

      // 4. עדכון המסך בהצלחה עם הנתונים המעובדים
      _emit(HomeSuccess(dailyEvents: dailyEvents, allClients: clients));
    } catch (e) {
      // עדכון הסטייט בשגיאה במקרה של בעיה חמורה (כמו חוסר בהרשאות גוגל)
      _emit(HomeFailure('נכשלה טעינת הנתונים: ${e.toString()}'));
    }
  }
}

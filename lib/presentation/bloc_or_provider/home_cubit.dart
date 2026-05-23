import 'package:meta/meta.dart';
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

  const HomeSuccess({required this.dailyEvents});
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

  // רשימת מאזינים לשינויי מצב
  final List<void Function(HomeState)> _listeners = [];

  HomeCubit({required ClientRepository clientRepository, required EventRepository eventRepository, required CalculateDailyEventsUseCase calculateDailyEventsUseCase}) : _clientRepository = clientRepository, _eventRepository = eventRepository, _calculateDailyEventsUseCase = calculateDailyEventsUseCase;

  void listen(void Function(HomeState) listener) {
    _listeners.add(listener);
    listener(_state);
  }

  void _emit(HomeState newState) {
    _state = newState;
    for (var listener in _listeners) {
      listener(_state);
    }
  }

  /// טעינת סקירת המשימות היומית ורשימת הלקוחות המלאה מהענן/Cache
  /// תומך בפרמטר [forceRefresh] כדי לאפשר דריסה מוחלטת של ה-Cache הלוקלי עם עליית האפליקציה
  Future<void> loadDailyOverview({required String spreadsheetId, bool forceRefresh = false}) async {
    _emit(const HomeLoading());
    try {
      // משיכת הנתונים הגולמיים במקביל משני המקורות עם העברת דגל הרענון
      final clients = await _clientRepository.getAllClients(spreadsheetId, forceRefresh: forceRefresh);
      final events = await _eventRepository.getAllEvents(spreadsheetId, forceRefresh: forceRefresh);

      // תיקון שורה 72: התאמה מדויקת לשמות הפרמטרים והעברת DateTime.now() לפרמטר today כמצופה ב-Use Case שלך
      final dailyResults = _calculateDailyEventsUseCase.execute(allClients: clients, allEvents: events, today: DateTime.now());

      // עדכון המצב ל-Success עם הנתונים המחושבים כפי שמוגדר במקור אצלך
      _emit(HomeSuccess(dailyEvents: dailyResults));
    } catch (e) {
      _emit(HomeFailure('שגיאה בטעינת סקירת המשימות: ${e.toString()}'));
    }
  }

  /// סימון אירוע כנשלח באמצעות עדכון חותמת הזמן הנוכחית
  Future<void> markEventAsSent({required String spreadsheetId, required EventModel event}) async {
    try {
      final String currentTimestamp = DateTime.now().toIso8601String();
      final updatedEvent = event.copyWith(sentTimestamp: currentTimestamp);
      await _eventRepository.updateEvent(spreadsheetId, updatedEvent);
      await loadDailyOverview(spreadsheetId: spreadsheetId);
    } catch (e) {
      _emit(HomeFailure('שגיאה בסימון האירוע כנשלח: ${e.toString()}'));
    }
  }

  /// ביטול סימון השליחה והחייאת האירוע על ידי ריקון חותמת הזמן
  Future<void> cancelEventSentStatus({required String spreadsheetId, required EventModel event}) async {
    try {
      final updatedEvent = event.copyWith(sentTimestamp: '');
      await _eventRepository.updateEvent(spreadsheetId, updatedEvent);
      await loadDailyOverview(spreadsheetId: spreadsheetId);
    } catch (e) {
      _emit(HomeFailure('שגיאה בביטול סימון השליחה: ${e.toString()}'));
    }
  }

  /// מחיקה לוגית (הקפאה) של אירוע
  Future<void> deleteEvent({required String spreadsheetId, required EventModel event}) async {
    try {
      await _eventRepository.deleteEventSoft(spreadsheetId, event);
      await loadDailyOverview(spreadsheetId: spreadsheetId);
    } catch (e) {
      _emit(HomeFailure('שגיאה במחיקת האירוע: ${e.toString()}'));
    }
  }

  /// שחזור אירוע שנמחק לוגית
  Future<void> restoreEvent({required String spreadsheetId, required EventModel event}) async {
    try {
      // תיקון שורה 118: עדכון הסטטוס ל-'פעיל' ב-copyWith, בהתאמה למבנה שדות הסטטוס במערכת שלך
      final restoredEvent = event.copyWith(status: 'פעיל');
      await _eventRepository.updateEvent(spreadsheetId, restoredEvent);
      await loadDailyOverview(spreadsheetId: spreadsheetId);
    } catch (e) {
      _emit(HomeFailure('שגיאה בשחזור האירוע: ${e.toString()}'));
    }
  }
}

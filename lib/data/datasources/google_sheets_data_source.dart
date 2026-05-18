import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import '../models/client_model.dart';
import '../models/event_model.dart';

abstract class GoogleSheetsDataSource {
  Future<List<ClientModel>> getClients(String spreadsheetId);
  Future<void> appendClient(String spreadsheetId, ClientModel client);
  Future<List<EventModel>> getEvents(String spreadsheetId);
  Future<void> appendEvent(String spreadsheetId, EventModel event);

  // פונקציית הזרקה בשביל לעדכן את הטוקן המאומת של לי לאחר התחברות
  void updateAuthenticatedClient(http.Client client);
}

class GoogleSheetsDataSourceImpl implements GoogleSheetsDataSource {
  http.Client? _authenticatedClient;

  @override
  void updateAuthenticatedClient(http.Client client) {
    _authenticatedClient = client;
  }

  // אם המשתמש מחובר נשתמש בלקוח המאומת, אחרת בלקוח רגיל
  http.Client get _effectiveClient => _authenticatedClient ?? http.Client();

  @override
  Future<List<ClientModel>> getClients(String spreadsheetId) async {
    try {
      final sheetsApi = sheets.SheetsApi(_effectiveClient);
      const String range = 'Sheet1!A2:D'; // קריאת עמודות לקוח

      final response = await sheetsApi.spreadsheets.values.get(spreadsheetId, range);
      final List<List<dynamic>>? rows = response.values;

      if (rows == null || rows.isEmpty) {
        return [];
      }

      return rows.map((row) => ClientModel.fromSheetsRow(row)).toList();
    } catch (e) {
      print('שגיאה במשיכת לקוחות מגוגל שיטס: $e');
      return [];
    }
  }

  @override
  Future<void> appendClient(String spreadsheetId, ClientModel client) async {
    try {
      final sheetsApi = sheets.SheetsApi(_effectiveClient);
      const String range = 'Sheet1!A1';

      final valueRange = sheets.ValueRange(values: [client.toSheetsRow()]);

      await sheetsApi.spreadsheets.values.append(valueRange, spreadsheetId, range, valueInputOption: 'USER_ENTERED');
    } catch (e) {
      print('שגיאה בהוספת לקוח לגוגל שיטס: $e');
    }
  }

  @override
  Future<List<EventModel>> getEvents(String spreadsheetId) async {
    try {
      final sheetsApi = sheets.SheetsApi(_effectiveClient);
      const String range = 'Events!A2:D'; // קריאת עמודות אירוע מטאב Events

      final response = await sheetsApi.spreadsheets.values.get(spreadsheetId, range);
      final List<List<dynamic>>? rows = response.values;

      if (rows == null || rows.isEmpty) {
        return [];
      }

      return rows.map((row) => EventModel.fromSheetsRow(row)).toList();
    } catch (e) {
      print('שגיאה במשיכת אירועים מגוגל שיטס: $e');
      return [];
    }
  }

  @override
  Future<void> appendEvent(String spreadsheetId, EventModel event) async {
    try {
      final sheetsApi = sheets.SheetsApi(_effectiveClient);
      const String range = 'Events!A1';

      final valueRange = sheets.ValueRange(values: [event.toSheetsRow()]);

      await sheetsApi.spreadsheets.values.append(valueRange, spreadsheetId, range, valueInputOption: 'USER_ENTERED');
    } catch (e) {
      print('שגיאה בהוספת אירוע לגוגל שיטס: $e');
    }
  }
}

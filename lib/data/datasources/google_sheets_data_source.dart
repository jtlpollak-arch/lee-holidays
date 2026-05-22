import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import '../models/client_model.dart';
import '../models/event_model.dart';

abstract class GoogleSheetsDataSource {
  void updateAuthenticatedClient(http.Client client);
  Future<List<ClientModel>> getClients(String spreadsheetId);
  Future<void> appendClient(String spreadsheetId, ClientModel client);
  Future<void> updateClientRow(String spreadsheetId, int rowIndex, ClientModel client);

  Future<List<EventModel>> getEvents(String spreadsheetId);
  Future<void> appendEvent(String spreadsheetId, EventModel event);
  Future<void> updateEventRow(String spreadsheetId, int rowIndex, EventModel event);
}

class GoogleSheetsDataSourceImpl implements GoogleSheetsDataSource {
  http.Client? _authenticatedClient;

  GoogleSheetsDataSourceImpl([this._authenticatedClient]);

  @override
  void updateAuthenticatedClient(http.Client client) {
    _authenticatedClient = client;
  }

  sheets.SheetsApi _getSheetsApi() {
    if (_authenticatedClient == null) {
      throw StateError('ה-Authenticated Client לא אותחל ב-DataSource.');
    }
    return sheets.SheetsApi(_authenticatedClient!);
  }

  // ==========================================
  // לוגיקת לקוחות (Sheet1) - מורחב ל-6 עמודות: A עד F
  // ==========================================

  @override
  Future<List<ClientModel>> getClients(String spreadsheetId) async {
    final sheetsApi = _getSheetsApi();
    try {
      // הטווח עודכן מ-E ל-F כדי לקרוא את כל 6 העמודות (כולל ה-id החדש בטור A)
      final response = await sheetsApi.spreadsheets.values.get(spreadsheetId, 'Sheet1!A2:F5000');
      final List<ClientModel> clients = [];

      if (response.values != null) {
        for (var row in response.values!) {
          if (row.isNotEmpty && row[0].toString().trim().isNotEmpty) {
            clients.add(ClientModel.fromRow(row));
          }
        }
      }
      return clients;
    } catch (e) {
      print('שגיאה במשיכת לקוחות מגוגל שיטס: $e');
      return [];
    }
  }

  @override
  Future<void> appendClient(String spreadsheetId, ClientModel client) async {
    final sheetsApi = _getSheetsApi();
    final valueRange = sheets.ValueRange(values: [client.toRow()]);
    try {
      // הטווח עודכן ל-F כדי לתמוך בשמירת 6 העמודות בענן
      await sheetsApi.spreadsheets.values.append(valueRange, spreadsheetId, 'Sheet1!A:F', valueInputOption: 'USER_ENTERED');
    } catch (e) {
      print('שגיאה בהוספת לקוח חדש לגוגל שיטס: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateClientRow(String spreadsheetId, int rowIndex, ClientModel client) async {
    final sheetsApi = _getSheetsApi();
    final valueRange = sheets.ValueRange(values: [client.toRow()]);
    try {
      // הטווח עודכן ל-F לעדכון שורה מלאה בענן
      await sheetsApi.spreadsheets.values.update(valueRange, spreadsheetId, 'Sheet1!A$rowIndex:F$rowIndex', valueInputOption: 'USER_ENTERED');
    } catch (e) {
      print('שגיאה בעדכון שורת לקוח בגוגל שיטס: $e');
      rethrow;
    }
  }

  // ==========================================
  // לוגיקת אירועים (Events) - נשארת 8 עמודות: A עד H (ללא שינוי טווחים)
  // ==========================================

  @override
  Future<List<EventModel>> getEvents(String spreadsheetId) async {
    final sheetsApi = _getSheetsApi();
    try {
      final response = await sheetsApi.spreadsheets.values.get(spreadsheetId, 'Events!A2:H5000');
      final List<EventModel> events = [];

      if (response.values != null) {
        for (var row in response.values!) {
          if (row.isNotEmpty && row[0].toString().trim().isNotEmpty) {
            events.add(EventModel.fromRow(row));
          }
        }
      }
      return events;
    } catch (e) {
      print('שגיאה במשיכת אירועים מגוגל שיטס: $e');
      return [];
    }
  }

  @override
  Future<void> appendEvent(String spreadsheetId, EventModel event) async {
    final sheetsApi = _getSheetsApi();
    final valueRange = sheets.ValueRange(values: [event.toRow()]);
    try {
      await sheetsApi.spreadsheets.values.append(valueRange, spreadsheetId, 'Events!A:H', valueInputOption: 'USER_ENTERED');
    } catch (e) {
      print('שגיאה בהוספת אירוע חדש לגוגל שיטס: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateEventRow(String spreadsheetId, int rowIndex, EventModel event) async {
    final sheetsApi = _getSheetsApi();
    final valueRange = sheets.ValueRange(values: [event.toRow()]);
    try {
      await sheetsApi.spreadsheets.values.update(valueRange, spreadsheetId, 'Events!A$rowIndex:I$rowIndex', valueInputOption: 'USER_ENTERED');
    } catch (e) {
      print('שגיאה בעדכון שורת אירוע בגוגל שיטס: $e');
      rethrow;
    }
  }
}

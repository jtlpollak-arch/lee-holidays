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

  /// הצהרה ב-Interface המאפשרת ל-Repositories להפעיל את מחיקת ה-Batch המרוכזת
  Future<void> deleteRowsBatch(String spreadsheetId, String sheetName, List<int> rowNumbers);
  Future<void> updateValuesBatch(String spreadsheetId, List<sheets.ValueRange> data);
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
      final response = await sheetsApi.spreadsheets.values.get(spreadsheetId, 'Sheet1!A2:G5000');
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
      await sheetsApi.spreadsheets.values.append(valueRange, spreadsheetId, 'Sheet1!A:G', valueInputOption: 'USER_ENTERED');
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
      await sheetsApi.spreadsheets.values.update(valueRange, spreadsheetId, 'Sheet1!A$rowIndex:G$rowIndex', valueInputOption: 'USER_ENTERED');
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
      final response = await sheetsApi.spreadsheets.values.get(spreadsheetId, 'Events!A2:I1000');
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
      await sheetsApi.spreadsheets.values.append(valueRange, spreadsheetId, 'Events!A:I', valueInputOption: 'USER_ENTERED');
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

  @override
  Future<void> deleteRowsBatch(String spreadsheetId, String sheetName, List<int> rowNumbers) async {
    if (rowNumbers.isEmpty) return;

    print('GoogleSheetsDataSource: מתחיל בניית בקשת Batch למחיקת ${rowNumbers.length} שורות מהגיליון "$sheetName"...');

    final sheetsApi = _getSheetsApi();

    try {
      // 1. שלב ראשון: משיכת מזהה הגיליון הפנימי (sheetId) של הטאב הספציפי על פי השם שלו
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);

      // תיקון יציבות: התאמה מדויקת וגמישה לשמות הטאבים הפיזיים שלך בענן (כולל אותיות גדולות/קטנות)
      final sheet = spreadsheet.sheets?.firstWhere((s) {
        final title = s.properties?.title;
        if (sheetName == 'clients' && title == 'Sheet1') return true;
        if (sheetName == 'events' && title == 'Events') return true; // תיקון הנתק: התאמה ל-'Events' עם E גדולה
        return title == sheetName;
      }, orElse: () => throw Exception('הגיליון "$sheetName" לא נמצא בתוך ה-Spreadsheet'));

      final int? sheetId = sheet?.properties?.sheetId;
      if (sheetId == null) {
        throw Exception('לא ניתן היה לאחזר את ה-sheetId עבור הגיליון "$sheetName"');
      }

      // 2. שלב שני: בניית רשימת בקשות המחיקה הפיזיות
      final List<sheets.Request> requests = rowNumbers.map((rowNumber) {
        return sheets.Request(
          deleteDimension: sheets.DeleteDimensionRequest(
            range: sheets.DimensionRange(
              sheetId: sheetId,
              dimension: 'ROWS',
              startIndex: rowNumber - 1, // המרה ל-0-based index (כולל)
              endIndex: rowNumber, // הגבול העליון פתוח (לא כולל)
            ),
          ),
        );
      }).toList();

      // 3. שלב שלישי: אריזת הבקשות לתוך BatchUpdateSpreadsheetRequest ושליחתן במכה אחת לענן
      final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest(requests: requests);

      await sheetsApi.spreadsheets.batchUpdate(batchUpdateRequest, spreadsheetId);

      print('GoogleSheetsDataSource: פקודת ה-Batch בוצעה בהצלחה! השורות נמחקו והגיליון צומצם.');
    } catch (e) {
      print('שגיאה בביצוע deleteRowsBatch ב-Google Sheets: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateValuesBatch(String spreadsheetId, List<sheets.ValueRange> data) async {
    if (data.isEmpty) return;

    print('CbvSheetsBatch: מתחיל עדכון ערכים מרוכז (Batch Update) עבור ${data.length} טווחים...');

    final sheets.SheetsApi sheetsApi = _getSheetsApi();

    // אריזת כל הטווחים והערכים לתוך בקשת ה-Batch המובנית של גוגל שיטס
    final batchUpdateRequest = sheets.BatchUpdateValuesRequest(valueInputOption: 'USER_ENTERED', data: data);

    try {
      await sheetsApi.spreadsheets.values.batchUpdate(batchUpdateRequest, spreadsheetId);
      print('CbvSheetsBatch: עדכון ה-Batch של הערכים בוצע בהצלחה מול Google Sheets.');
    } catch (e) {
      print('CbvSheetsBatch: שגיאה במהלך ביצוע batchUpdate של ערכים: $e');
      throw Exception('נכשל עדכון ערכים מרוכז ב-Google Sheets: $e');
    }
  }
}

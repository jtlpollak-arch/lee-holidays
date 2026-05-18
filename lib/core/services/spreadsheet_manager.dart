import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SpreadsheetManager {
  static const String _fileName = "מערכת הברכות של לי - מאגר נתונים";
  static const String _prefsKey = "google_spreadsheet_id";

  Future<String> getOrCreateSpreadsheet(http.Client client) async {
    final prefs = await SharedPreferences.getInstance();

    String? savedId = prefs.getString(_prefsKey);
    if (savedId != null && savedId.isNotEmpty) {
      return savedId;
    }

    final driveApi = drive.DriveApi(client);
    final query = "name = '$_fileName' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false";

    final fileList = await driveApi.files.list(q: query, spaces: 'drive', $fields: 'files(id, name)');

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final existingId = fileList.files!.first.id!;
      await prefs.setString(_prefsKey, existingId);
      return existingId;
    }

    final sheetsApi = sheets.SheetsApi(client);

    // יצירת קובץ עם שני טאבים: Sheet1 ללקוחות, ו-Events לאירועים
    final newSpreadsheet = sheets.Spreadsheet(
      properties: sheets.SpreadsheetProperties(title: _fileName),
      sheets: [
        sheets.Sheet(properties: sheets.SheetProperties(title: 'Sheet1')),
        sheets.Sheet(properties: sheets.SheetProperties(title: 'Events')),
      ],
    );

    final createdSheet = await sheetsApi.spreadsheets.create(newSpreadsheet);
    final String newId = createdSheet.spreadsheetId!;

    // כותרות ללקוחות
    await sheetsApi.spreadsheets.values.update(
      sheets.ValueRange(
        values: [
          ['מזהה', 'שם מלא', 'שם פרטי', 'טלפון'],
        ],
      ),
      newId,
      'Sheet1!A1:D1',
      valueInputOption: 'USER_ENTERED',
    );

    // כותרות לאירועים
    await sheetsApi.spreadsheets.values.update(
      sheets.ValueRange(
        values: [
          ['מזהה לקוח', 'תאריך אירוע', 'סוג אירוע', 'הערות'],
        ],
      ),
      newId,
      'Events!A1:D1',
      valueInputOption: 'USER_ENTERED',
    );

    await prefs.setString(_prefsKey, newId);
    return newId;
  }
}

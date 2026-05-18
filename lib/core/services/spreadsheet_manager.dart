import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SpreadsheetManager {
  static const String _fileName = "מערכת הברכות של לי - מאגר נתונים";
  static const String _prefsKey = "google_spreadsheet_id";

  Future<String> getOrCreateSpreadsheet(http.Client client) async {
    final prefs = await SharedPreferences.getInstance();
    final driveApi = drive.DriveApi(client);
    final sheetsApi = sheets.SheetsApi(client);

    String? savedId = prefs.getString(_prefsKey);

    // בדיקה האם המזהה השמור בזיכרון באמת קיים ותקין בענן
    if (savedId != null && savedId.isNotEmpty) {
      try {
        await sheetsApi.spreadsheets.get(savedId);
        print('נמצא קובץ תקין בזיכרון המקומי: $savedId');
        return savedId;
      } catch (e) {
        print('הקובץ השמור בזיכרון כבר לא תקף או נמצא באשפה. ננקה ונחפש מחדש.');
        await prefs.remove(_prefsKey);
      }
    }

    // חיפוש קפדני בדרייב, תוך התעלמות מוחלטת מקבצים שנמחקו
    final query = "name = '$_fileName' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false";

    try {
      final fileList = await driveApi.files.list(q: query, spaces: 'drive', $fields: 'files(id, name, trashed)');

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // סינון נוסף בקוד לביטחון מקסימלי מפני קבצי אשפה
        final validFile = fileList.files!.firstWhere((f) => f.trashed == false && f.id != null, orElse: () => drive.File());

        if (validFile.id != null) {
          final existingId = validFile.id!;
          print('נמצא קובץ קיים ותקין בענן גוגל דרייב: $existingId');
          await prefs.setString(_prefsKey, existingId);
          return existingId;
        }
      }
    } catch (e) {
      print('שגיאה במהלך חיפוש קובץ קיים: $e');
    }

    // שלב היצירה של קובץ חדש לחלוטין
    print('מייצר קובץ נתונים חדש לגמרי בענן בשם: $_fileName');

    final newSpreadsheet = sheets.Spreadsheet(
      properties: sheets.SpreadsheetProperties(title: _fileName),
      sheets: [
        sheets.Sheet(properties: sheets.SheetProperties(title: 'Sheet1')),
        sheets.Sheet(properties: sheets.SheetProperties(title: 'Events')),
      ],
    );

    final createdSheet = await sheetsApi.spreadsheets.create(newSpreadsheet);
    final String newId = createdSheet.spreadsheetId!;

    // כותרות ללשונית הלקוחות
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

    // כותרות ללשונית האירועים
    await sheetsApi.spreadsheets.values.update(
      sheets.ValueRange(
        values: [
          ['מזהה לקוח', 'תאריך', 'סוג אירוע', 'הערות'],
        ],
      ),
      newId,
      'Events!A1:D1',
      valueInputOption: 'USER_ENTERED',
    );

    // שמירת המזהה החדש בזיכרון המכשיר
    await prefs.setString(_prefsKey, newId);
    print('הקובץ החדש נוצר ואותחל בהצלחה! מזהה: $newId');

    return newId;
  }
}

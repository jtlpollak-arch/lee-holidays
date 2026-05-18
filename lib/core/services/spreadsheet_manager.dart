import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SpreadsheetManager {
  static const String _fileName = "מערכת הברכות של לי - מאגר נתונים";
  static const String _prefsKey = "google_spreadsheet_id";

  // מפתחות ה-Cache המקומיים של הלקוחות והאירועים לצורך ניקוי בעת הצורך
  static const String _clientsCacheKey = 'cached_clients_json';
  static const String _eventsCacheKey = 'cached_events_json';

  // משתנה סטטי ברמת המחלקה שחוסם יצירה מקבילה של קבצים בכל האפליקציה
  static Future<String>? _currentSetupFuture;

  Future<String> getOrCreateSpreadsheet(http.Client client) async {
    // אם כבר רץ תהליך איתור או יצירה של קובץ ברגע זה, כל הקריאות האחרות
    // ימתינו לאותו ה-Future המקורי ולא יבצעו קריאות כפולות מול גוגל
    if (_currentSetupFuture != null) {
      print('זיהיתי קריאה מקבילה לאיתור קובץ. מפנה את הקריאה להמתין לתהליך שכבר רץ...');
      return _currentSetupFuture!;
    }

    // הגדרת ה-Future המרכזי
    _currentSetupFuture = _executeGetOrCreate(client);

    try {
      final String resultId = await _currentSetupFuture!;
      return resultId;
    } finally {
      // בסיום התהליך (הצלחה או שגיאה), נפתח את החסימה לקריאות עתידיות
      _currentSetupFuture = null;
    }
  }

  Future<String> _executeGetOrCreate(http.Client client) async {
    final prefs = await SharedPreferences.getInstance();
    final driveApi = drive.DriveApi(client);
    final sheetsApi = sheets.SheetsApi(client);

    String? savedId = prefs.getString(_prefsKey);

    if (savedId != null && savedId.isNotEmpty) {
      try {
        await sheetsApi.spreadsheets.get(savedId);
        print('נמצא קובץ תקין בזיכרון המקומי: $savedId');
        return savedId;
      } catch (e) {
        print('הקובץ השמור בזיכרון כבר לא תקף או נמצא באשפה. ננקה ונחפש מחדש.');
        await prefs.remove(_prefsKey);
        // אם הקובץ הישן נמחק, ננקה גם את ה-Cache המקומי כדי שלא יציג נתוני רפאים
        await prefs.remove(_clientsCacheKey);
        await prefs.remove(_eventsCacheKey);
      }
    }

    final query = "name = '$_fileName' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false";

    try {
      final fileList = await driveApi.files.list(q: query, spaces: 'drive', $fields: 'files(id, name, trashed)');

      if (fileList.files != null && fileList.files!.isNotEmpty) {
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

    print('מייצר קובץ נתונים חדש לגמרי בענן בשם: $_fileName');

    // ברגע שמייצרים קובץ חדש מאפס, חובה לנקות את הזיכרון המקומי הישן של הלקוחות והאירועים
    await prefs.remove(_clientsCacheKey);
    await prefs.remove(_eventsCacheKey);
    print('ה-Cache המקומי של הלקוחות והאירועים אופס בהצלחה.');

    final newSpreadsheet = sheets.Spreadsheet(
      properties: sheets.SpreadsheetProperties(title: _fileName),
      sheets: [
        sheets.Sheet(properties: sheets.SheetProperties(title: 'Sheet1')),
        sheets.Sheet(properties: sheets.SheetProperties(title: 'Events')),
      ],
    );

    final createdSheet = await sheetsApi.spreadsheets.create(newSpreadsheet);
    final String newId = createdSheet.spreadsheetId!;

    // כותרות מעודכנות ללשונית הלקוחות (הורדנו את כתובת הנכס מפה)
    await sheetsApi.spreadsheets.values.update(
      sheets.ValueRange(
        values: [
          ['מזהה', 'שם מלא', 'שם פרטי', 'טלפון', 'אימייל', 'סטטוס'],
        ],
      ),
      newId,
      'Sheet1!A1:F1',
      valueInputOption: 'USER_ENTERED',
    );

    // כותרות מורחבות ומעודכנות ללשונית האירועים (הוספנו את כתובת הנכס כאן בטור D)
    await sheetsApi.spreadsheets.values.update(
      sheets.ValueRange(
        values: [
          ['מזהה לקוח', 'תאריך', 'סוג אירוע', 'כתובת נכס / אזור', 'הערות', 'סטטוס'],
        ],
      ),
      newId,
      'Events!A1:F1',
      valueInputOption: 'USER_ENTERED',
    );

    await prefs.setString(_prefsKey, newId);
    print('הקובץ החדש נוצר, פולח ואותחל בהצלחה! מזהה: $newId');

    return newId;
  }
}

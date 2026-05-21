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

  // משתנה סטטי ברמת המחלקה שחוסם ומאחד את כל תהליך הבדיקה והיצירה ברחבי האפליקציה
  static Future<String>? _currentSetupFuture;

  Future<String> getOrCreateSpreadsheet(http.Client client) async {
    // אם כבר רץ תהליך אתחול, איתור או יצירה של קובץ ברגע זה, כל שאר הקריאות
    // ימתינו לאותו ה-Future המקורי ולא יבצעו שום בדיקה או קריאה מקבילה מול גוגל
    if (_currentSetupFuture != null) {
      print('זיהיתי קריאה מקבילה לאתחול מערך הנתונים. מפנה את הרכיב להמתין לתהליך שכבר רץ...');
      return _currentSetupFuture!;
    }

    // עטיפת כל התהליך (מבדיקת הזיכרון המקומי ועד החיפוש והיצירה בענן) תחת ה-Future הסטטי המשותף
    _currentSetupFuture = _executeSynchronizedSetup(client);

    try {
      final resultId = await _currentSetupFuture!;
      return resultId;
    } finally {
      // בסיום מוחלט של התהליך (הצלחה או שגיאה), נאפס את המשתנה הסטטי כדי לאפשר קריאות עתידיות במידת הצורך
      _currentSetupFuture = null;
    }
  }

  /// הלוגיקה הפנימית המוגנת שמבוצעת בצורה טורית ומסונכרנת עבור כל רכיבי האפליקציה
  Future<String> _executeSynchronizedSetup(http.Client client) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? cachedId = prefs.getString(_prefsKey);

    if (cachedId != null && cachedId.isNotEmpty) {
      final driveApi = drive.DriveApi(client);
      try {
        print('נמצא מזהה קובץ שמור בזיכרון המקומי ($cachedId). מverify שהוא פעיל בענן...');
        // בדיקה אקטיבית מול גוגל דרייב שהקובץ אכן קיים ואינו נמצא באשפה
        await driveApi.files.get(cachedId, $fields: 'id, trashed');
        print('הקובץ השמור אומת בהצלחה ונמצא תקין ופעיל.');
        return cachedId;
      } catch (e) {
        print('הקובץ השמור לא נמצא או נמחק ידנית מהענן ($e). מנקה את ה-Cache המקומי ומתכונן לאיתור או יצירה...');
        // מחיקת כל הזיכרון הישן וה-Cache מהמכשיר כדי לרוקן את המסכים באופן מיידי
        await prefs.remove(_prefsKey);
        await prefs.remove(_clientsCacheKey);
        await prefs.remove(_eventsCacheKey);
      }
    }

    final driveApi = drive.DriveApi(client);
    final sheetsApi = sheets.SheetsApi(client);

    print('מחפש קובץ קיים בדרייב בשם: "$_fileName"...');
    final fileList = await driveApi.files.list(q: "name = '$_fileName' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false", spaces: 'drive', pageSize: 1);

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final String existingId = fileList.files!.first.id!;
      print('נמצא קובץ נתונים קיים בדרייב! מזהה קובץ: $existingId. מעדכן את הזיכרון המקומי.');
      await prefs.setString(_prefsKey, existingId);
      return existingId;
    }

    print('לא נמצא קובץ תואם בענן. מייצר קובץ Google Sheets חדש ומגדיר את מבנה העמודות המעודכן...');

    // ניקוי ביטחוני נוסף של זיכרון המטמון המקומי לקראת התחלת עבודה עם קובץ חדש לחלוטין
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

    // כותרות מעודכנות ללשונית הלקוחות - מספר הטלפון מחליף לחלוטין את המזהה הרץ והופך לטור הראשי
    await sheetsApi.spreadsheets.values.update(
      sheets.ValueRange(
        values: [
          ['cl_id', 'טלפון', 'שם מלא', 'שם פרטי', 'אימייל', 'סטטוס'],
        ],
      ),
      newId,
      'Sheet1!A1:F1',
      valueInputOption: 'USER_ENTERED',
    );

    // כותרות מעודכנות ללשונית האירועים - הקישור נעשה באמצעות טלפון לקוח במקום מזהה מספרי
    await sheetsApi.spreadsheets.values.update(
      sheets.ValueRange(
        values: [
          ['ev_id', 'cl_id', 'תאריך אירוע', 'סוג אירוע', 'כתובת נכס', 'הערות', 'סטטוס', 'חותמת זמן'],
        ],
      ),
      newId,
      'Events!A1:H1',
      valueInputOption: 'USER_ENTERED',
    );

    print('הקובץ החדש נוצר והמבנה עודכן בהצלחה מול גוגל שיטס. מזהה: $newId');
    await prefs.setString(_prefsKey, newId);
    return newId;
  }

  Future<void> clearLocalCachedSpreadsheetId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_clientsCacheKey);
    await prefs.remove(_eventsCacheKey);
    print('מזהה הגיליון וה-Cache של הנתונים נמחקו מה-SharedPreferences בהצלחה.');
  }
}

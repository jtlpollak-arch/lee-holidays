import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis/drive/v3.dart' as drive;

class AuthService {
  // הווספנו את drive.fileScope כדי לאפשר חיפוש ויצירת הקובץ אוטומטית
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      sheets.SheetsApi.spreadsheetsScope,
      calendar.CalendarApi.calendarScope,
      drive.DriveApi.driveFileScope, // הרשאה ייעודית לניהול קבצים שהאפליקציה יוצרת
    ],
  );

  GoogleSignInAccount? _currentUser;

  Stream<GoogleSignInAccount?> get onCurrentUserChanged => _googleSignIn.onCurrentUserChanged;
  GoogleSignInAccount? get currentUser => _currentUser;

  Future<GoogleSignInAccount?> signInSilently() async {
    _currentUser = await _googleSignIn.signInSilently();
    return _currentUser;
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (error) {
      print('שגיאה במהלך התחברות לגוגל: $error');
      rethrow;
    }
  }

  Future<GoogleSignInAccount?> signOut() async {
    _currentUser = await _googleSignIn.signOut();
    return _currentUser;
  }

  Future<http.Client?> getAuthenticatedClient() async {
    if (_currentUser == null) return null;
    final Map<String, String> authHeaders = await _currentUser!.authHeaders;
    return AuthenticatedClient(authHeaders);
  }
}

class AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _innerClient = http.Client();

  AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _innerClient.send(request);
  }
}

import '../datasources/google_sheets_data_source.dart';
import '../datasources/local_db_data_source.dart';
import '../models/client_model.dart';

abstract class ClientRepository {
  Future<List<ClientModel>> getAllClients(String spreadsheetId);
  Future<void> addNewClient(String spreadsheetId, ClientModel client);
}

class ClientRepositoryImpl implements ClientRepository {
  final GoogleSheetsDataSource googleSheetsDataSource;
  final LocalDbDataSource localDbDataSource;

  ClientRepositoryImpl({required this.googleSheetsDataSource, required this.localDbDataSource});

  @override
  Future<List<ClientModel>> getAllClients(String spreadsheetId) async {
    try {
      // משיכת הלקוחות אך ורק מהענן האמיתי בגוגל שיטס
      final List<ClientModel> cloudClients = await googleSheetsDataSource.getClients(spreadsheetId);

      // עדכון ה-Cache המקומי במידע האמיתי מהענן (גם אם הענן ריק - נשמור רשימה ריקה)
      await localDbDataSource.saveClients(cloudClients);
      return cloudClients;
    } catch (e) {
      print('שגיאה במשיכת לקוחות מהענן ב-ClientRepository: $e');
      // במקרה של שגיאת תקשורת חמורה בלבד, נחזור למה ששמור מקומית כדי למנוע קריסה
      return await localDbDataSource.getClients();
    }
  }

  @override
  Future<void> addNewClient(String spreadsheetId, ClientModel client) async {
    try {
      // שמירה מקומית של הלקוח החדש
      final List<ClientModel> currentLocal = await localDbDataSource.getClients();
      currentLocal.add(client);
      await localDbDataSource.saveClients(currentLocal);

      // כתיבה ישירה לענן
      await googleSheetsDataSource.appendClient(spreadsheetId, client);
    } catch (e) {
      print('שגיאה בהוספת לקוח ב-ClientRepository: $e');
    }
  }
}

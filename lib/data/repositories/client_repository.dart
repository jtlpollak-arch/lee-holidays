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
      // 1. נסמך על ה-DataSource המעודכן שלנו
      final List<ClientModel> cloudClients = await googleSheetsDataSource.getClients(spreadsheetId);

      if (cloudClients.isNotEmpty) {
        // עדכון זיכרון מקומי לגיבוי
        await localDbDataSource.saveClients(cloudClients);
        return cloudClients;
      }

      return await localDbDataSource.getClients();
    } catch (e) {
      print('שגיאה במשיכת לקוחות מרפוזיטורי: $e');
      return await localDbDataSource.getClients();
    }
  }

  @override
  Future<void> addNewClient(String spreadsheetId, ClientModel client) async {
    try {
      final List<ClientModel> currentLocal = await localDbDataSource.getClients();
      currentLocal.add(client);
      await localDbDataSource.saveClients(currentLocal);

      await googleSheetsDataSource.appendClient(spreadsheetId, client);
    } catch (e) {
      print('שגיאה בהוספת לקוח מרפוזיטורי: $e');
    }
  }
}

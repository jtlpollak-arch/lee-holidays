import 'dart:math';
import '../datasources/google_sheets_data_source.dart';
import '../datasources/local_db_data_source.dart';
import '../models/client_model.dart';

abstract class ClientRepository {
  Future<List<ClientModel>> getAllClients(String spreadsheetId, {bool forceRefresh = false});
  Future<void> addClient(String spreadsheetId, ClientModel client);
  Future<void> addNewClient(String spreadsheetId, ClientModel client);
  Future<void> editClientRow(String spreadsheetId, int rowIndex, ClientModel client);
  Future<void> updateClient(String spreadsheetId, ClientModel client);
  Future<void> deleteClientSoft(String spreadsheetId, String clientId); // שונה מ-phone ל-clientId הקשיח
}

class ClientRepositoryImpl implements ClientRepository {
  final GoogleSheetsDataSource _googleSheetsDataSource;
  final LocalDbDataSource _localDbDataSource;

  ClientRepositoryImpl({required GoogleSheetsDataSource googleSheetsDataSource, required LocalDbDataSource localDbDataSource}) : _googleSheetsDataSource = googleSheetsDataSource, _localDbDataSource = localDbDataSource;

  /// פונקציית עזר פנימית לייצור מזהה ייחודי קשיח ללקוח מבוסס זמן ורכיב אקראי
  String _generateClientId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1000);
    return 'cli_${timestamp}_$random';
  }

  @override
  Future<List<ClientModel>> getAllClients(String spreadsheetId, {bool forceRefresh = false}) async {
    if (forceRefresh) {
      final cloudClients = await _googleSheetsDataSource.getClients(spreadsheetId);
      if (cloudClients.isNotEmpty) {
        await _localDbDataSource.saveClients(cloudClients);
      }
      return cloudClients;
    }

    final localClients = await _localDbDataSource.getClients();
    if (localClients.isNotEmpty) {
      return localClients;
    }

    final cloudClients = await _googleSheetsDataSource.getClients(spreadsheetId);
    if (cloudClients.isNotEmpty) {
      await _localDbDataSource.saveClients(cloudClients);
    }
    return cloudClients;
  }

  @override
  Future<void> addClient(String spreadsheetId, ClientModel client) async {
    final clientWithId = client.id.isEmpty ? client.copyWith(id: _generateClientId()) : client;

    await _googleSheetsDataSource.appendClient(spreadsheetId, clientWithId);

    final currentLocal = await _localDbDataSource.getClients();
    currentLocal.add(clientWithId);
    await _localDbDataSource.saveClients(currentLocal);
  }

  @override
  Future<void> addNewClient(String spreadsheetId, ClientModel client) async {
    final clientWithId = client.id.isEmpty ? client.copyWith(id: _generateClientId()) : client;

    await _googleSheetsDataSource.appendClient(spreadsheetId, clientWithId);

    final currentLocal = await _localDbDataSource.getClients();
    currentLocal.add(clientWithId);
    await _localDbDataSource.saveClients(currentLocal);
  }

  @override
  Future<void> editClientRow(String spreadsheetId, int rowIndex, ClientModel client) async {
    await _googleSheetsDataSource.updateClientRow(spreadsheetId, rowIndex, client);

    final currentLocal = await _localDbDataSource.getClients();
    final localIndex = currentLocal.indexWhere((c) => c.id == client.id); // שונה מ-phone ל-id
    if (localIndex != -1) {
      currentLocal[localIndex] = client;
      await _localDbDataSource.saveClients(currentLocal);
    }
  }

  @override
  Future<void> updateClient(String spreadsheetId, ClientModel client) async {
    final currentLocal = await _localDbDataSource.getClients();
    final localIndex = currentLocal.indexWhere((c) => c.id == client.id); // שונה מ-phone ל-id
    if (localIndex != -1) {
      currentLocal[localIndex] = client;
      await _localDbDataSource.saveClients(currentLocal);
    }

    final cloudClients = await _googleSheetsDataSource.getClients(spreadsheetId);
    final cloudIndex = cloudClients.indexWhere((c) => c.id == client.id); // שונה מ-phone ל-id
    if (cloudIndex != -1) {
      final int sheetRowNumber = cloudIndex + 2;
      await _googleSheetsDataSource.updateClientRow(spreadsheetId, sheetRowNumber, client);
    }
  }

  @override
  Future<void> deleteClientSoft(String spreadsheetId, String clientId) async {
    // שונה מ-phone ל-clientId
    final cloudClients = await _googleSheetsDataSource.getClients(spreadsheetId);
    final cloudIndex = cloudClients.indexWhere((c) => c.id == clientId); // שונה מ-phone ל-id

    if (cloudIndex != -1) {
      final targetClient = cloudClients[cloudIndex];
      final updatedClient = targetClient.copyWith(status: 'מחוק');

      final int sheetRowNumber = cloudIndex + 2;
      await _googleSheetsDataSource.updateClientRow(spreadsheetId, sheetRowNumber, updatedClient);

      final currentLocal = await _localDbDataSource.getClients();
      final localIndex = currentLocal.indexWhere((c) => c.id == clientId); // שונה מ-phone ל-id
      if (localIndex != -1) {
        currentLocal[localIndex] = updatedClient;
        await _localDbDataSource.saveClients(currentLocal);
      }
    }
  }
}

import '../datasources/google_sheets_data_source.dart';
import '../datasources/local_db_data_source.dart';
import '../models/client_model.dart';

abstract class ClientRepository {
  Future<List<ClientModel>> getClients(String spreadsheetId, {bool forceRefresh = false});
  Future<List<ClientModel>> getAllClients(String spreadsheetId);
  Future<void> addClient(String spreadsheetId, ClientModel client);
  Future<void> addNewClient(String spreadsheetId, ClientModel client);
  Future<void> editClientRow(String spreadsheetId, int rowIndex, ClientModel client);
  Future<void> updateClient(String spreadsheetId, ClientModel client);
  Future<void> deleteClientSoft(String spreadsheetId, int clientId);
}

class ClientRepositoryImpl implements ClientRepository {
  final GoogleSheetsDataSource _googleSheetsDataSource;
  final LocalDbDataSource _localDbDataSource;

  ClientRepositoryImpl({required GoogleSheetsDataSource googleSheetsDataSource, required LocalDbDataSource localDbDataSource}) : _googleSheetsDataSource = googleSheetsDataSource, _localDbDataSource = localDbDataSource;

  @override
  Future<List<ClientModel>> getClients(String spreadsheetId, {bool forceRefresh = false}) async {
    if (forceRefresh) {
      final cloudClients = await _googleSheetsDataSource.getClients(spreadsheetId);
      if (cloudClients.isNotEmpty) {
        await _localDbDataSource.saveClients(cloudClients);
      }
      return cloudClients;
    }
    return getAllClients(spreadsheetId);
  }

  @override
  Future<List<ClientModel>> getAllClients(String spreadsheetId) async {
    try {
      final List<ClientModel> cloudClients = await _googleSheetsDataSource.getClients(spreadsheetId);
      if (cloudClients.isNotEmpty) {
        await _localDbDataSource.saveClients(cloudClients);
        return cloudClients.where((c) => c.isActive).toList();
      }
      final local = await _localDbDataSource.getClients();
      return local.where((c) => c.isActive).toList();
    } catch (e) {
      final local = await _localDbDataSource.getClients();
      return local.where((c) => c.isActive).toList();
    }
  }

  @override
  Future<void> addClient(String spreadsheetId, ClientModel client) async {
    await addNewClient(spreadsheetId, client);
  }

  @override
  Future<void> addNewClient(String spreadsheetId, ClientModel client) async {
    final current = await _localDbDataSource.getClients();
    current.add(client);
    await _localDbDataSource.saveClients(current);
    await _googleSheetsDataSource.appendClient(spreadsheetId, client);
  }

  @override
  Future<void> editClientRow(String spreadsheetId, int rowIndex, ClientModel client) async {
    await _googleSheetsDataSource.updateClientRow(spreadsheetId, rowIndex, client);
    final currentLocal = await _localDbDataSource.getClients();
    final index = currentLocal.indexWhere((c) => c.id == client.id);
    if (index != -1) {
      currentLocal[index] = client;
      await _localDbDataSource.saveClients(currentLocal);
    }
  }

  @override
  Future<void> updateClient(String spreadsheetId, ClientModel client) async {
    final currentLocal = await _localDbDataSource.getClients();
    final index = currentLocal.indexWhere((c) => c.id == client.id);
    if (index != -1) {
      currentLocal[index] = client;
      await _localDbDataSource.saveClients(currentLocal);
    }

    final cloudClients = await _googleSheetsDataSource.getClients(spreadsheetId);
    final cloudIndex = cloudClients.indexWhere((c) => c.id == client.id);
    if (cloudIndex != -1) {
      final int sheetRowNumber = cloudIndex + 2;
      await _googleSheetsDataSource.updateClientRow(spreadsheetId, sheetRowNumber, client);
    }
  }

  @override
  Future<void> deleteClientSoft(String spreadsheetId, int clientId) async {
    final cloudClients = await _googleSheetsDataSource.getClients(spreadsheetId);
    final cloudIndex = cloudClients.indexWhere((c) => c.id == clientId);

    if (cloudIndex != -1) {
      final targetClient = cloudClients[cloudIndex];
      final updatedClient = ClientModel(id: targetClient.id, fullName: targetClient.fullName, firstName: targetClient.firstName, phone: targetClient.phone, email: targetClient.email, status: 'מחוק');

      final int sheetRowNumber = cloudIndex + 2;
      await _googleSheetsDataSource.updateClientRow(spreadsheetId, sheetRowNumber, updatedClient);

      final currentLocal = await _localDbDataSource.getClients();
      final localIndex = currentLocal.indexWhere((c) => c.id == clientId);
      if (localIndex != -1) {
        currentLocal[localIndex] = updatedClient;
        await _localDbDataSource.saveClients(currentLocal);
      }
    }
  }
}

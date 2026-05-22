import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:study_hub/services/storage_service.dart';

class DataExportResult {
  final String filePath;
  final DateTime exportedAt;

  const DataExportResult({required this.filePath, required this.exportedAt});
}

class DataExportService {
  final StorageService _storage;

  DataExportService({StorageService? storage})
    : _storage = storage ?? StorageService();

  Future<DataExportResult> exportActiveAccountData() async {
    final exportedAt = DateTime.now();
    final payload = {
      'format': 'study_hub_export_v1',
      'exportedAt': exportedAt.toIso8601String(),
      'namespace': _storage.activeNamespace,
      'settings': await _storage.getCloudSettingsSnapshot(),
      'localConfig': await _storage.getLocalConfigSnapshot(),
      'records': (await _storage.getStudyLogs())
          .map((record) => record.toMap())
          .toList(),
      'events': (await _storage.getStudyEvents())
          .map((event) => event.toMap())
          .toList(),
      'goals': (await _storage.getStudyGoals())
          .map((goal) => goal.toMap())
          .toList(),
      'certificates': (await _storage.getCertificates())
          .map((certificate) => certificate.toMap())
          .toList(),
    };

    final directory = await getApplicationDocumentsDirectory();
    final stamp = exportedAt
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${directory.path}/study_hub_export_$stamp.json');
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload), flush: true);
    return DataExportResult(filePath: file.path, exportedAt: exportedAt);
  }
}

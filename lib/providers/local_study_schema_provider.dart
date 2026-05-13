import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:study_hub/models/local_study_field.dart';
import 'package:study_hub/services/cloud_sync_service.dart';
import 'package:study_hub/services/local_study_schema_service.dart';
import 'package:study_hub/services/storage_service.dart';

class LocalStudySchemaProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final CloudSyncService _cloudSync = CloudSyncService.instance;
  final List<LocalStudyField> _fields = [];
  bool _isLoading = false;
  String? _lastError;

  LocalStudySchemaProvider() {
    loadFields();
  }

  List<LocalStudyField> get fields => List.unmodifiable(_fields);
  List<LocalStudyField> get activeFields =>
      _fields.where((field) => !field.isArchived).toList();
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  Future<void> loadFields() async {
    _setLoading(true);
    try {
      _lastError = null;
      final stored = await _storage.getLocalStudyFields();
      _fields
        ..clear()
        ..addAll(
          stored.isEmpty ? LocalStudySchemaService.defaultFields() : stored,
        );
      if (stored.isEmpty) {
        await _storage.saveLocalStudyFields(_fields);
      }
    } catch (e) {
      _lastError = 'Nao foi possivel carregar a tabela local.';
      debugPrint('[LocalStudySchemaProvider] loadFields failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addField(LocalStudyField field) async {
    if (_hasDuplicateLabel(field.label)) {
      _lastError = 'Ja existe um campo ativo com esse nome.';
      notifyListeners();
      return false;
    }
    _fields.add(field);
    return _persist();
  }

  Future<bool> updateField(LocalStudyField field) async {
    final index = _fields.indexWhere((item) => item.id == field.id);
    if (index == -1) return false;
    if (_hasDuplicateLabel(field.label, exceptId: field.id)) {
      _lastError = 'Ja existe um campo ativo com esse nome.';
      notifyListeners();
      return false;
    }
    _fields[index] = field.copyWith(updatedAt: DateTime.now());
    return _persist();
  }

  Future<bool> archiveField({
    required String id,
    required String? protectedTimeField,
  }) async {
    final index = _fields.indexWhere((item) => item.id == id);
    if (index == -1) return false;
    final field = _fields[index];
    if (field.label == protectedTimeField || field.isRequired) {
      _lastError = 'Este campo e necessario para os registros.';
      notifyListeners();
      return false;
    }
    _fields[index] = field.copyWith(
      isArchived: true,
      updatedAt: DateTime.now(),
    );
    return _persist();
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  bool _hasDuplicateLabel(String label, {String? exceptId}) {
    final normalized = label.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return activeFields.any(
      (field) =>
          field.id != exceptId &&
          field.label.trim().toLowerCase() == normalized,
    );
  }

  Future<bool> _persist() async {
    try {
      _lastError = null;
      await _storage.saveLocalStudyFields(_fields);
      await _cloudSync.enqueueLocalConfig();
      unawaited(_cloudSync.flushQueue());
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Nao foi possivel salvar a tabela local.';
      debugPrint('[LocalStudySchemaProvider] persist failed: $e');
      notifyListeners();
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

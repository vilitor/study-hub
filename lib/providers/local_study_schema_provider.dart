import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:study_hub/models/local_study_field.dart';
import 'package:study_hub/services/cloud_sync_service.dart';
import 'package:study_hub/services/local_study_schema_service.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/services/study_profile_catalog.dart';

class LocalStudySchemaProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final CloudSyncService _cloudSync = CloudSyncService.instance;
  final List<LocalStudyField> _fields = [];
  bool _isLoading = false;
  String? _lastError;

  LocalStudySchemaProvider({bool autoLoad = true}) {
    if (autoLoad) {
      loadFields();
    }
  }

  List<LocalStudyField> get fields => List.unmodifiable(_fields);
  List<LocalStudyField> get activeFields =>
      _fields.where((field) => !field.isArchived).toList();
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  Future<void> loadFields({
    List<String> defaultCategories = const [],
    bool useFallbackCategories = true,
    bool refreshDefaultCategoryOptions = false,
    bool persistDefaultFields = true,
  }) async {
    _setLoading(true);
    try {
      _lastError = null;
      final stored = await _storage.getLocalStudyFields();
      _fields
        ..clear()
        ..addAll(
          stored.isEmpty
              ? LocalStudySchemaService.defaultFields(
                  categories: defaultCategories,
                  useFallbackCategories: useFallbackCategories,
                )
              : _fieldsWithProfileCategoriesIfSafe(
                  stored,
                  defaultCategories,
                  refreshDefaultCategoryOptions,
                ),
        );
      if (stored.isEmpty && persistDefaultFields) {
        await _storage.saveLocalStudyFields(_fields);
      } else if (refreshDefaultCategoryOptions &&
          !_sameFields(stored, _fields)) {
        await _storage.saveLocalStudyFields(_fields);
      }
    } catch (e) {
      _lastError = 'Não foi possível carregar a tabela local.';
      debugPrint('[LocalStudySchemaProvider] loadFields failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  List<LocalStudyField> _fieldsWithProfileCategoriesIfSafe(
    List<LocalStudyField> fields,
    List<String> categories,
    bool enabled,
  ) {
    if (!enabled) return fields;
    final index = fields.indexWhere((field) => field.id == 'local_category');
    if (index == -1) return fields;

    final field = fields[index];
    if (!field.isDefault ||
        field.isArchived ||
        field.type != LocalStudyFieldType.select ||
        !_canReplaceOptions(field.options)) {
      return fields;
    }

    final nextOptions = _dedupe(categories);
    if (_sameOptions(field.options, nextOptions)) return fields;

    final next = List<LocalStudyField>.from(fields);
    next[index] = field.copyWith(
      options: nextOptions,
      updatedAt: DateTime.now(),
    );
    return next;
  }

  bool _canReplaceOptions(List<String> options) {
    if (options.isEmpty) return true;
    final safeOptions = {
      ...LocalStudySchemaService.fallbackCategoryOptions,
      ...const StudyProfileCatalog().allStarterSubjects(),
    }.map((value) => value.toLowerCase()).toSet();
    return options.every(
      (option) => safeOptions.contains(option.toLowerCase()),
    );
  }

  List<String> _dedupe(List<String> values) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      final key = trimmed.toLowerCase();
      if (trimmed.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(trimmed);
    }
    return result;
  }

  bool _sameOptions(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].toLowerCase() != right[i].toLowerCase()) return false;
    }
    return true;
  }

  bool _sameFields(List<LocalStudyField> left, List<LocalStudyField> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].id != right[i].id ||
          !_sameOptions(left[i].options, right[i].options)) {
        return false;
      }
    }
    return true;
  }

  Future<bool> addField(LocalStudyField field) async {
    if (_hasDuplicateLabel(field.label)) {
      _lastError = 'Já existe um campo ativo com esse nome.';
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
      _lastError = 'Já existe um campo ativo com esse nome.';
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
      _lastError = 'Este campo é necessário para os registros.';
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
      _lastError = 'Não foi possível salvar a tabela local.';
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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:study_hub/models/local_study_field.dart';
import 'package:study_hub/models/onboarding_state.dart';
import 'package:study_hub/services/cloud_sync_service.dart';
import 'package:study_hub/services/local_study_schema_service.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/services/study_profile_catalog.dart';

class StarterSubjectSeedingService {
  final StorageService _storage;
  final StudyProfileCatalog _catalog;
  final CloudSyncService _cloudSync;

  StarterSubjectSeedingService({
    StorageService? storage,
    StudyProfileCatalog catalog = const StudyProfileCatalog(),
    CloudSyncService? cloudSync,
  }) : _storage = storage ?? StorageService(),
       _catalog = catalog,
       _cloudSync = cloudSync ?? CloudSyncService.instance;

  Future<OnboardingState> seedIfNeeded(OnboardingState state) async {
    if (state.legacyMigrationCompleted ||
        !state.profilePersonalizationCompleted ||
        state.starterSubjectsSeeded) {
      return state;
    }

    debugPrint('[ONBOARDING] seeding subjects start');
    final starterSubjects = _catalog.starterSubjects(
      profileId: state.selectedStudyProfileId,
      focusId: state.selectedStudyFocusId,
    );

    if (starterSubjects.isNotEmpty) {
      final current = await _storage.getCustomCategories();
      final next = _canReplaceOptions(current)
          ? _dedupe(starterSubjects)
          : _dedupe([...current, ...starterSubjects]);
      await _storage.saveCustomCategories(next);
    } else {
      final current = await _storage.getCustomCategories();
      if (_canReplaceOptions(current)) {
        await _storage.saveCustomCategories(const []);
      }
    }

    final storedFields = await _storage.getLocalStudyFields();
    if (storedFields.isEmpty) {
      await _storage.saveLocalStudyFields(
        LocalStudySchemaService.defaultFields(
          categories: starterSubjects,
          useFallbackCategories: false,
        ),
      );
    } else {
      final updated = _replaceDefaultCategoryOptionsIfSafe(
        fields: storedFields,
        categories: starterSubjects,
      );
      if (updated != null) {
        await _storage.saveLocalStudyFields(updated);
      }
    }

    final next = state.copyWith(
      starterSubjectsSeeded: true,
      starterSubjectsSeededAt: DateTime.now(),
    );
    await _storage.saveOnboardingState(next);
    await _cloudSync.enqueueLocalConfig();
    await _cloudSync.enqueueSettings(await _storage.getCloudSettingsSnapshot());
    unawaited(_cloudSync.flushQueue());
    debugPrint('[ONBOARDING] seeding subjects end');
    return next;
  }

  List<LocalStudyField>? _replaceDefaultCategoryOptionsIfSafe({
    required List<LocalStudyField> fields,
    required List<String> categories,
  }) {
    final index = fields.indexWhere((field) => field.id == 'local_category');
    if (index == -1) return null;

    final field = fields[index];
    if (!field.isDefault ||
        field.isArchived ||
        field.type != LocalStudyFieldType.select) {
      return null;
    }

    if (!_canReplaceOptions(field.options)) return null;

    final nextOptions = _dedupe(categories);
    final currentKey = field.options
        .map((value) => value.toLowerCase())
        .join('|');
    final nextKey = nextOptions.map((value) => value.toLowerCase()).join('|');
    if (currentKey == nextKey) return null;

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
      ..._catalog.allStarterSubjects(),
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
}

import 'package:study_hub/config/app_constants.dart';
import 'package:study_hub/models/app_settings.dart';
import 'package:study_hub/models/notion_schema.dart';
import 'package:study_hub/services/study_profile_catalog.dart';

class SubjectRepository {
  final StudyProfileCatalog _catalog;

  const SubjectRepository({
    StudyProfileCatalog catalog = const StudyProfileCatalog(),
  }) : _catalog = catalog;

  List<String> getSubjects({
    required AppSettings settings,
    required NotionDatabaseSchema? schema,
  }) {
    final notionSubjects = _subjectsFromConfiguredNotionField(
      settings: settings,
      schema: schema,
    );

    if (notionSubjects.isNotEmpty) {
      return notionSubjects;
    }

    if (settings.profilePersonalizationCompleted &&
        !settings.legacyMigrationCompleted) {
      if (!settings.starterSubjectsSeeded) {
        return List<String>.from(
          _catalog.starterSubjects(
            profileId: settings.selectedStudyProfileId,
            focusId: settings.selectedStudyFocusId,
          ),
        )..sort();
      }
      final profileSubjects = _catalog.starterSubjects(
        profileId: settings.selectedStudyProfileId,
        focusId: settings.selectedStudyFocusId,
      );
      if (_isKnownStarterSet(settings.customCategories)) {
        return List<String>.from(profileSubjects)..sort();
      }
      return _dedupe(settings.customCategories)..sort();
    }

    final defaultSubjects = AppConstants.defaultSubjects.where(
      (subject) => !settings.deletedDefaultCategories.contains(subject),
    );

    return {...defaultSubjects, ...settings.customCategories}.toList()..sort();
  }

  bool isUsingNotionSubjects({
    required AppSettings settings,
    required NotionDatabaseSchema? schema,
  }) {
    return _subjectsFromConfiguredNotionField(
      settings: settings,
      schema: schema,
    ).isNotEmpty;
  }

  List<String> getSelectableSubjectFields(NotionDatabaseSchema? schema) {
    if (schema == null) return const [];
    return schema.properties.entries
        .where(
          (entry) =>
              entry.value.type == 'select' ||
              entry.value.type == 'multi_select',
        )
        .map((entry) => entry.value.name)
        .toList();
  }

  List<String> _subjectsFromConfiguredNotionField({
    required AppSettings settings,
    required NotionDatabaseSchema? schema,
  }) {
    if (!settings.isNotionConnected ||
        settings.notionDatabaseId == null ||
        settings.notionDatabaseId!.isEmpty ||
        !settings.linkCategoriesToNotion ||
        settings.notionCategoryField == null ||
        schema == null) {
      return const [];
    }

    final property = schema.properties[settings.notionCategoryField];
    final options = property?.options ?? const <String>[];
    return options.toSet().toList()..sort();
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

  bool _isKnownStarterSet(List<String> subjects) {
    if (subjects.isEmpty) return false;
    final known = {
      ...AppConstants.defaultSubjects,
      ..._catalog.allStarterSubjects(),
    }.map((value) => value.toLowerCase()).toSet();
    return subjects.every(
      (subject) => known.contains(subject.trim().toLowerCase()),
    );
  }
}
